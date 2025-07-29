import cligen, cligen/[mfile, mslice, osUt], adix/topk
from std/strutils as su import nil
when not declared(stderr): import std/syncio

proc pyIx(x: openArray[MSlice], i: int): MSlice = x[if i < 0: i + x.len else: i]
proc pyIx(x: openArray[MSlice], s: Slice[int]): MSlice =
  let a = if s.a < 0: s.a + x.len else: s.a
  let b = if s.b < 0: s.b + x.len else: s.b   # b < a | Out of bounds -> ""
  if b < a or a + 1 > x.len or b + 1 > x.len: result.mem = nil; result.len = 0
  else: result.mem = x[a].mem; result.len = x[b].mem +! x[b].len -! x[a].mem

proc topn*(input="/dev/stdin", delim=" ", mxCol=0, n=0, order=Cheap,
           partn=Partn.last, specs: seq[string]) =
  ## Write spec'd cols of topN-rows-by-various-other-cols to outFile's.  A spec
  ## is `<N>[,<keyCol>(0)[,outCol(same)[,outFile(stdout)]]]`. ColNos are Py-like
  ## 0-origin,signed.  *outCol* can be an A:B exclusive or A..B slice.  Algo is
  ## fast one-pass over (mmap|stream) input.  Simple & Fancy E.g.s:
  ##  ``find . -type f -printf '%C@ %p\\n' | topn -m1 5``  # newest 5 by ctime
  ##  ``topn 9,1,-1,x`` # writes last col of top 9-by-col-1 rows to file x.
  ## If `n!=0` then `<N>` can end in '%' to instead mean *100\*pct/n* rows.
  let m = specs.len                     # Handle all `m` sort orders in one pass
  if m < 1: stderr.write "No specs requested.  -h for help.\n"; return
  var keyC = newSeq[int](m)
  var nTop = newSeq[int](m)
  var oCol = newSeq[Slice[int]](m)
  var oFil = newSeq[File](m)
  for i, spec in specs:                 # Parse key-output specifiers
    let params = su.split(spec, ',')
    if params.len < 1:
      stderr.write "too few sub-params in spec ", spec, "\n"; continue
    let p0 = params[0]
    nTop[i] = if su.endsWith(p0, '%'): su.parseInt(p0[0..^2]) * n div 100
              else: su.parseInt(p0)
    nTop[i] = max(1, nTop[i])
    keyC[i] = if params.len > 1: su.parseInt(params[1]) else: 0
    oCol[i]=if params.len>2:parseHSlice[int,int](params[2])else:keyC[i]..keyC[i]
    oFil[i] = if params.len > 3: open(params[3], fmWrite) else: stdout
  let sep = initSep(delim)              # Init into-seq[MSlice] splitter
  var row: seq[MSlice] = @[]
  let mf = mopen(input)

  template sweep(mf, T, i, outsVal) {.dirty.} =
    type Rec = tuple[val: float32; outs: T]
    var tops: seq[TopK[Rec]]
    for i in 0 ..< m: tops.add initTopK[Rec](nTop[i], partn)
    var rec: Rec
    for line in mSlices(mf, eat='\0'):  # RO mmap | slices from stdio
      sep.split(line, row, mxCol)       # split into columns
      for i in 0 ..< m:                 # update our 1-to-several `TopK`
        rec.val  = parseFloat(pyIx(row, keyC[i])).float32 # tuned4 float rarity
        rec.outs = outsVal
        tops[i].push rec.move           # `$pyIx(..)` in outsVal maybe made cpy
    for i in 0 ..< m:                   # Emit like sort -gk<C+1>|tail -n<n>|tac
      for e in tops[i].maybeOrdered(order): oFil[i].urite e.outs, "\n"
      if not oFil[i].isNil and oFil[i] != stdout: oFil[i].close

  # rec.outs become either GC'd `string` or no-need-to-GC `MSlice`
  if mf.mem.isNil: sweep(input, string, i, $pyIx(row, oCol[i]))
  else           : sweep(mf   , MSlice, i,  pyIx(row, oCol[i]))

when isMainModule: include cligen/mergeCfgEnv; dispatch topn, help={
  "input": "input data path",
  "delim": "delimiting (repeats=>any num; \"white\")",
  "mxCol": "max columns in input to parse",
  "n"    : "scale for '%' amounts",
  "partn": "partition: last, ran",
  "order": "order: Cheap, Ascending, Descending"}
