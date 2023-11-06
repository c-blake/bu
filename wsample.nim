import std/[os, tables, strutils, math, random],
       cligen, cligen/[mfile, mslice, osUt, sysUt]

proc loadTokens*(tokens: string): seq[MSlice] = # no close to keep result valid
  for token in mopen(tokens).mSlices: result.add token

type
  Weight* {.packed.} = object       ## Size=8B
    w*    {.bitsize: 15.}: int16    ## weight: up to 32767
    aMul* {.bitsize:  1.}: bool     ## lookup-avoidance-flag: >1 multiplicity
    why*  {.bitsize: 48.}: uint64   ## explanation mask
  WeightTab* = Table[MSlice, Weight]
  Weights* = object
    wtab: WeightTab
    labs: seq[MSlice]
    cnt: Table[MSlice, array[48, uint8]]    # token -> (cnt[labIx] tab for mults
var emptyA: array[48, uint8]

proc loadWeights*(weights="", tokens: seq[MSlice]): Weights =
  result.wtab = initTable[MSlice, Weight](tokens.len)
  for line in mopen(weights).mSlices:       # Keep open to keep `label` valid
    var line = line
    if line.len > 0: line.clipAtFirst '#'
    if line.len == 0: continue
    var cols = line.msplit(0)
    if cols.len != 3: continue
    let path = $cols[0]                     # Format is: PATH WEIGHT LABEL
    let amt  = parseInt($cols[1]).int16
    if path == "BASE":
      for token in tokens: result.wtab.mgetOrPut(token, Weight()).w += amt
    else:
      if (let mf = mopen(path); mf != nil): # No close in case mgetOrPut
        if result.labs.len==48: raise newException(IOError, "too many sources")
        let bit = 1u64 shl result.labs.len
        for token in mf.mSlices:            #..adds a novel `token`.
          if token.len == 0: continue
          var cell = addr result.wtab.mgetOrPut(token, Weight())
          cell.w += amt
          if (cell.why and bit) != 0:       # Bit already on: inc multiples
            cell.aMul = true                # Avoids lookup-to-test in `print`
            result.cnt.mgetOrPut(token, emptyA)[result.labs.len].incSat # Updt>1
          else:
            cell.why = cell.why or bit      # Turn bit on for labs[^1]
        cols[2].mem = cols[2].mem +! -1; cols[2].len += 1 # extend to delim
        result.labs.add cols[2]             # @end to avoid earlier -1/^1's

proc weights*(wt: WeightTab, tokens: seq[MSlice]): seq[float] =
  for t in tokens: result.add float(wt[t].w)

proc meanW(wt: WeightTab): float =
  for wL in wt.values: result += wL.w.float
  result /= wt.len.float

proc print*(wts: Weights, stdize=false) =
  var ws: string
  let meanW = if stdize: wts.wtab.meanW else: 1.0
  for tok, v in wts.wtab:   # hash-order; Maybe novel keys in SRC notin `tokens`
    if stdize: ws = formatFloat(v.w.float/meanW, ffDefault, 4)
    else: ws.setLen 0; ws.addInt v.w
    ws.add " "; ws.add tok; outu ws     # 1 outu faster than outu ws, " ", tok
    let cnt = if v.aMul: wts.cnt[tok] else: emptyA # Good C compiler skips cpy..
    for i, lab in wts.labs:                        #..unless cnt[i] needed below
      if (v.why and (1u64 shl i)) != 0:
        outu lab
        if v.aMul and cnt[i] > 0: outu "*", $(cnt[i] + 1) # `cnt` counts > 1
    outu "\n"

iterator cappedSample*(wt: WeightTab, tokens: seq[MSlice], n=1, m=3): MSlice =
  ## Weighted sample of size ``n`` capping to ``m`` copies of any given token.
  ## This can be useful to weight but bound the skew.  This does bias to make
  ## more heavily weighted tokens earlier in a sample.  Algo does not inf.loop,
  ## but slows down for ``n >~ m*tokens.len``.
  let nEffective = min(n, m * tokens.len)
  let cdf = wt.weights(tokens).cumsummed
  var count: CountTable[MSlice]
  for i in 0 ..< nEffective:    #Algo must infinite loop at >= nEffective
    var s {.noinit.}: MSlice
    while true:                 #Becomes slow after n >=~ (m-1)*tokens.len
      s = sample(tokens, cdf)
      count.inc s
      if count[s] <= m: break
    yield s

when isMainModule:
  when defined(release): randomize()
  when not declared(stdout): import std/syncio
  proc wsample(weights, tokens: string; n=4000, m=3, dir=".",
               explain=false, stdize=false) =
    ## Print `n`-sample of tokens {nl-delim file `tokens`} weighted by path
    ## `weights` which has fmt: SRC W LABEL\\n where each SRC file is a set of
    ## nl-delimited tokens.  BASE in `weights` = `tokens` (gets no label).
    var b = newSeq[char](8192); discard c_setvbuf(stdout, b[0].addr, 0, 8192)
    setCurrentDir dir
    let tokens = loadTokens(tokens)
    let wts = loadWeights(weights, tokens)
    if explain: wts.print stdize; quit 0
    if m > 0:
      for s in wts.wtab.cappedSample(tokens, n, m): outu s, "\n"
    else:
      let cdf = wts.wtab.weights(tokens).cumsummed
      for i in 1..n: outu sample(tokens, cdf), "\n"
  dispatch wsample,help={"weights": "path to weight meta file",
                         "tokens" : "path to tokens file",
                         "n"      : "sample size",
                         "m"      : "max duplicates for any given token",
                         "dir"    : "path to directory to run in",
                         "explain": "print WEIGHT TOKEN SOURCE(s) & exit",
                         "stdize" : "divide explain weight by mean weight"}
