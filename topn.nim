import cligen, cligen/[mfile, mslice, osUt], std/heapqueue
from std/strutils as su import nil
when not declared(stderr): import std/syncio

proc pyIx[T](vs: openArray[T], i: int): T = vs[if i < 0: i + vs.len else: i]

proc topn*(input="/dev/stdin", delim=" ", mxCol=0, n=0, specs: seq[string]) =
  ## Write spec'd cols of topN-rows-by-various-other-cols to outFile's.  A spec
  ## is `<n>[,<sort-key-col>(0)[,outCol(same)[,outFile(stdout)]]]`.  ColNos are
  ## Py-like 0-origin,signed.  Algo is fast one-pass over (mmap|stream) input.
  ## Eg: ``topn 10,1,-1,x`` writes last col of top 10-by-col-1 rows to file x.
  ## If `n!=0` then `<n>` can end in % to instead mean *100\*pct/n* rows.
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
    keyC[i] = if params.len > 1: su.parseInt(params[1]) else: 0
    oCol[i] = if params.len > 2: su.parseInt(params[2]) else: keyC[i]
    oFil[i] = if params.len > 3: open(params[3], fmWrite) else: stdout
  let sep = initSep(delim)              # Init into-seq[MSlice] splitter
  var row: seq[MSlice] = @[]
  let mf = mopen(input)

  template sweep(mf, T, i, outsVal) {.dirty.} =
    type Rec = tuple[val: float32; outs: T]
    var hqs = newSeq[HeapQueue[Rec]](m)
    var rec: Rec
    for line in mSlices(mf, eat='\0'):  # RO mmap | slices from stdio
      sep.split(line, row, mxCol)       # split into columns
      for i in 0 ..< m:                 # update our 1-to-several HeapQueues
        rec.val  = parseFloat(pyIx(row, keyC[i])).float32
        rec.outs = outsVal          #XXX Better to make `int` index to saved?
        if hqs[i].len < nTop[i]:    # memcmp savings dep.on float key uniqueness
          hqs[i].push rec.move      # `$pyIx(..)` in outsVal made any needed cpy
        elif rec > hqs[i][0]:
          discard hqs[i].replace rec.move
    for i in 0 ..< m:                   # Pop out like sort -gk<C+1>|tail -n<n>
      while hqs[i].len > 0:
        oFil[i].urite hqs[i].pop.outs, "\n"
      if not oFil[i].isNil and oFil[i] != stdout:
        oFil[i].close

  if mf.mem.isNil: sweep(input, string, i, $pyIx(row, oCol[i]))
  else           : sweep(mf   , MSlice, i, pyIx(row, oCol[i]))

when isMainModule: dispatch topn, help={
  "input": "input data path",
  "delim": "delimiting (repeats=>any num; \"white\")",
  "mxCol": "max columns in input to parse",
  "n"    : "scale for '%' amounts"}
