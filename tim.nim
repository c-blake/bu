when not declared(addfloat): import std/[syncio, formatfloat]
import std/[os, times, algorithm, stats, math, strformat], cligen/strUt

proc run(cmd: string, runs=10): seq[float] =
  for trial in 1..runs:
    let t0 = epochTime()
    if execShellCmd(cmd) != 0: quit "could not run \"" & cmd & "\"", 2
    result.add epochTime() - t0

proc me(s: RunningStat): (float, float) = (s.mean, s.standardDeviation)

proc tim(best=3, runs=10, sigma=7.5, write="", cmds: seq[string]) =
  ## Run shell commands (maybe w/escape/quoting) 2*R times.  Finds mean,"err"
  ## of the `best` `runs` twice and, if stable at `sigma`-level, merge results
  ## (reporting mean,"err" of the `best` of all runs).  `doc/tim.md` says more.
  if runs < best: quit "runs >= best must hold", 1
  let f = if write.len > 0: open(write, fmWrite) else: nil
  for cmd in cmds:
    var s1, s2, s: RunningStat
    var r1 = run(cmd, runs)
    var r2 = run(cmd, runs)
    r1.sort; s1.push r1[0..<best]
    r2.sort; s2.push r2[0..<best]
    let (m1, e1) = s1.me
    let (m2, e2) = s2.me
    let sigmas = abs(m1 - m2) / sqrt(e1*e1 + e2*e2)
    if sigmas > sigma:
      let sa = &"{sigmas:.1f}"
      echo &"UNSTABLE; Mean,\"err\"(Best {best} of {runs}):\n\t",
           fmtUncertain(m1, e1), "\n\t", fmtUncertain(m2, e2), "\n", &"""
are {sa} sig apart.  taskset, chrt & if those fail fixing CPU freqs (either in
OS|BIOS) may stabilize timing as can suspend/quit of competing work/browsers."""
    else:       # Compute best of all runs & print mean,"err"
      var r = r1 & r2; r.sort; s.push r[0..<best]
      let (m,e) = s.me; echo fmtUncertain(m, e), "\t", cmd
    if not f.isNil:
      for t in r1: f.write $t,'\n'
      for t in r2: f.write $t,'\n'

when isMainModule: import cligen; dispatch tim, help={
  "best" : "number of best times to average",
  "runs" : "number of outer trials",
  "sigma": "max distance to declare stability",
  "write": "also write times to this file"}
