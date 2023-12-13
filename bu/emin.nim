import std/[stats, algorithm], bu/eve

type MinEst* = tuple[est, err: float] ## An uncertain estimate of a minimum

template eMin*(k=3, n=8, m=4, get1): untyped =
  ## This template takes as its final parameter any Nim code block giving one
  ## `float` (probably a delta time) and gives a `MinEst` by a best k/n m-times
  ## approach. `doc/tim.md` has details; `bu/tim.nim` is a CLI utility example.
  #IDEA: Check m-sampling same via Anderson-Darling(minTail-weighted/clipped).
  var xall: seq[float]
  var sest: RunningStat
  let a = k.a_ik
  for outer in 1..m:
    var samp: seq[float]
    for inner in 1..n: samp.add (block: get1)
    samp.sort
    sest.push samp.ele(a) 
    xall.add samp
  (est: xall.ele(a_ik(2*k)), err: sest.standardDeviation) #/sqrt(m.float)4big m?

when isMainModule:
  when not declared(addFloat): import std/formatFloat
  import cligen
  proc minE(k: int, x: seq[float]) =
    var x = x; x.sort
    echo ele(x, k.a_ik)
    x.reverse; echo "flipped method, just basic estimate"
    let off = 2*x[0] + - x[^1]
    echo "off: ", off
    for e in mitems x: e = off - e
    echo off - x.ere(k.a_ik)          # , off  # for debugging
  dispatch minE, help={"k": "2k=num of order stats", "x": "1-D / univar data.."}
