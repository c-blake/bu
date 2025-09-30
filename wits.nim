when not declared(stdin): import std/[syncio, formatfloat]
import std/[math, times], adix/[bist, lmbist, embist, xhist1], nio

var old = 2000.0/2001.0
xhist1.def FHisto,  lna, exp, Bist[uint32]
xhist1.def EHisto,  lna, exp, EMBist[float32], Hini=true, old

xhist1.def     FBist  , lna, exp, Bist[uint32]
xhist1.defMove MFHisto, FBist, 1, 1

xhist1.def     LBist  , lna, exp, LMBist[uint32]
xhist1.defMove MLHisto, LBist, it.t + 1, it.t + 1 - it.win

xhist1.def     EBist  , lna, exp, EMBist[float32], Hini=true, old
xhist1.defMove MEHisto, EBist, 1.0, it.xwh.hist.scale(it.win)

type Kernel = enum kFlat="flat", kLin="linear", kExp="exponential"
proc wits(input=".Nf", kernel=kFlat, win=60, oldW=0.99, a=1000.0, b=1e18,
          n=32767, time=false, fs: seq[float]) =
  ## Windowed/Weighted Incremental Time Series.  A CLI for maybe-time-windowed &
  ## maybe-time-weighted incremental dynamic histograms of `adix` with related
  ## quantities like Winsorized/trimmed moments.  Presently, this only takes one
  ## binary numeric column (to get experience w/run-time parameterization), but
  ## emits as many `float32` (aka `'f'`) as quantile fractions specified.
  let fs = if fs.len==0: @[0.5] else: fs    # box & whiskers
  var i = nOpen(input)                  #XXX Must decide on & impl a spec lang
  var num: float                        #... for Winsor/trim moments & qtls (&
  var o = newSeq[float32](fs.len)       #... also impl Winsor/trim moments!)

  var hMF = initMFHisto(a, b, n, win)
  var hML = initMLHisto(a, b, n, win)
  var hME = initMEHisto(a, b, n, win)   #XXX this is buggy/infinite loops XXX
  var hF  = initFHisto(a,  b, n)
  var hE  = initEHisto(a,  b, n)        #XXX must propagate a decay factor
  let t0  = epochTime()
  var c = 0
  while i.read num:
    if win > 0:
      if   kernel == kFlat: hMF.add num
      elif kernel == kLin : hML.add num
      elif kernel == kExp : hME.add num
    else:
      if   kernel == kFlat: hF.add num
      elif kernel == kExp : hE.add num
    for j, f in fs:
      o[j] = (if win > 0:
                if   kernel == kFlat: hMF.quantile f
                elif kernel == kLin : hML.quantile f
                elif kernel == kExp : hME.quantile f
                else: NaN
              else:
                if   kernel == kFlat: hF.quantile f
                elif kernel == kExp : hE.quantile f
                else: NaN).float32
    discard stdout.writeBuffer(addr o[0], o[0].sizeof*o.len)
    inc c
  if time: stderr.write (epochTime() - t0)*1e9/c.float, " ns/num\n"

when isMainModule: import cligen;include cligen/mergeCfgEnv;dispatch wits,help={
  "fs"    : "quantile fractions; 0.5=median (also default)",
  "input" : "nio input file; extension-only=>stdin",
  "kernel": "time-kernel: flat, linear, exponential",
  "win"   : "window; 0=>running/cumulative(!linear)",
  "oldW"  : "weight on old data for exponential",
  "a"     : "lower bound",
  "b"     : "upper bound",
  "n"   : """cross-sectional `n` for HDR histo; 32767=~
15/log10(1.001)=>defaults=>0.1% bins""",
  "time"  : "report main loop execution time"}
