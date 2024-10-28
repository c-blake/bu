when not declared(stderr): import std/syncio
include cligen/unsafeAddr
import std/[posix, sets, strutils], cligen, cligen/[osUt, posixUt, dents, statx]

proc since*(refPath: string, refTime="", time="m", recurse=1, chase=false,
            Deref=false, kinds={fkFile}, quiet=false, xdev=false, file="",
            delim='\n', eof0=false, noDot=false, unique=false,
            paths: seq[string]) =
  ## Print files whose *time* is since|before *refTime* of *refPath*.  Files
  ## examined = UNION of *paths* + optional *delim*-delimited input *file* (
  ## ``stdin`` if `"-"`|if `""` & ``stdin`` is not a terminal ), **maybe
  ## recursed** as roots.  To print regular files m-older than LAST under CWD:
  ## ``since -t-m -pLAST -r0 .``
  let err = if quiet: nil else: stderr
  let tO  = fileTimeParse(time)                 #- or CAPITAL=oldest
  let tR  = if refTime.len > 0: fileTimeParse(refTime) else: tO
  var refStat: Statx
  if stat(refPath, refStat) != 0: quit(1)
  let r   = fileTime(refStat, tR.tim, tR.dir)
  var dip = initHashSet[string]()
  let it  = both(paths, fileStrings(file, delim))
  var roots: seq[string]
  for root in it(): (if root.len > 0: roots.add root)
  for rt in (if roots.len == 0 and paths.len == 0: @["."] else: roots.move):
    forPath(rt, recurse, true, chase, xdev, eof0, err,
            depth, path, nmAt, ino, dt, lst, dfd, dst, did):
      if dt != DT_UNKNOWN:                      # unknown here => disappeared
        if (dt == DT_LNK and Deref and not chase and
            doStat(dfd,path,nmAt,lst,Deref,quiet)) or
           lst.stx_nlink != 0 or doStat(dfd,path,nmAt,lst,Deref,quiet):
          if lst.stx_mode.match(kinds) and fileTime(lst, tO.tim, tO.dir) > r:
            let path = if noDot:
                         if   path.startsWith("./."): path[3..^1]
                         elif path.startsWith("./"): path[2..^1]
                         else: path
                       else: path
            if not unique or path notin dip:
              stdout.write path, "\n"
              dip.incl path
    do: discard
    do: discard
    do: recFailDefault("since", path)

when isMainModule:  # Exercise this with an actually useful CLI wrapper.
  include cligen/mergeCfgEnv; dispatch since, help={
    "refPath": "path to ref file",
    "time"   : "stamp to compare ({-}[bamcv]\\*)",
    "refTime": "stamp of ref file to use (if different)",
    "recurse": "recurse n-levels on dirs; 0:unlimited",
    "chase"  : "chase symlinks to dirs in recursion",
    "xdev"   : "block recursion across device boundaries",
    "Deref"  : "dereference symlinks for file times",
    "kinds"  : "i-node type like find(1): [fdlbcps]",
    "quiet"  : "suppress file access errors",
    "file"   : "optional input (\"-\"|!tty=stdin)",
    "delim"  : "input file record delimiter",
    "eof0"   : "read dirents until 0 eof",
    "noDot"  : "remove a leading . from names",
    "unique" : "only print a string once"}, short={"refTime":'T', "refPath":'p'}
