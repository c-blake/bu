## This samples from power-law Zipf distributions two ways: either explicit CDF
## construction and using std/random.sample(openArray,cdf) or via the method of
## Hormann, Derflinger: "Rejection-Inversion to Generate Variates from Monotone
## Discrete Distributions" eeyore.wu-wien.ac.at/papers/96-04-04.wh-der.ps.gz .
##
## Counter-intuitively to some, a small state method is <2X faster than a GIANT
## space one in hot loop benchmarks.  Less space-less time=win,win.  The costly
## method is kept as edifying. (Also, CPU/libcs with >2X slower exp/ln exist.)

when not declared writeFile: import std/syncio
import std/[math, random], memfiles as mf

proc calcCDF*(n: int, alpha=1.5): seq[float64] =
  ## Calculate Zipf CDF for for n items. Usable by random.sample(openArray,cdf).
  result.setLen n
  result[0] = 1.0
  for i in 1 ..< n:
    result[i] = result[i-1] + pow(float64(i + 1), -alpha)
  let norm = 1.0 / result[^1]
  for i in 0 ..< n:
    result[i] *= norm

iterator sample*[T](n=10, alpha=1.5, wr="", rd="", keys: openArray[T]): T =
  template toa[T](p: pointer; a, b: int): untyped =
    toOpenArray[T](cast[ptr UncheckedArray[T]](p), a, b)
  var gen: seq[float64]     # Data generated from calcCDF
  var sav: MemFile          # Data saved from a prior run
  var cdf: pointer          # Whichever of above is in use here
  if rd.len == 0:           # Gen, Load, or Save the big array
    gen = calcCDF(keys.len, alpha)
    cdf = gen[0].addr
  else:                     #NOTE algorithm.upperBound binSearch seeks can be
    sav = mf.open(rd)       #     slow on media, but OTOH /dev/shm is v.fast.
    if sav.size != 8*keys.len:
      sav.close
      raise newException(IOError, "`rd` file size does not match `n` request")
    cdf = sav.mem
  if wr.len > 0:
    writeFile wr, toa[byte](cdf, 0, 8*keys.len - 1)
  for i in 1..n:            # THE MAIN EVENT
    yield sample(keys, toa[float64](cdf, 0, keys.len - 1))
  if not sav.mem.isNil:
    sav.close

# The (usually) a little faster & always much smaller space method.

type Zipf* = object         ## Holds metadata to generate Zipf deviates.
  s, imax, v, q, one_Q, one_Qinv, hxm, hx0_Hxm: float

func h(z: Zipf, x: float): float = exp(z.one_Q*ln(z.v + x)) * z.one_Qinv

func hI(z: Zipf, h: float): float = exp(z.one_Qinv*ln(z.one_Q*h)) - z.v

func initZipf*(s: float, v: range[1.0..float.high], imax: uint): Zipf =
  ## Make a Zipf deviate maker which gets values k on [0,imax] such that P(k) ~
  ## (v + k)**(-s).  Needs: s > 1.
  if s <= 1.0: raise newException(ValueError, "Zipf needs s > 1.0")
  result.imax     = imax.float; result.v = v; result.q = s
  result.one_Q    = 1.0 - s
  result.one_Qinv = 1.0 / result.one_Q
  result.hxm      = result.h(result.imax + 0.5)
  result.hx0_Hxm  = result.h(0.5) - exp(-s*ln(v)) - result.hxm
  result.s        = 1 - result.hI(result.h(1.5) - exp(-s*ln(v + 1.0)))

func sample*(r: var Rand, z: Zipf): uint =
  ## Get a value drawn from distribution described by `z` using `r`.
  if z.v == 0.0: raise newException(ValueError, "Uninitialized Zipf")
  var k = 0.0
  while true:
    let r  = r.rand(1.0)                # U[0,1] sample
    let ur = z.hxm + r*z.hx0_Hxm
    let x  = z.hI(ur)
    k = floor(x + 0.5)                  # round to nearest integer
    if k - x <= z.s or ur >= z.h(k + 0.5) - exp(-ln(k + z.v)*z.q):
      break
  k.uint

proc sample*(z: Zipf): uint = randState.sample(z)
  ## Get a value drawn from distribution described by `z` with the global PRNG.

when isMainModule:
  import cligen, cligen/osUt
  when defined(release): randomize()

  proc zipf(n=10, alpha=1.5, wr="", rd="", gen=0..0, bin=false, fast=false,
            keys: seq[string]) =
    ## Sample passed args according to a Zipf distribution for for n items.
    ## The bigger `alpha` the more skewed to dominant events.  Provides `wr`
    ## & `rd` since CDF calc is slow for many possible items.  I recommend
    ## (https://github.com/c-blake/nio) filenames ending in `.Nd`.
    if gen.a != 0 or gen.b != 0:
      var keys: seq[int64]
      if not fast:
        keys.setLen gen.b - gen.a + 1
        for i in gen: keys[i - gen.a] = i
      if bin:
        if fast:
          let z = initZipf(alpha, 1.0, uint(gen.b - gen.a))
          for _ in 1..n:
            let key = z.sample
            discard stdout.uriteBuffer(key.unsafeAddr, 8)
        else:
          for key in sample(n, alpha, wr, rd, keys):
            discard stdout.uriteBuffer(key.unsafeAddr, 8)
      else:
        for key in sample(n, alpha, wr, rd, keys): outu $key, "\n"
    else:
      for key in sample(n, alpha, wr, rd, keys): outu key, "\n"

  dispatch zipf, help={"n"    : "sample size",
                       "alpha": "Zipf-ian parameter; > 1",
                       "wr"   : "write (binary) data to this",
                       "rd"   : "read (binary) data from this",
                       "gen"  : "sample from ints in this range",
                       "bin"  : "8B binary ints->stdout",
                       "fast" : "small state method (bin,gen mode only)"}
