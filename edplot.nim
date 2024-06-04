when not declared(stdin): import std/[syncio, formatfloat]
import std/[strutils, strformat, algorithm]
from spfun/binom import initBinomP, est
from cligen/colorScl import rgb, hex # For details see: en.wikipedia.org/wiki/
from cligen/osUt import mkdirOpen # CDF-based_nonparametric_confidence_interval
type ConfBand* = enum pointWise, simultaneous, tube
type TubeOpt* = enum pw="pointWise", sim="simultaneous", both
type Fs = seq[float]; type Strs = seq[string]

iterator edf*[T](ts: seq[T]): (T, int) =
  ## (x, CumCnt(x)) unnormalized EDF with ties of already sorted seq `ts`; Unix
  ## uniq -c-esque but cumulative.  E.g.: 1 2 2 2 3 4 4 -> 1,1 2,4 3,5 4,7.
  var tLast: T
  var c: int
  for t in ts:
    if c > 0 and t != tLast:    # Not first point
      yield (tLast, c)
    tLast = t
    inc c
  if c > 0:                     # Could be empty
    yield (tLast, c)

proc massartBand(c, n: int; ci=0.95): (float, float) =
  let eps = 2.0/(1.0 - ci)/(2.0*n.float)
  (max(0.0, c.float/n.float - eps), min(1.0, c.float/n.float + eps))

proc blur*(k=pw, ci=0.1; tp,gplot,xlabel:string; wvls,vals,alphas:Fs; ps:Strs) =
  let nCI = int(0.5/ci - 0.5)   # + 1 gets added in divisor
  for p in ps:
    var xs: seq[float]
    for f in lines(if p.len>0: p.open else: stdin): xs.add f.strip.parseFloat
    xs.sort; let n = xs.len             # Make, then emit EDF, C.Band files
    let e = mkdirOpen(&"{tp}/{p}E", fmWrite)
    for (f, c) in edf(xs):
      e.write f," ",c.float/n.float
      for j in 1..nCI:
        let ci = j.float/float(nCI + 1)
        let (lo, hi) = if   k == pw : initBinomP(c, n).est(ci)
                       elif k == sim: massartBand(c, n, ci)
                       else: (c.float/n.float, c.float/n.float) # no range
        e.write " ",lo," ",hi
      e.write "\n"
    e.close
  let g = if gplot.len > 0: open(gplot, fmWrite) else: stdout
  g.write &"""#!/usr/bin/gnuplot
# set terminal png size 1920,1080 font "Helvetica,10"; set output "cbands.png"
set key top left noautotitle    # EDFs go bot left->up right;Dot keys crowd plot
set style data steps; set ylabel "Probability"; set xlabel "{xlabel}"
plot """
  for i, p in ps:
    let lab = if p.len>0: p else: "stdin"
    for j in 1..nCI:
      let cCI = rgb(wvls[i], sat=1.0 - j.float/float(nCI + 1), val=vals[i]).hex
      let alph = if alphas[i] < 1.0: int(alphas[i]*256).toHex[^2..^1] else: ""
      let s = if i==0 and j==1: "" else: ",\\\n     "
      g.write s, &"'{tp}/{p}E' u 1:{2*j+1} lw 2 lc rgb '#{alph}{cCI}'"
      g.write &",\\\n     '{tp}/{p}E' u 1:{2*j+2} lw 2 lc rgb '#{alph}{cCI}'"
    let cEDF = rgb(wvls[i], sat=1.0, val=vals[i]).hex
    g.write &",\\\n     '{tp}/{p}E' u 1:2 lw 3 lc rgb '#{cEDF}' t '{lab}'"
  g.write "\n"; g.close

