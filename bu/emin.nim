#when not declared(stderr): import std/syncio
import std/[stats, math, algorithm], bu/eve

type MinEst* = tuple[est, err: float] ## An uncertain estimate of a minimum

template eMin(x: var seq[float]; k: int): (float, float) =
  x.sort Descending
  let off = 2*x[0] + - x[^1]
  for e in mitems x: e = off - e
  let xF = off - x.ere(k)
  let st = gNk0(off - xF, k, x)
  for e in mitems x: e = off - e        # reflect back
  (xF, st)

template eMin*(k=3, n=8, m=4, aFinite=0.1, get1): untyped =
  ## This template takes as its final parameter any Nim code block giving one
  ## `float` (probably a delta time) and gives a `MinEst` by a best k/n m-times
  ## approach. `doc/tim.md` has details; `bu/tim.nim` is a CLI utility example.
# let thresh = -ln(-ln(1.0 - aFinite))
  var xall: seq[float]
  var sest: RunningStat
  for outer in 1..m:
    var samp: seq[float]
    for inner in 1..n: samp.add (block: get1)
    let (sm, st {.used.}) = samp.eMin(k)
#   if st > thresh: stderr.write "tFinite: ",st," > ",thresh," => long-tailed\n"
    sest.push sm
    xall.add samp
  let (sm, st {.used.}) = xall.eMin(2*k)
# if st > thresh: stderr.write "tFinite: ",st," > ",thresh," => long-tailed\n"
  (est: sm, err: sest.standardDeviation) #/sqrt(m.float) for larger m's?
#IDEA: Check same-sampling w/m-sample Anderson-Darling(minTail-weighted/clipped)
