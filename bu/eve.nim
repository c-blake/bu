when not declared(addFloat): import std/formatFloat
import std/[math, algorithm, random, stats], cligen/[osUt, strUt]
const ln2 = ln 2.0

proc ere*(x: seq[float], k: int): float =
  ## The general Fraga Alves & Neves2017 Estimator for Extreme Right Endpoint.
  ## This needs sorted `x` and at least upper 2*k-1 elements to exist.
  if x.len<2*k: raise newException(ValueError,"2*k(" & $k & ")>x.len=" & $x.len)
  for i in 0..<k: result += ln(1.0 + 1.0/float(k + i))*x[^(k + i)]
  x[^1] + x[^k] - result/ln2

proc gNk(xF: float, k: int, x: seq[float]): float = 
  (xF - x[^k])/(x[^k] - x[^(2*k)])

proc gNk0*(xF: float, k: int, x: seq[float]): float = 
  ## Is short-tailed test passes if gNk0 < -ln(-ln(-pFinite/2)) else long-tail.
  ln2*gNk(xF, k, x) - (ln(k.float) + 0.5*ln2)

# Fraga Alves & Neves give a formula for an approx. "- not +-" conf.interval,
#   proc h(g: float): float = (1.0/g)*(1.0 + (pow(2.0, -g) - 1)/(g*ln2))
#   proc qa(p, g: float): float = pow(-ln(p), -g)/g
#   proc ci(k, p, g, a0: float): float = a0*(h(g) + pow(k.float, g)*qa(p, g))
# but that must estimate g=gamma & a0.  This code does sample extreme-retaining
# bootstrapped variance instead.  Such retention helps near-estimate clustering.
# Samples can fail finite tail tests. Such are dropped (cf importance sampling).
proc ese*(x: seq[float]; k, boot, BLimit: int; aFinite: float): float =
  var wnd = false
  let boo = min(boot, int(pow(2.0, float(2*k - 1))))
  if boo < boot: erru "eve: warning: tiny 2k-1=",2*k-1," saturates B=",boot,"\n"
  var st: RunningStat
  let tThresh = -ln(-ln(1.0 - aFinite))
  let o = x.len - 1 - (2*k - 1)
  var b = x
  for trial in 1..boo:                  # This resamples from *only* upper tail.
    for subTry in 1..BLimit:            # Nim rand(m) is 0..m inclusive of m.
      for i in 0 ..< 2*k-1: b[o+i] = x[o + rand(2*k-2)] # k-2: Leave sample max
      b.sort                            # Only b[o..^2] can be out of order..
      let xF = b.ere(k)
      let tFinite = gNk0(xF, k, x)
      if tFinite > tThresh:
        if subTry == BLimit:
          if not wnd: erru "eve: hit BLimit: close to long-tailed\n"; wnd = true
        else: st.push xF; break
      else:
        st.push xF; break
  st.standardDeviationS

type Emit = enum eTail="tail", eBound="bound"
proc eve*(low=false, boot=32, BLimit=5, emit={eBound}, aFinite=0.05,
          k = -0.5, KMax=50, shift=0.0, x: seq[float]) =
  ## Extreme Value Estimate by FragaAlves&Neves2017 Estimator for Right Endpoint
  ## method with bootstrapped standard error.  E.g.: `eve -l $(repeat 99 tmIt)`.
  ## This only assumes IID samples (which can FAIL for sequential timings!) and
  ## checks that spacings are not consistent with an infinite tail.
  if x.len < 4: raise newException(ValueError, $x.len & " is too few samples")
  var x = x; x.sort
  let off = x[^1] + (x[^1] - x[0])  # Should keep all x[] >= 0 (but not needed)
  if low: (x.reverse; for e in x.mitems: e = off - e)
  let k = if k > 0.0: k.int
          else: min(KMax, min(x.len div 2, int(pow(x.len.float, k.abs))))
  var xF = x.ere(k)
  let tFinite = gNk0(xF, k, x)
  let tThresh = -ln(-ln(1.0 - aFinite))
  if tFinite > tThresh:
    if eTail in emit: echo "tFinite: ",tFinite," > ",tThresh," => long-tailed"
  if eBound in emit:
    let es = x.ese(k, boot, BLimit, aFinite)
    xF = xF + shift*es              # Correct finite sample too big bias a bit
    if low: xF = off - xF           # ~Centers for U[-1,1],Triangle,Epanechnikov
    echo fmtUncertain(xF, es, e0= -2..5)

when isMainModule:
  import cligen; when defined(release): randomize()
  dispatch eve, help={
    "low"      : "flip input to estimate *Left* Endpoint",
    "boot"     : "number of bootstrap replications",
    "BLimit"   : "re-tries per replication to get not-long",
    "emit":"""`tail`  - verbose long-tail test
`bound` - bound when short-tailed""",
    "aFinite"  : "tail index > 0 acceptance significance",
    "k"        : "2k=num of order statistics; <0 => = n^|k|",
    "KMax"     : "biggest k; FA,N2017 suggests ~50..100",
    "shift"    : "shift MAX by this many sigma (finite bias)",
    "x": "1-D / univariate data ..."}
# Bücher&Jennessen 2022 - Stats for Heteroscedastic Time Series Extremes has an
# approach for the more general case of serial autocorrelation with time varying
# fluctuation scale. That'd need something like `pIndep`, `pHetero`, but would
# be more appropriate for "analyze many sequential run-times" non-IID use cases.
