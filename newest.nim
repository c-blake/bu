when not declared(stderr): import std/syncio
include cligen/unsafeAddr
import std/posix, cligen, cligen/[osUt, posixUt, dents, statx], adix/topk

type TimePath = tuple[tm: int64, path: string]

proc newest*(n=1, time="m", recurse=1, chase=false, Deref=false, kinds={fkFile},
             quiet=false, xdev=false, outEnd="\n", file="", delim='\n',
             eof0=false, paths: seq[string]) =
  ## Echo ended by *outEnd* <= *n* newest files in file *time* order
  ## `{-}[bamcv]` for Birth, Access, Mod, Ctime, Version=max(MC); {`-` | CAPITAL
  ## means ***oldest***}.  Examined files = UNION of *paths* + optional
  ## *delim*-delimited input *file* ( ``stdin`` if `"-"`|if `""` & ``stdin`` is
  ## not a terminal ), **maybe recursed** as roots.  E.g. to echo the 3 oldest
  ## regular files by m-time under the CWD: ``newest -n3 -t-m -r0 .``.
  let err = if quiet: nil else: stderr
  let tO = fileTimeParse(time)                  #- or CAPITAL=oldest
  let it = both(paths, fileStrings(file, delim))
  var t  = initTopK[TimePath](n)                # topk accumulator
  for root in it():
    if root.len == 0: continue                  # skip any improper inputs
    forPath(root, recurse, false, chase, xdev, eof0, err,
            depth, path, nmAt, ino, dt, lst, dfd, dst, did):
      if dt != DT_UNKNOWN:                      # unknown here => disappeared
        if (dt==DT_LNK and Deref and doStat(dfd,path,nmAt,lst,Deref,quiet)) or
           lst.stx_nlink != 0 or doStat(dfd,path,nmAt,lst,Deref,quiet):
          if lst.stx_mode.match(kinds):
            t.push (fileTime(lst, tO.tim, tO.dir), path)
    do: discard
    do: discard
    do: recFailDefault("newest", path)
  for tp in t.ascending: stdout.write tp.path, outEnd # Emit in given tmOrd

when isMainModule:  # Exercise this with an actually useful CLI wrapper.
  include cligen/mergeCfgEnv; dispatch newest, help={
    "n"      : "number of 'newest' files",
    "time"   : "timestamp to compare ({-}[bamcv]\\*)",
    "recurse": "recurse n-levels on dirs; 0:unlimited",
    "chase"  : "chase symlinks to dirs in recursion",
    "xdev"   : "block recursion across device boundaries",
    "Deref"  : "dereference symlinks for file times",
    "kinds"  : "i-node type like find(1): [fdlbcps]",
    "quiet"  : "suppress file access errors",
    "outEnd" : "output record terminator",
    "file"   : "optional input (\"-\"|!tty=stdin)",
    "delim"  : "input file record delimiter" }
