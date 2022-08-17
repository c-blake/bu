import random, times, strutils, stats, cligen

when defined(mt):
  import mersenne               # Test against a diff PRNG
  var mt = newMersenneTwister(1234554321)
  proc rand(max: int): int =    # Inclusive of endpoint
    int(mt.getNum mod (uint32(max) + 1u32))

proc sattolo_cycle[T](x: var openArray[T]) =
  for i in countdown(x.len - 1, 1):
    swap x[i], x[rand(i - 1)]   # i-1 -> i =>Fisher-Yates

proc prepRanElt(x: var seq[int], n: int) =
  for i in 0..<n: x[i]=rand(9)  # 9 keeps sums short

var r = initRand(123)           # Speed not bias optimized
proc runRanElt(x: seq[int], nAcc: int): int =
  let mask = uint(x.len - 1)    # Only pow2 lens work!
  when defined(mt):
    for i in 1..nAcc: result += x[int(mt.getNum and mask)]
  else:
    for i in 1..nAcc: result += x[int(r.next.uint and mask)]

proc prepShuffle(x: var seq[int], n: int) =
  for i in 0..<n: x[i] = i      # Pop seq with identity
  x.sattolo_cycle               # ..perm & then shuffle

proc runShuffle(x: seq[int], nAcc: int): int =
  for i in 1..nAcc: result = x[result]

proc getrandom(a: pointer, n: uint64, f: cuint): csize_t
  {.header: "sys/random.h".}    # /dev/urandom on Linux

var tru: seq[uint]
proc prepTrueRan(x: var seq[int], n: int) =
  let mask = uint(x.len - 1)    # Only pow2 lens work!
  for i in 0..<n: x[i]=rand(9)  # 9 keeps sums short
  tru.setLen n
  discard getrandom(tru[0].addr, n.uint64 shl 3, 0.cuint)
  for i in 0..<n: tru[i] = tru[i] and mask

proc runTrue(x: seq[int], nAcc: int): int =
  for i in 1..nAcc: result += x[tru[i]]

proc fmt(x=0.0, n=3): auto = formatFloat(x, ffDecimal, n)

proc time(prep, run: auto; n, nAcc, avgN, minN: int) =
  var dtMins: RunningStat
  var s = 0                     # Block skipping all work
  var x = newSeq[int](n)
  x.prep n
  for avgIt in 1..avgN:
    var dtMin = float.high
    for minIt in 1..minN:
      let t0 = epochTime()
      s += x.run(nAcc)
      dtMin = min(dtMin, (epochTime() - t0)*1e9/nAcc.float)
    dtMins.push dtMin
  echo "KiB: ", n shr 7, " ns/Access: ", fmt(dtMins.mean),
       " +- ", fmt(dtMins.standardDeviationS), " s:", s

type Algo = enum ranElt, shuff, truRan

proc lat*(kind=shuff, sizeKiB=1048576, nAcc=1_000_000,
          avgN=4, minN=4, seed=0) =
  ## Time latency three ways. shuffle measures real latency.
  if seed > 0: r = initRand(seed)
  else: randomize(); r = initRand(rand(100000))
  let n = (sizeKiB shl 10) shr 3    # or shl 7
  case kind
  of shuff : time(prepShuffle, runShuffle, n,nAcc,avgN,minN)
  of ranElt: time(prepRanElt , runRanElt , n,nAcc,avgN,minN)
  of truRan: time(prepTrueRan, runTrue   , n,nAcc,avgN,minN)

dispatch(lat, help = {"kind": "shuff: chase ran perm\n" &
                              "ranElt: access ran elt\n" &
                              "truRan: pre-read getrandom",
                      "seed": "0=>random, else set" })
