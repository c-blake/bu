when not declared(stderr): import std/syncio
when not declared(addFloat): import std/formatFloat
import std/[stats, math, algorithm], bu/eve

type MinEst* = object               ## Holds state for 2-stage minimum estimate
  r1*, r2*, r*: seq[float]          ## stage1, stage2, combined data
  s1*, s2*, s*: RunningStat         ## std/stats summaries of r1/r2/r
  est1*, err1*, est2*, err2*: float ## stage1 estimates of 2 subsamples
  apart*: float                     ## statistical distance between 2 subsamples
  measured*: bool                   ## flag indicating successful measurement
  est*, err*: float                 ## Successfully estimated minimum & its err

proc distance(s1, s2: RunningStat; r1, r2: seq[float]): float = # Could be KS-
  abs(s1.mean - s2.mean) / sqrt(s1.variance + s2.variance)      # test(near min)

# Stage 2 estimator combining all data
proc stage2(s: RunningStat; r: var seq[float]; boot=100, BLimit=5, aFinite=0.05,
            k = -0.5, KMax=50, shift=0.0): (float, float) =
  if boot < 1: (s.min - s.standardDeviation, s.standardDeviation)
  else: # Apply `eve` estimator to `r` (ignoring `s`)
    if r.len < 16:
      raise newException(ValueError, $r.len & " is too few samples")
    let off = r[^1] + (r[^1] - r[0])  # Keep all r[] >= 0 (but not needed)
    r.reverse; for e in r.mitems: e = off - e
    let k = if k > 0.0: k.int
            else: min(KMax, min(r.len div 2, int(pow(r.len.float, k.abs))))
    var xF = r.ere(k)
    let tFinite = gNk0(xF, k, r)
    let tThresh = -ln(-ln(1.0 - aFinite))
    if tFinite > tThresh:
      stderr.write "tFinite: ",tFinite," > ",tThresh," => long-tailed\n"
    let es = r.ese(k, boot, BLimit, aFinite)
    xF = xF + shift*es              # Let user tweak finite sample bias a bit
    xF = off - xF                   # ~Centers for U[-1,1],Triangle,Epanechnikov
    (xF, es)

template measureSortSummarize(rx, sx, sample1) =
  for it in 1..n:                       # Measure n trials
    rx.add (block: sample1)
  rx.sort                               # Sort
  sx.push rx[0..<best]                  # Summarize

template eMin*(n=10, best=3, dist=7.5, boot=100, BLimit=5, aFinite=0.05,
               k = -0.5, KMax=50, shift=2.0, sample1): untyped =
  ## This template takes as its final parameter any block of Nim code that
  ## produces a single `float`, probably a delta time and produces a `MinEst`.
  ## `doc/tim.md` explains; `bu/tim.nim` is a worked example to time programs.
  var result: MinEst                    # STAGE 1: assess sampling coherence
  measureSortSummarize(result.r1, result.s1, sample1)
  measureSortSummarize(result.r2, result.s2, sample1)
  result.apart = distance(result.s1, result.s2, result.r1, result.r2)
  if result.apart < dist:               # STAGE 2: Merge data to refine estim
    result.r = result.r1 & result.r2
    result.r.sort
    result.s.push result.r[0..<best]
    (result.est, result.err) = stage2(result.s, result.r, boot, BLimit, aFinite,
                                      k, KMax, shift)
    result.measured = true              # !measured => (est,err)==(0.0,0.0)
  result
#IDEAS:
# - Do k-sample Anderson-Darling (min-tail weighted) for coherence
# - User-parameterize both stages w/various ideas; Cross-deployment Experiment