proc tube*(k=pw, ci=0.95;tp,gplot,xlabel:string; wvls,vals,alphas:Fs; ps:Strs) =
  if ci < 0.3: stderr.write &"cdplot warning: ci = {ci:.4f}\n"
  for p in ps:
    var xs: seq[float]
    for f in lines(if p.len>0: p.open else: stdin): xs.add f.strip.parseFloat
    xs.sort; let n = xs.len             # Make, then emit EDF, C.Band files
    let e = mkdirOpen(&"{tp}/{p}E", fmWrite)
    for (f, c) in edf(xs):
      e.write f," ",c.float/n.float
      if k in {pw ,both}:
        let (lo, hi) = initBinomP(c, n).est(ci); e.write " ",lo," ",hi
      if k in {sim,both}:
        let (lo, hi) = massartBand(c, n, ci)   ; e.write " ",lo," ",hi
      e.write "\n"
    e.close
  let g = if gplot.len > 0: open(gplot, fmWrite) else: stdout
  g.write &"""#!/usr/bin/gnuplot
# set terminal png size 1920,1080 font "Helvetica,10"; set output "cbands.png"
set key top left noautotitle    # EDFs go bot left->up right;Dot keys crowd plot
set style data steps; set ylabel "Probability"; set xlabel "{xlabel}"
plot """
  for i, p in ps:
    let lab = if p.len>0: p else: "stdin"
    let s = if i==0: "" else: ",\\\n     "
    let cCB = rgb(wvls[i], sat=1.0, val=vals[i]).hex
    let cIn = rgb(wvls[i], sat=0.5, val=vals[i]).hex
    let alph = if alphas[i] < 1.0: int(alphas[i]*256).toHex[^2..^1] else: ""
    if k == both: # Gnuplot has filledcurves & fillsteps, BUT no filledsteps;PR?
      g.write s, &"'{tp}/{p}E' u 1:3:4 w filledc lc rgb '#{alph}{cIn}' t '{lab}'"
      g.write &",\\\n     '{tp}/{p}E' u 1:4:6 w filledc lc rgb '#{alph}{cCB}'"
      g.write &",\\\n     '{tp}/{p}E' u 1:5:3 w filledc lc rgb '#{alph}{cCB}'"
    else: # Idea of ^^ is 3 shaded regions: the 2 band boundaries & pastel inner
      g.write s, &"'{tp}/{p}E' u 1:3:4 w filledc lc rgb '#{alph}{cIn}' t '{lab}'"
      g.write &",\\\n     '{tp}/{p}E' u 1:3 lc rgb '#{alph}{cCB}'"
      g.write &",\\\n     '{tp}/{p}E' u 1:4 lc rgb '#{alph}{cCB}'"
  g.write "\n"; g.close

proc cdplot*(band=pointWise,ci=0.02, tp="/tmp/ed/",gplot="",xlabel="Sample Val",
  wvls:Fs= @[], vals:Fs= @[], alphas:Fs= @[], opt=both, inputs: Strs) =
  ## Generate files & gnuplot script to render CDF as confidence band blur|tube.
  ## If `.len < inputs.len` the final value of `wvls`, `vals`, or `alphas` is
  ## re-used for subsequent inputs, otherwise they match pair-wise.
  let inputs = if inputs.len > 0: inputs else: @[""]
  template setup(id, arg, default) =    # Ensure ok (wvls|vals|alphas)[i] ..
    var id = arg                        #.. for each inputs[i].
    if id.len == 0: id.add default
    for i in 1 .. inputs.len - id.len: id.add id[^1]
  setup wvls, wvls, 0.87; setup vals, vals, 1.0; setup alphas, alphas, 0.5
  case band
  of pointWise   : blur pw,  ci, tp, gplot, xlabel, wvls, vals, alphas, inputs
  of simultaneous: blur sim, ci, tp, gplot, xlabel, wvls, vals, alphas, inputs
  of tube        : tube opt, ci, tp, gplot, xlabel, wvls, vals, alphas, inputs

when isMainModule:
  import cligen; include cligen/mergeCfgEnv; dispatch cdplot, help={
    "inputs": "input paths or \"\" for stdin",
    "band"  : "bands: pointWise simultaneous tube",
    "ci"    : "CI level | dP spacing for conf.bands",
    "tp"    : "tmp path prefix for numbered CI levels",
    "gplot" : "gnuplot script or \"\" for stdout",
    "xlabel": "x-axis label; y is always probability",
    "wvls"  : "cligen/colorScl HSV-based wvlens; 0.6",
    "vals"  : "values (V) of HSV fame; 0.8",
    "alphas": "alpha channel transparencies; 0.5",
    "opt"   : "tube opts: pointWise simultaneous both"}
