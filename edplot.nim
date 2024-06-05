when not declared(stdin): import std/[syncio, formatfloat]
import std/[strutils, strformat, algorithm]
from spfun/binom import initBinomP, est
from bu/eve      import a_ik, gNk0, gNk0Thresh, eLE, eRE
from math        import ln, sqrt, copySign
from cligen/colorScl import rgb, hex # For details see: en.wikipedia.org/wiki/
from cligen/osUt import mkdirOpen # CDF-based_nonparametric_confidence_interval
type ConfBand* = enum pointWise, simultaneous, tube
type TubeOpt* = enum pw="pointWise", sim="simultaneous", both
type Fs = seq[float]; type Strs = seq[string]; let dbg = true   #XXX temporary

proc eLE[T](ts: seq[T], a_ik: seq[float], k: int, gNk0Thresh: float): float =
  result = ts.eLE(a_ik)
  if (let s = result.gNk0(k, ts, lower=true); s < gNk0Thresh.abs) and dbg:
    stderr.write &"{s:.4f} < {gNk0Thresh.abs:.4f}; Reject -inf tail\n"
  else:
    if dbg: stderr.write &"Lower tail infinite\n"               #XXX temporary
    result = if gNk0Thresh>0: T.low else: ts[0] - (ts[min(k, ts.len-1)] - ts[0])

proc eRE[T](ts: seq[T], a_ik: seq[float], k: int, gNk0Thresh: float): T =
  result = ts.eRE(a_ik)
  if (let s = result.gNk0(k, ts); s < gNk0Thresh.abs) and dbg:  # test stat `s`
    stderr.write &"{s:.4f} < {gNk0Thresh.abs:.4f}; Reject +inf tail\n"
  else:
    if dbg: stderr.write &"Upper tail infinite\n"               #XXX temporary
    result= if gNk0Thresh>0: T.high else: ts[^1] + (ts[^1]-ts[^min(k,ts.len-1)])

iterator edf*[T](ts: seq[T], k=0, aFinite=0.05): (T, int) =
  ## (x, CumCnt(x)) unnormalized EDF with ties of already sorted seq `ts`; Unix
  ## uniq -c-esque but cumulative.  E.g.: 1 2 2 2 3 4 4 -> 1,1 2,4 3,5 4,7.
  ## If `k>0`, emit an initial 0-level via `bu/eve.eLE` & a final n-level via
  ## `eve.eRE` if edge passes finite-tail test @level `aFinite`; Use `k` order
  ## stats past sample min|max if tail test fails | T.(low|high) if `aFinite<0`.
  let a = if k > 0: k.a_ik else: @[]    # Pass `a` & thr for tiny data sets?
  let gNk0Thresh = copySign(aFinite.abs.gNk0Thresh, aFinite)
  var tLast: T
  var c: int
  if a.len > 0:
    yield (ts.eLE(a, k, gNk0Thresh), 0)
  for t in ts:
    if c > 0 and t != tLast:    # Not first point
      yield (tLast, c)
    tLast = t
    inc c
  if c > 0:                     # Could be empty
    yield (tLast, c)
  if a.len > 0:
    yield (ts.eRE(a, k, gNk0Thresh), c)

proc massartBand(c, n: int; ci=0.95): (float, float) =
  let eps = sqrt(ln(2.0/(1.0 - ci))/(2.0*n.float))
  (max(0.0, c.float/n.float - eps), min(1.0, c.float/n.float + eps))

proc blur*(b=pw, ci=0.1, k=4, tailA=0.05; fp, gplot, xlabel: string;
           wvls, vals, alphas: Fs; ps: Strs) =
  let nCI = int(0.5/ci - 0.5)   # + 1 gets added in divisor
  for p in ps:
    var xs: seq[float]
    for f in lines(if p.len>0: p.open else: stdin): xs.add f.strip.parseFloat
    xs.sort; let n = xs.len             # Make, then emit EDF, C.Band files
    let e = mkdirOpen(&"{fp}/{p}E", fmWrite)
    for (f, c) in edf(xs, k, tailA):
      e.write f," ",c.float/n.float
      for j in 1..nCI:
        let ci = j.float/float(nCI + 1)
        let (lo, hi) = if   b == pw : initBinomP(c, n).est(ci)
                       elif b == sim: massartBand(c, n, ci)
                       else: (c.float/n.float, c.float/n.float) # no range
        e.write " ",lo," ",hi
      e.write "\n"
    e.close
  let g = if gplot.len > 0: open(gplot, fmWrite) else: stdout
  g.write &"""#!/usr/bin/gnuplot
# set terminal png size 1920,1080 font "Helvetica,10"; set output "cbands.png"
set key top left noautotitle    # EDFs go bot left->up right;Dot keys crowd plot
set style data steps; set ylabel "Probability"; set xlabel "{xlabel}"
set yrange [-0.03:1.03]; set ytics 0.1; set grid
plot """
  for i, p in ps:
    let lab = if p.len>0: p else: "stdin"
    for j in 1..nCI:
      let cCI = rgb(wvls[i], sat=1.0 - j.float/float(nCI + 1), val=vals[i]).hex
      let alph = if alphas[i] < 1.0: int(alphas[i]*256).toHex[^2..^1] else: ""
      let s = if i==0 and j==1: "" else: ",\\\n     "
      g.write s, &"'{fp}/{p}E' u 1:{2*j+1} lw 2 lc rgb '#{alph}{cCI}'"
      g.write &",\\\n     '{fp}/{p}E' u 1:{2*j+2} lw 2 lc rgb '#{alph}{cCI}'"
    let cEDF = rgb(wvls[i], sat=1.0, val=vals[i]).hex
    g.write &",\\\n     '{fp}/{p}E' u 1:2 lw 3 lc rgb '#{cEDF}' t '{lab}'"
  g.write "\n"; g.close

