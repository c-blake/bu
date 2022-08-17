import math, sugar, algorithm, stats, random, cligen/strUt; randomize()

proc eMax(x: seq[float], k: int): (float, float) =
  let top = x[^k .. ^1]
  let xL  = collect(for e in top: ln(e))
  let m1  = sum(collect(for e in xL[1..^1]:  e - xL[0]    )) / xL.len.float
  let m2  = sum(collect(for e in xL[1..^1]: (e - xL[0])^2 )) / xL.len.float
  let g   = m1 + 1 - 0.5/(1 - m1*m1/m2)
  if g >= 0:
    raise newException(ValueError, "g >= 0")
  let a   = top[0] * m1 * (1 - min(0, g))
  let b   = top[0]
  let bnd = b - a / g
  var v = (1-g)^2 * (1 - 3*g + 4*g^2) / (g^4 * (1 - 2*g)*(1 - 3*g)*(1 - 4*g))
  v *= a / sqrt(k.float)
  if v < 0:
    raise newException(ValueError, "v < 0")
  (sqrt(v), bnd)

proc aveSmallest2nd*(ves: seq[(float, float)], m: int): float =
  var ves = ves
  ves.sort
  var e: RunningStat
  for i, ve in ves:
    if i >= m: break
    e.push ve[1]
  e.mean

proc eMaxCB(vals: var seq[float], qmax=0.5, amax=20, m=5): float =
  vals.sort
  var ves: seq[(float, float)]
  for k in 2 ..< min(int(qmax * vals.len.float + 0.5), amax):
    try   : ves.add eMax(vals, k)
    except: discard
  ves.aveSmallest2nd(m)

proc eve1(vals: seq[float], n=false, qmax=0.5, amax=20, m=5, low=2.0, geom=true,
          verbose=false): float =
  var vs = vals
  var offset: float                     # Force values onto [low,inf)
  if n:                                 # minimum estimation mode
    if geom:
      offset = vs.max
      for i, x in vs: vs[i] = low * offset / x
    else:
      offset = vs.max + low
      for i, x in vs: vs[i] = offset - x
  else:                                 # maximum estimation mode
    if geom:
      offset = vs.min
      for i, x in vs: vs[i] = low * x / offset
    else:
      offset = vs.min - low
      for i, x in vs: vs[i] = x - offset
  let e = eMaxCB(vs, qmax, amax, m)
# if verbose: stderr.write "xfmSort: ", vs, "\n"
  if n:
    if geom: low * offset / e
    else   : offset - e
  else:
    if geom: low / (offset * e)
    else   : e + offset

proc evs(vals: seq[float], batch=30, n=false): seq[float] =
  var c = 0; var ex = if n: float.high else: float.low
  for v in vals:
    inc c
    ex = if n: min(ex, v) else: max(ex, v)
    if c == batch:
      result.add ex
      c = 0; ex = if n: float.high else: float.low
  # Ignore any short batch `ex` here in favor of constant sample size.

proc eve2(vals: seq[float], batch=30, trials=2000, n=false, qmax=0.5, amax=20,
          m=5, low=2.0, geom=false, verbose=false): (float,float)=
  var eves: seq[float]
  var vals = vals
  for t in 1..trials:
    vals.shuffle
    let e = eve1(vals.evs(batch, n), n, qmax, amax, m, low, geom, verbose)
    if e.classify in {fcNormal, fcSubnormal, fcZero, fcNegZero}:
      eves.add e
  eves.sort
  var ev: RunningStat
  let clip = max(1, int(0.05 * trials.float))
  for e in eves[clip..^(clip+1)]: ev.push e
  (ev.mean, ev.standardDeviationS)

proc eve*(batch=30, n=false, qmax=0.5, amax=20, m=5, sig=0.05, low=2.0,
          geom=false, verbose=false, vals: seq[float]) =
  ## Extreme Value Estimator a la Einmahl2010.  Einmahl notes that for low `k`
  ## variance is high but bias is low & this swaps as `k` grows.  Rather than
  ## trying to minimize asymptotic MSE averaging `gamma` over `k`, we instead
  ## average EV estimates for `<=m` values of `k` with the least var estimates.
  ## Averaging only low bias estimates *should* lower estimator var w/o raising
  ## bias, but simulation study is warranted. Eg: `eve -ng $(repeat 720 tmIt)`.
  if vals.len < 16: echo "Need at least 16 samples! -h for help"; quit(1)
  var sigSig  = float.high
  var lastSig = 0.0
  var trials  = 32
  var em, ev: RunningStat
  while sigSig > sig * lastSig:
    trials = trials * 3 div 2
    if trials > 100000:
      break
    ev.clear                            # keep accumulating em
    for i in 1..10:
      let tup = eve2(vals, batch, trials, n, qmax, amax, m, low, geom, verbose)
      em.push tup[0]
      ev.push tup[1]
    lastSig = ev.mean
    sigSig  = ev.standardDeviationS
  echo fmtUncertain(em.mean, ev.mean, e0= -2..5), " with trials=", trials

when isMainModule: import cligen; dispatch eve, help = {
  "batch"  : "block size for min/max passes",
  "n"      : "estimate minimum, not maximum",
  "qmax"   : "max quantile used for average over `k`",
  "amax"   : "absolute max `k`",
  "m"      : "max number of `k` to average",
  "sig"    : "fractional sigma(sigma)",
  "low"    : "positive transformed lower bound",
  "geom"   : "geometric (v. location) [low,inf) cast; >0!",
  "verbose": "operate verbosely",
  "vals"   : "values"
}
