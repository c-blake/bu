import std/[syncio, posix, strutils], cligen/[sysUt, posixUt]
impCint("fcntl.h", O_DIRECTORY)         # posixUt.impCint; Yes, Nim stdlib sux
proc rename(old, new: cstring): cint {.importc,header:"stdio.h".}
proc mkstemp(tmpl: ptr char): cint {.importc,header:"stdlib.h".}
proc futimes(dfd: cint, tvs: ptr Timeval): cint {.importc,header:"sys/time.h".}
template e(s) = stderr.write "mova: ",s,": ",strerror(errno),"\n" # e=e)rrorEcho

proc cpLoop(sfd, dfd: cint): cint =     # returns 0 by default
  var buf: array[65536, char]           # Does not do sparse files efficiently
  var nR, nW: int                       # 0-init by default
  while (nR=read(sfd, buf[0].addr, buf.sizeof); nR>0)or(nR<0 and errno==EINTR):
    cfor (var off = 0), off < nR, off += nW:
      while (nW=write(dfd, buf[off].addr, nR - off); nW<0 and errno == EINTR):
        discard
      if nW < 0: e "write fail during copy"; return -1
  if nR < 0: e "read fail during copy"; return -1

proc xfsync(fd: cint; einvalOk=false): bool =
  while fsync(fd) != 0:
    if errno == EINTR: continue
    if einvalOk and errno == EINVAL: return true
    return false
  true

template clo =                              # fd closes only for use as lib call
  if sfd >= 0: discard close(sfd); sfd = -1 # For programs, the kernel just..
  if dfd >= 0: discard close(dfd); dfd = -1 #..reclaims all more efficiently.

proc mova*(srcDst: seq[string]): int =
  ##[ Atomic mv to place output is a common idiom, but same dir/FS is not always
  natural => OS mv SHOULD have grown `--atomic` *DECADES* ago.  Like mv(1), try
  rename(2) first - already atomic on *same* FS mount.  On `EXDEV`, **mova**
  falls back to copy to a tmp file *in DST\'s dir* + atomic rename + fsync +
  unlink SRC where `ENOSPC` *is* a possible failure.  Preserves SRC owner, perm
  bits & [am]time (if possible, usually all that's needed for placement idioms).
  Post-rename fsync dirname(dst) => name should be durable. ]##
  if srcDst.len != 2: IO !! "mova needs exactly 2 parameters: SRC DST"
  let (s,d) = (srcDst[0], srcDst[1])    # Unpack args
  let slash = d.rfind('/')
  let nDir  = if slash >= 0: slash + 1 else: 0
  let dir   = if nDir > 0: d[0 ..< nDir] else: "."
  var Dfd   = open(dir.cstring, O_RDONLY or O_DIRECTORY)
  if Dfd < 0: e "open dirname(dst) fail"; return 1
  if rename(s.cstring, d.cstring) == 0:
    if not xfsync(Dfd, einvalOk=true):  # Durability promise on simplest case
      e "fsync dirnam(dst)"; discard close(Dfd); return 2
    discard close(Dfd); return 0
  if errno != EXDEV: e "rename fail"; discard close(Dfd); return 3
  var sfd = open(s.cstring, O_RDONLY)
  if sfd < 0: e "open fail: \"" & s & "\""; return 4
  var st: Stat
  if fstat(sfd, st) != 0: e "stat fail: \"" & s & "\""; return 5
  if not S_ISREG(st.st_mode): e "not regular file: \"" & s & "\""; return 6
  var tmpl = d[0 ..< nDir] & ".mova.XXXXXX"
  var dfd  = mkstemp(addr tmpl[0])      # Nim strings are mutable & NUL term
  if dfd < 0: e "mkstemp fail: \"" & tmpl & "\""; clo; return 7
  if cpLoop(sfd, dfd) != 0: clo; discard tmpl.cstring.unlink; return 8
  if fchown(dfd, st.st_uid, st.st_gid) != 0: e "(owner unpreserved) fchown"
  if fchmod(dfd, st.st_mode and 0o7777) != 0: e "(mode unpreserved) fchmod"
  var tv: array[2, Timeval]             # 0-init
  tv[0].tv_sec = st.st_atime; tv[1].tv_sec = st.st_mtime
  if futimes(dfd, tv[0].addr) != 0: e "(times unpreserved) futimes"
  if not xfsync(dfd): e "fsync fail"; clo; discard tmpl.cstring.unlink; return 9
  clo #NOTE: if final rename fails, leave tmpl around as src may be on /dev/shm
  if rename(tmpl.cstring, d.cstring) != 0: e "final rename fail"; return 10
  if not xfsync(Dfd, einvalOk=true): e "fsync dirname(dst) fail"; clo; return 2
  clo
  if s.cstring.unlink != 0: e "unlink(src=\"" & s & "\") fail (but wrote dst)"

when isMainModule: import cligen; dispatch mova, help={"srcDst": "*SRC* *DST*"}
