import std/[strutils, times], cligen/statx, cligen

proc fage(Ref="", refTm='v', fileTm='v', self=false, verb=0, paths:seq[string])=
  ## Print max resolution age (`fileTime(Ref|self,rT) - fileTime(path,fT)`)
  ## for paths.  "now" =~ program start-up.  Examples:
  ##   `fage x y`           v-age of *x* & *y* relative to "now"
  ##   `fage -fb x`         b-age of *x* relative to "now"
  ##   `fage -Rlog logDir`  v-age of *log* rel.to its *logDir*
  ##   `fage -srm -fb x y`  **mtime - btime** for both *x* & *y*
  ##   `fage -ra -R/ ''`    Like `stat -c%X /`, but high-res
  ## Last works since missing files are given time stamps of 0 (start of 1970).
  if paths.len == 0:
    raise newException(HelpError, "Need >= 1 path; ${HELP}")
  let tR = if self: 0i64        # just to skip unneeded syscall(s)
           else: Ref.fileTime(refTm, int64(epochTime() * 1e9))
  for path in paths:
    let tR  = if self: path.fileTime(refTm) else: tR
    let tF  = fileTime(path, fileTm)
    let age = float(tR - tF) * 1e-9
    stdout.write formatFloat(age, ffDecimal, 9)
    if verb > 1:
      stdout.write " ", tR, " ", tF
    if verb > 0:
      echo " ", path else: echo ""

when isMainModule: dispatch fage, help={
  "Ref"   : "path to ref file",
  "refTm" : "ref file stamp [bamcv]",
  "fileTm": "file time stamp [bamcv]",
  "self"  : "take ref time from file itself",
  "verb"  : "0: Deltas; 1: Also paths; 2: diff-ends (ns)"}
