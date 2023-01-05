when not declared(addfloat): import std/[syncio, formatfloat]
import std/[os, times, strformat], cligen, cligen/strUt, bu/emin

proc sample1(cmd: string): float =
  let t0 = epochTime()
  if execShellCmd(cmd) != 0:
    quit "could not run \"" & cmd & "\"", 2
  epochTime() - t0

proc tim(n=10, best=3, dist=7.5, write="", cmds: seq[string]) =
  ## Run shell cmds (maybe w/escape|quoting) `2*n` times.  Finds mean,"err" of
  ## the `best` twice and, if stable at level `dist`, merge results for a final
  ## time & error estimate.  `doc/tim.md` explains.
  if n < best:
    raise newException(HelpError, "Need n >= best; Full ${HELP}")
  if cmds.len == 0:
    raise newException(HelpError, "Need cmds; Full ${HELP}")
  let f = if write.len > 0: open(write, fmWrite) else: nil
  for cmd in cmds:
    var e = eMin(n, best, dist, sample1(cmd))         # Get estimate w/error
    if e.measured:
      echo fmtUncertain(e.est, e.err),"\t",cmd        # Report if successful
    else:
      let sa = &"{e.apart:.2f}"                       # Informative failure
      echo &"UNSTABLE; Mean,\"err\"(Best {best} of {n}) stage 1's:\n\t",
        fmtUncertain(e.est1,e.err1),"\n\t",fmtUncertain(e.est2,e.err2),"\n",&"""
are {sa} err apart.  taskset, chrt, fixing CPU freqs (either in OS|BIOS) may
stabilize time sampling as can suspend/quit of competing work/browsers."""
    if not f.isNil:                                   # Optionally log for..
      for t in e.r1: f.write $t,'\n'                  #..further analysis.
      for t in e.r2: f.write $t,'\n'

when isMainModule: include cligen/mergeCfgEnv; dispatch tim, help={
  "n"    : "number of outer trials; 1/2 total",
  "best" : "number of best times to average",
  "dist" : "max distance to decide stable samples",
  "write": "also write times to this file"}
