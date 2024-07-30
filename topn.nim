import cligen, cligen/[mfile, mslice, osUt], adix/topk
from std/strutils as su import nil
when not declared(stderr): import std/syncio

proc pyIx[T](vs: openArray[T], i: int): T = vs[if i < 0: i + vs.len else: i]

proc topn*(input="/dev/stdin", delim=" ", mxCol=0, n=0, order=Cheap,
           partn=Partn.last, specs: seq[string]) =
  ## Write spec'd cols of topN-rows-by-various-other-cols to outFile's.  A spec
  ## is `<n>[,<sort-key-col>(0)[,outCol(same)[,outFile(stdout)]]]`.  ColNos are
  ## Py-like 0-origin,signed.  Algo is fast one-pass over (mmap|stream) input.
  ## Simple Eg: ``find . -type f -printf '%C@ %p\\n' | topn -m1 5``.  Fancy Eg:
  ## ``topn 9,1,-1,x`` writes last col of top 9-by-col-1 rows to file x.  If
  ## `n!=0` then `<n>` can end in % to instead mean *100\*pct/n* rows.
  let m = specs.len                     # Handle all `m` sort orders in one pass
  if m < 1: stderr.write "No specs requested.  -h for help.\n"; return
  var keyC = newSeq[int](m)
  var nTop = newSeq[int](m)
  var oCol = newSeq[int](m)
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
    oCol[i] = if params.len > 2: su.parseInt(params[2]) else: keyC[i]
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

  if mf.mem.isNil: sweep(input, string, i, $pyIx(row, oCol[i]))
  else           : sweep(mf   , MSlice, i,  pyIx(row, oCol[i]))

when isMainModule: include cligen/mergeCfgEnv; dispatch topn, help={
  "input": "input data path",
  "delim": "delimiting (repeats=>any num; \"white\")",
  "mxCol": "max columns in input to parse",
  "n"    : "scale for '%' amounts",
  "partn": "partition: last, ran",
  "order": "order: Cheap, Ascending, Descending"}
