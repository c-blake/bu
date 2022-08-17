## Hardware hosting filesystems can change.  It can be nice to save & restore
## `ctime` & `btime` rather than always wiping history.  No OS/FS-portable way
## exists.  (`settimeofday` can do `ctime` with disruptive time storms.)  This
## utility fills the gap for XFS/ext4 on Linux.  Basic usage for an XFS on DEV
## mounted at MNT is:
##     cbtm save /MNT >MNT.stDat
## Then, sometime later, on e.g. a brand new device:
##     cbtm filt -qr/MNT <MNT.stDat | cbtm resto >CMDS
##     umount /MNT
##     xfs_db -x DEV <CMDS >CMDS.log 2>&1
## **WARNING: Use at your own risk.  No warranty, express or implied.**

import std/[strutils, re, sugar], cligen/[dents, statx, osUt, posixUt]

proc wr(outp: File, lSt: Statx, path: string) =
  let path = (if path.startsWith("./"): path[2..^1] else: path)
  discard outp.uriteBuffer(lSt.addr, lSt.sizeof)
  let nPath = path.len.cushort
  discard outp.uriteBuffer(nPath.addr, nPath.sizeof)
  discard outp.uriteBuffer(path[0].addr, nPath + 1)

proc rd(inp: File): (Statx, string) =
  var nPath: cushort
  discard inp.ureadBuffer(result[0].addr, result[0].sizeof)
  if inp.eof: return
  discard inp.ureadBuffer(nPath.addr, nPath.sizeof)
  result[1].setLen(nPath.int)
  discard inp.ureadBuffer(result[1][0].addr, nPath + 1)

iterator recs*(inp: File): (Statx, string) =
  while (let (lSt, path) = inp.rd; path.len != 0): yield (lSt, path)

proc save*(file="", delim='\n', output="/dev/stdout", quiet=false,
           roots: seq[string]): int =
  ## Save *all* statx metadata for all paths under `roots` to `output`.
  ##
  ## Output format is back-to-back (statx, 2B-pathLen, NUL-term path) records.
  ## To be more selective than full recursion on roots, you can use the output
  ## of `find -print[0]` if you like (& `file=/dev/stdin` to avoid temp files).
  let roots = if roots.len > 0: roots else: @[ "." ]
  let err   = if quiet: nil else: stderr
  var nErr  = 0
  let outp  = if output == "/dev/stdout": stdout else: open(output, fmWrite)
  let it    = both(roots, fileStrings(file, delim))
  for root in it():
    if root.len == 0: continue                  # skip any improper inputs
    forPath(root, 0, true, false, true, false, err,
            depth, path, nmAt, ino, dt, lSt, dfd, dst, did): outp.wr lSt, path
    do: discard
    do: discard
    do: recFailDefault("cbtm save", path)
  return min(nErr, 255)

proc print*(input="/dev/stdin", delim="\t") =
  ## Print metadata stored in input in a human-readable format.
  let inp = if input == "/dev/stdin": stdin else: open(input)
  for (lSt, path) in inp.recs: echo path, delim, lSt

type
  Match* = enum mNm  = "name" , mSz  = "size" , mOwn = "owner", mPerm = "perm",
                mMTm = "mtime", mNLn = "links", mTmSm = "timeSame", mRe = "re"
const MATCH_ALL* = {mSz, mOwn, mPerm, mMTm, mNLn, mTmSm}

proc findAny(s: string; res: seq[Regex]): bool = # bool result default to false
  for r in res: (if s.find(r) != -1: return true)

proc filter*(input="/dev/stdin", output="/dev/stdout", root="", quiet=false,
             match: set[Match]={}, drop="", keeps: seq[string]) =
  ## Remove input records if source & target differ|same [bc]time.
  let inp   = if input  == "/dev/stdin" : stdin  else: open(input)
  let outp  = if output == "/dev/stdout": stdout else: open(output, fmWrite)
  let match = if match.len == 0: MATCH_ALL else: match
  if root.len == 0: erru "no point in running without a `root`\n"; return
  let root  = if root.endsWith('/'): root else: root & "/"
  let dropR = drop.re
  let keeps = collect(for keep in keeps: keep.re)
  var tSt: Statx
  for (lSt, path) in inp.recs:
    var diff: set[Match]
    let tgt = root & path
    if lstatx(tgt.cstring, tSt) != 0: diff.incl mNm
    if mSz   in match and  tSt.stx_size  != lSt.stx_size : diff.incl mSz
    if mOwn  in match and (tSt.stx_uid   != lSt.stx_uid or
                           tSt.stx_gid   != lSt.stx_gid) : diff.incl mOwn
    if mPerm in match and  tSt.stx_mode  != lSt.stx_mode : diff.incl mPerm
    if mMTm  in match and  tSt.stx_mtime != lSt.stx_mtime: diff.incl mMTm
    if mNLn  in match and  tSt.stx_nlink != lSt.stx_nlink: diff.incl mNLn
    if mTmSm in match and (tSt.stx_ctime == lSt.stx_ctime and
                           tSt.stx_btime == lSt.stx_btime): diff.incl mTmSm
    if keeps.len > 0 and not path.findAny(keeps): diff.incl mRe
    if drop.len  > 0 and path.find(dropR) != -1: diff.incl mRe
    if diff.len == 0:                          # xfs_db path quote|esc lexed,BUT
      var lSt = lSt; lSt.stx_ino = tSt.stx_ino # lex never de-quoted/de-escaped.
      outp.wr lSt, path                        # So, use inode instead.
    elif not quiet: erru path, ": diff: ", diff, '\n'

proc tXf(ts: StatxTs): int64 {.inline.} = (ts.tv_sec shl 32) or ts.tv_nsec

type FSKind* = enum fsXFS = "xfs", fsExt4 = "ext4"

proc restore*(input="/dev/stdin", kind=fsXFS) =
  ## Generate commands to restore [cb]time `input`
  let inp = if input == "/dev/stdin": stdin else: open(input)
  for (lSt, path) in inp.recs:
    case kind
    of fsXFS:
      echo "inode ", lSt.stx_ino    # xfs_db path quote|esc broken; Use inode
      echo "write core.ctime.sec ", lSt.stx_ctime.tXf #..and also <<32|nsec;
      echo "write v3.crtime.sec " , lSt.stx_btime.tXf #..Cannot wr raw sec|nsec
    of fsExt4:
      echo "sif foo/bar ctime 20130503145204"         #y4mdHMS; Bit of work..
#     echo "sif foo/bar ctime_extra ", lSt.stx_ctime.tv_nsec

when isMainModule: import cligen; dispatchMulti( #NOTE: nre defines `filter`
  [save   , help={"file"  : "optional input (\"-\"|!tty=stdin)",
                  "delim" : "input file record delimiter",
                  "output": "output file",
                  "quiet" : "suppress most OS error messages" }],
  [print  , help={"input" : "metadata archive/backup path"}],
  [filter , help={"keeps" : "PCRE path patterns to *INCLUDE*", # qualify if nre
                  "input" : "metadata archive/backup path",
                  "output": "output file",
                  "root"  : "target FS root",
                  "quiet" : "do not stderr.emit mismatches",
                  "match" :"""{}=>all else: name, size,perm,
owner,links,mtime,timeSame, re""",
                  "drop"  : "PCRE path pattern to *EXCLUDE*"}],
  [restore, help={"input" : "metadata archive/backup path",
                  "kind"  :"""xfs: gen for `xfs_db -x myImage`
ext4: gen for `debugfs -w myImage` *TODO*"""}])
