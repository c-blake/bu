import std/[stats, algorithm], bu/eve

type MinEst* = tuple[est, err: float] ## An uncertain estimate of a minimum

template eMin*(k=2, n=7, m=3, get1): untyped =
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
    sest.push samp.eLE(a)
    xall.add samp
  (est: xall.eLE(a_ik(2*k)), err: sest.standardDeviation) #/sqrt(m.float)4big m?

when isMainModule:
  import cligen
  when defined test:
    when not declared(addFloat): import std/formatFloat
    proc minE(k: int, x: seq[float]) =
      var x = x; x.sort
      echo eLE(x, k.a_ik)
      x.reverse; echo "flipped method, just basic estimate"
      let off = 2*x[0] + - x[^1]
      echo "off: ", off
      for e in mitems x: e = off - e
      echo off - x.ere(k.a_ik)          # , off  # for debugging
    dispatch minE, help={"k":"2k=num of order stats", "x":"1-D / univar data.."}
  else:
    import cligen/strUt; include cligen/mergeCfgEnv
    proc minE(warmup=1, k=2, n=7, m=3, ohead=0, x: seq[float]) =
      ## Emit a minimum estimator of `x` with its uncertainty
      if x.len != warmup + n*m:
        quit "warmup, n, m mismatch given x[]; Run with --help for more.", 1
      var i = warmup - 1
      let (est, err) = eMin(k, n, m, (inc i; x[i]))
      echo fmtUncertain(est, err, e0= -2..5)
    dispatch minE,cmdName="emin", help={"x":"x1 x2..", "warmup":"initial skip",
      "k":"k for eLE", "n":"n for eLE", "m":"outer reps", "ohead":"ignored"}