proc tube*(b=pw, ci=0.95, k=4, tailA=0.05; fp, gplot, xlabel: string;
           wvls, vals, alphas: Fs; ps: Strs) =
  let ci = if ci == 0.02: 0.95 else: ci
  for p in ps:
    var xs: seq[float]
    for f in lines(if p.len>0: p.open else: stdin): xs.add f.strip.parseFloat
    xs.sort; let n = xs.len             # Make, then emit EDF, Conf.Band files
    let e = mkdirOpen(&"{fp}/{p}E", fmWrite)
    var (p, pPL, pPH, pSL, pSH) = (0.0, 0.0, 0.0, 0.0, 0.0)
    for (f, c) in edf(xs, k, tailA):    # Draw 2 lines:
      e.write f," ",p                   #   1) Last P-level to new x
      if b in {pw, both}: e.write &" {pPL} {pPH}"
      if b in {sim,both}: e.write &" {pSL} {pSH}"
      e.write "\n"; p = c.float/n.float #   2) Then new x, new P-level
      e.write f," ",p
      if b in {pw, both}:
        let (l,h) = initBinomP(c, n).est(ci); e.write &" {l} {h}"; pPL=l; pPH=h
      if b in {sim,both}:
        let (l,h) = massartBand(c, n, ci)   ; e.write &" {l} {h}"; pSL=l; pSH=h
      e.write "\n"
    e.close
  let g = if gplot.len > 0: open(gplot, fmWrite) else: stdout
  g.write &"""#!/usr/bin/gnuplot
# set terminal png size 1920,1080 font "Helvetica,10"; set output "cbands.png"
set key top left noautotitle    # EDFs go bot left->up right;Dot keys crowd plot
set style data lines; set ylabel "Probability"; set xlabel "{xlabel}"
set yrange [-0.03:1.03]; set ytics 0.1; set grid
plot """
  for i, p in ps:
    let lab = if p.len>0: p else: "stdin"
    let s = if i==0: "" else: ",\\\n     "
    let cCB = rgb(wvls[i], sat=1.0, val=vals[i]).hex
    let cIn = rgb(wvls[i], sat=0.5, val=vals[i]).hex
    let alph = if alphas[i] < 1.0: int(alphas[i]*256).toHex[^2..^1] else: ""
    if b == both:
      g.write s,&"'{fp}/{p}E' u 1:3:4 w filledc lc rgb '#{alph}{cIn}' t '{lab}'"
      g.write &",\\\n     '{fp}/{p}E' u 1:4:6 w filledc lc rgb '#{alph}{cCB}'"
      g.write &",\\\n     '{fp}/{p}E' u 1:5:3 w filledc lc rgb '#{alph}{cCB}'"
    else: # Idea of ^^ is 3 shaded regions: the 2 band boundaries & pastel inner
      g.write s,&"'{fp}/{p}E' u 1:3:4 w filledc lc rgb '#{alph}{cIn}' t '{lab}'"
      g.write &",\\\n     '{fp}/{p}E' u 1:3 lc rgb '#{alph}{cCB}'"
      g.write &",\\\n     '{fp}/{p}E' u 1:4 lc rgb '#{alph}{cCB}'"
  g.write "\n"; g.close

proc edplot*(band=pointWise, ci=0.02, k=4, tailA=0.05, fp="/tmp/ed/", gplot="",
             xlabel="Samp Val", wvls:Fs= @[], vals:Fs= @[], alphas:Fs= @[],
             opt=both, inputs: Strs) =
  ## Generate files & gnuplot script to render CDF as confidence band blur|tube.
  ## If `.len < inputs.len` the final value of `wvls`, `vals`, or `alphas` is
  ## re-used for subsequent inputs, otherwise they match pair-wise.
  let inputs = if inputs.len > 0: inputs else: @[""]
  template setup(id, arg, default) =    # Ensure ok (wvls|vals|alphas)[i] ..
    var id = arg                        #.. for each inputs[i].
    if id.len == 0: id.add default
    for i in 1 .. inputs.len - id.len: id.add id[^1]
  setup wvls, wvls, 0.87; setup vals, vals, 1.0; setup alphas, alphas, 0.5
  case band             # Stats Opts    Plot Opts                         Data
  of pointWise   : blur pw, ci,k,tailA, fp,gplot,xlabel,wvls,vals,alphas, inputs
  of simultaneous: blur sim,ci,k,tailA, fp,gplot,xlabel,wvls,vals,alphas, inputs
  of tube        : tube opt,ci,k,tailA, fp,gplot,xlabel,wvls,vals,alphas, inputs

when isMainModule:
  import cligen; include cligen/mergeCfgEnv; dispatch edplot, help={
    "inputs": "input paths or \"\" for stdin",
    "band"  : "bands: pointWise simultaneous tube",
    "ci"    : "band CI level(0.95)|dP spacing(0.02)",
    "k"     : "amount of tails to use for EVE; 0 => no data range estimation",
    "tailA" : "tail finiteness alpha (smaller: less prone to decided +-inf)",
    "fp"    : "tmp File Path prefix for emitted data",
    "gplot" : "gnuplot script or \"\" for stdout",
    "xlabel": "x-axis label; y is always probability",
    "wvls"  : "cligen/colorScl HSV-based wvlens; 0.6",
    "vals"  : "values (V) of HSV fame; 0.8",
    "alphas": "alpha channel transparencies; 0.5",
    "opt"   : "tube opts: pointWise simultaneous both"}
