import std/[os, posix, strutils, sets]

if paramCount() < 1 or  paramCount() mod 5 != 0: quit """Usage:
  okpaths ENVAR [DELIM(:) [ITYPE{bcdpfls}(d) [PERMS{rwx}(x) [DEDUP{FL*}(F)]]]]
echos re-assembled value for $ENVAR delimited by char DELIM where each element
kept is inode type ITYPE w/permissions PERMS.  E.g., PATH=`okpaths PATH` keeps
only existing (d)irs executable(x) by the invoking user.  DEPDUP starting with
'F' means keep first use, while 'L' keeps last use & any other means no de-dup.
eval `okpaths PATH : d rx u` is nice in rc/init scripts for Unix shells. Blocks
of 5 params can repeat (since fork&exec can add to shell start-up times).""", 0

for shf in countup(0, paramCount()-1, 5):
  let delim = if paramCount()>1+shf: paramStr(2+shf)[0]         else: ':'
  let kinds = if paramCount()>2+shf: paramStr(3+shf)            else: "d"
  let perms = if paramCount()>3+shf: paramStr(4+shf)            else: "rx"
  let dedup = if paramCount()>4+shf: paramStr(5+shf).toUpper[0] else: 'F'

  func kind(mode: Mode): char =
    if   mode.S_ISBLK : 'b'
    elif mode.S_ISCHR : 'c'
    elif mode.S_ISDIR : 'd'
    elif mode.S_ISFIFO: 'p'
    elif mode.S_ISREG : 'f'
    elif (when not defined(windows): mode.S_ISLNK  else: false): 'l'
    elif (when not defined(windows): mode.S_ISSOCK else: false): 's'
    else: '.'

  proc perm(perms: string): cint =
    if 'r' in perms: result = result or R_OK
    if 'w' in perms: result = result or W_OK
    if 'x' in perms: result = result or X_OK

  let prms = perm(perms)
  var res: seq[string]            # Result to output (re-joined with delim)
  var ids: seq[Ino]               # i-node identity; [i] tracks res[i]
  var st: Stat
  var did: HashSet[Ino]
  for e in paramStr(1+shf).getEnv.split(delim):
    let ec = e.cstring
    if stat(ec, st) == 0 and st.st_mode.kind in kinds and access(ec, prms) == 0:
      if dedup == 'F':            # F)irst retention
        if st.st_ino notin did:   # Only add if have not already
          res.add e
          did.incl st.st_ino
      elif dedup == 'L':          # L)ast retention
        if st.st_ino in did:      # Already added; First delete [old]
          let ino = ids.find(st.st_ino)
          res.delete ino
          ids.delete ino
        did.incl st.st_ino        # Add it
        ids.add st.st_ino
        res.add e
      else:                       # Not de-duplicating
        res.add e

  echo paramStr(1+shf),"=",join(res, $delim)
