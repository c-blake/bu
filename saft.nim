when not declared(stderr): import std/syncio
include cligen/unsafeAddr
import cligen, cligen/[sysUt, osUt, posixUt, strUt], std/[posix, strformat]

template eStr: untyped = $strerror(errno)       # Error string for last errno

proc ctimeNsAt*(dirfd: cint; path: cstring; st: Stat; flags: cint): bool =
  ## Use `clock_settime` to set st_ctim returning `true` on *FAILURE*.
  var now: Timespec
  if clock_gettime(CLOCK_REALTIME, now) != 0:
    erru "saft:clock_gettime: ",eStr,'\n'
    return true
  var st = st                                   # std/posix declares as `var`??!
  if clock_settime(CLOCK_REALTIME, st.st_ctim) != 0:    # Q: subtract a guess?
    erru "saft:clock_settime: ",eStr,'\n'
    return true
  if st.st_mode.S_ISLNK and (flags or AT_SYMLINK_NOFOLLOW) != 0:
    var t = $path & "_"             # Linux has renameat2 w/RENAME_NOREPLACE..
    var st: Stat                    #..but we use hokey/racy foo_ foo__ loop.
    while fstatat(AT_FDCWD, t.cstring, st, 0) == 0: t.add '_'
    discard rename(path, t.cstring) # Updates ctim without altering mtim
    discard rename(t.cstring, path)
  elif fchownat(AT_FDCWD, path, st.st_uid, st.st_gid, flags)!=0: # Can be slow
    erru "saft:fchownat: \"",path,"\": ",eStr,'\n'  # Also, can fail on net FS..
    return true                                     #..or where root inadequate
  if clock_settime(CLOCK_REALTIME, now) != 0:           # Q: Add a guess?
    erru "saft:clock_settime: ",eStr,'\n'
    return true

proc saft(access=false, modify=true, cInode=false, link=false, verb=false,
          cmdFiles: seq[string]): int =
  ## Preserve file times while running `cmd files`. Eg.: `saft -- sed -si
  ## s/X/Y/g -- A B` may edit `X` -> `Y` in files `A B` without causing file
  ## time-based remake. { `cInode` on many files causes "time storms" }.
  let cmdFiles = cmdFiles.split("--")
  if cmdFiles.len != 2:
    Help !! "Need exactly cmd,files; Full $HELP"
  let cmd = cmdFiles[0]; let files = cmdFiles[1]
  if cmd.len  <  1: Help !! "Need Some Cmd; Full $HELP"
  if files.len < 1: Help !! "Need >= 1 file; Full $HELP"
  let flags = if link: AT_SYMLINK_NOFOLLOW else: 0.cint
  let flagSt = if link: "SYMLINK_NOFOLLOW" else: "0"

  var sts = newSeq[Stat](files.len)             # 1) Collect before-tms&build cL
  var cL = cast[cstringArray](alloc0((files.len + cmd.len + 1)*cstring.sizeof))
  for i in 0 ..< cmd.len: cL[i] = cast[cstring](cmd[i][0].unsafeAddr)
  for i, file in files:
    if fstatat(AT_FDCWD, file.cstring, sts[i], flags) != 0:
      erru "saft:fstatat:Bef: \"",file,"\": ",eStr,'\n'
    cL[cmd.len + i] = cast[cstring](files[i][0].unsafeAddr)

  let pid = vfork()                             # 2) Run the program on inputs
  case pid
  of -1: quit "saft:vfork: "&eStr, 2
  of 0: (if execvp(cmd[0].cstring, cL)!=0: quit "saft:execvp: "&eStr&"\n", 126)
  else:
    var xst: cint
    if waitpid(pid, xst, 0) != pid: quit "saft:waitpid: "&eStr&"\n", 3
    if xst.WEXITSTATUS.int == 126: quit "saft:waitpid: kid exec failed\n", 4

  var st: Stat                                  # 3) Cmp post-time,maybe restore
  var failedSet = false
  for i, file in files:
    let path = file.cstring
    if fstatat(AT_FDCWD, path, st, flags) != 0:
      erru "saft:fstatat:Aft: \"", file, "\": ",eStr,'\n'
      continue                                  # File likely deleted in interim
    let had = [sts[i].st_atim, sts[i].st_mtim]
    let new = [st    .st_atim, st    .st_mtim]
    var wnt = new
    if access: wnt[0] = had[0]                  # want access to be what we had
    if modify: wnt[1] = had[1]                  # want modify to be what we had
    if wnt != new:                              # Only act if needed; want!=new
      if verb: erru &"utimensat(\"{file}\", {had}, {flagSt})\n"
      if utimensat(AT_FDCWD, path, had, flags)!=0:
        erru "saft:utimesat: \"",file,"\": ",eStr,'\n'
    elif verb and (access or modify):
      erru wnt,"==",had,"\n"
    if cInode and st.st_ctim != sts[i].st_ctim and not failedSet:
      if verb: erru &"ctimeNsAt(\"{file}\", {sts[i].st_ctim}, {flagSt})\n"
      failedSet = ctimeNsAt(AT_FDCWD, path, sts[i], flags)

when isMainModule: include cligen/mergeCfgEnv; dispatch saft, help={
  "cmdFiles": "[--] `cmd opts&args..` -- `files to preserve times`",
  "access": "preserve atime",
  "modify": "preserve mtime",
  "cInode": "preserve ctime (need CAP_SYS_TIME/root; Sets & Restores clock!)",
  "link"  : "save times of symLink not target if OS supports",
  "verb"  : "emit various activities to stderr"}
