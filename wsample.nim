import os, tables, strutils, math, random, cligen, cligen/[mfile, mslice, osUt]

proc loadTokens*(tokens: string): seq[MSlice] = # no close to keep result valid
  for token in mopen(tokens).mSlices: result.add(token)

type
  Weight* = tuple[w: int, labels: seq[MSlice]]
  WeightTab* = Table[MSlice, Weight]

proc loadWeights*(weights="", tokens: seq[MSlice]): WeightTab =
  result = initTable[MSlice, Weight](tokens.len)
  let empty: Weight = ( 0, newSeqOfCap[MSlice](1) )
  for line in mopen(weights).mSlices: # no close to keep `label` valid
    if line.len == 0 or line[0] == '#':
      continue
    let cols = line.msplit(0)
    if cols.len != 3:
      continue
    let path  = $cols[0]
    let amt   = parseInt($cols[1])
    let label = cols[2]
    if path == "BASE":
      for token in tokens: result.mgetOrPut(token, empty).w += amt
    else:
      if (let mf = mopen(path); mf) != nil: # No close in case mgetOrPut
        for token in mf.mSlices:            #..adds a novel `token`.
          var cell = addr result.mgetOrPut(token, empty)
          cell.w += amt; cell.labels.add label

proc weights*(wt: WeightTab, tokens: seq[MSlice]): seq[float] =
  for t in tokens: result.add float(wt[t].w)

proc meanW(wt: WeightTab): float =
  for wL in wt.values: result += wL.w.float
  result /= wt.len.float

proc print*(wt: WeightTab, tokens: seq[MSlice], stdize=false) =
  let space = " "; let spc = toMSlice(space)
  let meanW = if stdize: wt.meanW else: 1.0
  for tok in tokens:
    let wL = wt[tok]
    let ws = if stdize: formatFloat(wL.w.float/meanW, ffDefault, 4) else: $wL.w
    outu ws, spc, tok
    var last = spc
    var cnt = 1
    for lab in wL.labels:
      if lab == last: cnt.inc
      else:
        if cnt > 1: outu "*", cnt
        outu spc, lab
        cnt = 1
      last = lab
    if cnt > 1: outu "*", cnt
    outu "\n"

proc cappedSample*(wt: WeightTab, tokens: seq[MSlice], n=1, m=3): seq[MSlice] =
  ## Weighted sample of size ``n`` capping to ``m`` copies of any given token.
  ## This can be useful if to weight but bound the skew.  This does bias to make
  ## more heavily weighted tokens earlier in a sample.  Algo does not inf.loop,
  ## but slows down for ``n >~ m*tokens.len``.
  let nEffective = min(n, m * tokens.len)
  let cdf = wt.weights(tokens).cumsummed
  var count: CountTable[MSlice]
  for i in 0 ..< nEffective:    #Algo must infinite loop at >= nEffective
    var s {.noinit.}: MSlice
    while true:                 #Becomes slow after n >=~ (m-1)*tokens.len
      s = sample(tokens, cdf)
      count.inc(s)
      if count[s] <= m: break
    echo s

when isMainModule:
  when defined(release): randomize()
  proc wsample*(weights, tokens: string; n=4000, m=3, dir=".",
                explain=false, stdize=false) =
    ## Print `n`-sample of tokens {nl-delim file `tokens`} weighted by path
    ## `weights` which has fmt: SRC W LABEL\\n where each SRC file is a set of
    ## nl-delimited tokens.  BASE in `weights` = `tokens` (gets no label).
    setCurrentDir(dir)
    let tokens = loadTokens(tokens)
    let wt = loadWeights(weights, tokens)
    if explain:
      wt.print(tokens, stdize); quit(0)
    if m > 0:
      for s in wt.cappedSample(tokens, n, m): echo s
    else:
      let cdf = wt.weights(tokens).cumsummed
      for i in 1..n: echo sample(tokens, cdf)
  dispatch wsample,help={"weights": "path to weight meta file",
                         "tokens" : "path to tokens file",
                         "n"      : "sample size",
                         "m"      : "max duplicates for any given token",
                         "dir"    : "path to directory to run in",
                         "explain": "print WEIGHT TOKEN SOURCE(s) & exit",
                         "stdize" : "divide explain weight by mean weight"}
