import std/[stats, math, algorithm]

type MinEst* = object               ## Holds state for 2-stage minimum estimate
  r1*, r2*, r*: seq[float]          ## stage1, stage2, combined data
  s1*, s2*, s*: RunningStat         ## std/stats summaries of r1/r2/r
  est1*, err1*, est2*, err2*: float ## stage1 estimates of 2 subsamples
  apart*: float                     ## statistical distance between 2 subsamples
  measured*: bool                   ## flag indicating successful measurement
  est*, err*: float                 ## Successfully estimated minimum & its err

proc distance(s1, s2: RunningStat; r1, r2: seq[float]): float = # Could be KS-
  abs(s1.mean - s2.mean) / sqrt(s1.variance + s2.variance)      # test(near min)

proc stage2(s: RunningStat, r: seq[float]): (float, float) = # Stage 2 estimator
  (s.mean, s.standardDeviation) #TODO stg2==stg1 now; (r[0], (r[1]-r[0])/3.0)?

template measureSortSummarize(rx, sx, sample1) =
  for it in 1..n:                       # Measure n trials
    rx.add (block: sample1)
  rx.sort                               # Sort
  sx.push rx[0..<best]                  # Summarize

template eMin*(n=10, best=3, dist=7.5, sample1): untyped =
  ## This template takes as its final parameter any block of Nim code that
  ## produces a single `float`, probably a delta time.  `doc/tim.md` explains
  ## while `bu/tim.nim` is a fully worked example to time programs reliably.
  var result: MinEst                    # STAGE 1: assess sampling coherence
  measureSortSummarize(result.r1, result.s1, sample1)
  measureSortSummarize(result.r2, result.s2, sample1)
  result.apart = distance(result.s1, result.s2, result.r1, result.r2)
  if result.apart < dist:               # STAGE 2: Merge data to refine estim
    result.r = result.r1 & result.r2
    result.r.sort
    result.s.push result.r[0..<best]
    (result.est, result.err) = stage2(result.s, result.r)
    result.measured = true              # !measured => (est,err)==(0.0,0.0)
  result
#IDEAS:
# - Do k-sample Anderson-Darling (min-tail weighted) for coherence
# - User-parameterize both stages w/various ideas; Cross-deployment Experiment
