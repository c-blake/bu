when not declared(addfloat): import std/[syncio, formatfloat]
import std/[os, times, strformat, math], cligen, cligen/strUt, bu/emin

proc sample1(cmd: string): float =
  let t0 = epochTime()
  if execShellCmd(cmd) != 0:
    quit "could not run \"" & cmd & "\"", 2
  epochTime() - t0

proc tim(n=10, best=3, dist=9.0, write="", Boot=0, limit=5, aFinite=0.05,
         shift=4.0, k = -0.5, KMax=50, ohead=0, cmds: seq[string]) =
  ## Run shell cmds (maybe w/escape|quoting) `2*n` times.  Finds mean,"err" of
  ## the `best` twice and, if stable at level `dist`, merge results for a final
  ## time & error estimate (-B>0 => EVT estimate).  `doc/tim.md` explains.
  if n < best:
    raise newException(HelpError, "Need n >= best; Full ${HELP}")
  if cmds.len == 0:
    raise newException(HelpError, "Need cmds; Full ${HELP}")
  let f = if write.len > 0: open(write, fmWrite) else: nil
  let o = if ohead > 0: eMin(ohead, best, dist, Boot, limit, aFinite,
                             k, KMax, shift, sample1("")) else: MinEst()
  for cmd in cmds:
    var e = eMin(n, best, dist, Boot, limit, aFinite,
                 k, KMax, shift, sample1(cmd))
    if e.measured:                                    # Got estimate w/error
      if ohead > 0:                                   # Subtract overhead..
        e.est -= o.est; e.err=sqrt(e.err^2 + o.err^2) #..propagating errors.
      echo fmtUncertain(e.est, e.err),"\t",cmd        # Report
    else:
      let sa = &"{e.apart:.2f}"                       # Informative failure
      echo &"UNSTABLE; Mean,\"err\"(Best {best} of {n}) stage 1's:\n\t",
        fmtUncertain(e.est1,e.err1),"\n\t",fmtUncertain(e.est2,e.err2),"\n",&"""
are {sa} err apart for {cmd}.  taskset, chrt, fixing CPU freqs (in OS|BIOS) may
stabilize time sampling as can suspend/quit of competing work (eg. browsers)."""
    if not f.isNil:                                   # Optionally log for..
      for t in e.r1: f.write $t,'\n'                  #..further analysis.
      for t in e.r2: f.write $t,'\n'

when isMainModule: include cligen/mergeCfgEnv; dispatch tim, help={
  "n"      : "number of outer trials; 1/2 total",
  "best"   : "number of best times to average",
  "dist"   : "max distance to decide stable samples",
  "write"  : "also write times to this file",
  "Boot"   :"""bootstrap replications for final err estim
<1 => simpler sample min estimate & error""",
  "limit"  : "re-try limit to get finite tail replication",
  "aFinite": "alpha/signif level to test tail finiteness",
  "shift"  : "shift by this many sigma (finite bias)",
  "k"      : "2k=num of order statistics; <0 => = n^|k|",
  "KMax"   : "biggest k; FA,N2017 suggests ~50..100",
  "ohead": """number of \"\" overhead runs;  If > 0, value
(measured same way) is offset from each item"""}
