import std/[math, random, syncio], memfiles as mf

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

when isMainModule:
  import cligen, cligen/osUt
  when defined(release): randomize()

  proc zipf(n=10, alpha=1.5, wr="", rd="", gen=0..0, bin=false,
            keys: seq[string]) =
    ## Sample passed args according to a Zipf distribution for for n items.
    ## The bigger `alpha` the more skewed to dominant events.  Provides `wr`
    ## & `rd` since CDF calc is slow for many possible items.  I recommend
    ## (https://github.com/c-blake/nio) filenames ending in `.Nd`.
    if gen.a != 0 or gen.b != 0:
      var keys: seq[int64]
      for i in gen: keys.add i
      if bin:
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
                       "bin"  : "8B binary ints->stdout"}
