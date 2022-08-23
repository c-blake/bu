import std/[posix, tables, strutils], cligen, cligen/[osUt, posixUt, dents]

type LncsLog* = enum osErr, summary         ## A micro logging system
type DevIno = tuple[dev: Dev; ino: uint64]

when isMainModule:                    #Provide a useful CLI wrapper.
  proc lncs(paths: seq[string], file="", dlm='\n', recurse=1, chase=false, #in
            xdev=false, eof0=false, kinds={fkFile}, minSize=0, thresh=2,   #filt
            quiet=false, log={osErr},                                      #log
            nEcho= -1, noDot=false, outDlm="\t", endOut="\n"): int =       #out
    ## Print hard link clusters within paths of maybe-chasing, maybe-recursive
    ## closure of the UNION of ``roots`` and optional ``dlm``-delimited input
    ## ``file`` (stdin if "-"|if "" & stdin not a tty).  Exit code is min(255,
    ## num.clusters >= thresh).  Eg., ``find -print0|lncs -d\\0 -o '' -e ''``
    ## makes a report reliably splittable on double-NUL then single-NUL for
    ## fully general path names while ``lncs -ls -n0 -r0 /`` echoes a summary.
    let outDlm = if outDlm.len > 0: outDlm else: "\x00"
    let endOut = if endOut.len > 0: endOut else: "\x00"
    var nPaths, nSet, nFile: int              #Track some statistics
    var tab = initTable[DevIno, seq[string]](512)
    let err = if quiet: nil else: stderr
    let it  = both(paths, fileStrings(file, dlm))
    var roots: seq[string]
    for root in it(): (if root.len > 0: roots.add root)
    for rt in (if roots.len == 0 and paths.len == 0: @["."] else: roots.move):
      forPath(rt, recurse, true, chase, xdev, eof0, err,
              depth, path, nmAt, ino, dt, lst, dfd, dst, did):
        if dt != DT_UNKNOWN and lst.stx_mode.match(kinds): # unknown here =>gone
          let path = if noDot and path.startsWith("./"): path[2..^1] else: path
          nPaths.inc
          if lst.stx_size >= minSize.uint64: # big enough
            let key: DevIno = (lst.st_dev, lst.stx_ino)
            tab.mgetOrPut(key, @[]).add(path)
      do: discard
      do: discard
      do: recFailDefault("lncs", path)
    for ino, s in tab:
     if s.len >= thresh:
      nSet.inc
      nFile.inc s.len
      if nEcho != 0:                  #Maybe emit report for set
        let lim = min(s.len, if nEcho > 0: nEcho else: s.len)
        stdout.write s[0 ..< lim].join(outDlm), endOut
    if summary in log:                #Emit summary statistics
      stderr.write nSet," sets of ",nFile," hard links in ",nPaths," paths\n"
    return min(255, nSet)             #Exit with appropriate status

  dispatch lncs, help={ "paths"  : "filesystem roots",
                        "file"   : "optional input (\"-\"|!tty=stdin)",
                        "dlm"    : "input file delimiter (\\0->NUL)",
                        "recurse": "recurse n-levels on dirs; 0:unlimited",
                        "chase"  : "follow symlinks to dirs in recursion",
                        "xdev"   : "block recursion across device boundaries",
                        "eof0"   : "read dirents until 0 eof",
                        "kinds"  : "i-node type like find(1): [fdlbcps]",
                        "minSize": "minimum file size",
                        "thresh" : "smallest hard link cluster to count",
                        "quiet"  : "suppress file access errors",
                        "log"    : ">stderr{osErr, summary}",
                        "nEcho"  : "num to print; 0: none; -1: unlimited",
                        "noDot"  : "remove a leading . from names",
                        "outDlm" : "output internal delimiter",
                        "endOut" : "output record terminator" },
           short = {"xdev": 'X', "eof0": '0', "noDot": '.'}
