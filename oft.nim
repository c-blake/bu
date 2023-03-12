import cligen, cligen/[mfile, mslice, osUt], adix/amoft, std/math
from std/strutils as su import nil
when not declared(stderr): import std/syncio

proc pyIx[T](vs: openArray[T], i: int): T = vs[if i < 0: i + vs.len else: i]

proc oft*(input="/dev/stdin", delim=" ", mxCol=0, errate=0.005, cover=0.98,
          salts: seq[int] = @[], specs: seq[string]) =
  ## Write most often seen N keys in various columns to outFile's.  Specs are
  ## `<n>[,<keyCol>(0)[,outFile(stdout)]]`.  ColNos are Py-like 0-origin,signed.
  ## Algorithm is approximate fast one-pass over mmap|stream input.  E.g., to
  ## write most frequent final column to stdout do: ``oft 10,-1``. (For exact,
  ## see `lfreq`, possibly with column splitting to FIFOs).
  let k    = specs.len                  # Handle all `k` keys in one pass
  if k < 1: stderr.write "No specs requested.  -h for help.\n"; return
  var keyC = newSeq[int](k)
  var oFil = newSeq[File](k)
  var amos = newSeq[AMOft[string, uint32]](k)
  let w    = ceil(exp(1.0)/errate).int  # Qs: Make per key-col?  Snap to pow2?
  let nTab = ceil(-ln(1.0 - cover)).int
  for i, spec in specs:                 # Parse key-output specifiers
    let params = su.split(spec, ',')
    if params.len < 1:
      stderr.write "too few sub-params in spec ", spec, "\n"; continue
    amos[i] = initAMOft[string, uint32](su.parseInt(params[0]), w, nTab, salts)
    keyC[i] = if params.len > 1: su.parseInt(params[1]) else: 0
    oFil[i] = if params.len > 2: open(params[2], fmWrite) else: stdout
  let sep = initSep(delim)              # Init into-seq[MSlice] splitter
  var row: seq[MSlice] = @[]
  let mf = mopen(input)

  template sweep(mf, T) {.dirty.} =
    for line in mSlices(mf, eat='\0'):  # RO mmap | slices from stdio
      sep.split(line, row, mxCol)       # split into columns
      for i in 0 ..< k:                 # update our 1-to-several OftAs
        amos[i].inc $pyIx(row, keyC[i])
    for i in 0 ..< k:                   # Pops out like sort -gk<C+1>|tail -n<n>
      for (k, c) in amos[i].mostCommon: oFil[i].urite c, " ", k, "\n"
      if not oFil[i].isNil and oFil[i] != stdout: oFil[i].close

  if mf.mem.isNil: sweep(input, string) else: sweep(mf, MSlice)

when isMainModule: dispatch oft, help={
  "input" : "input data path",
  "delim" : "delimiting (repeats=>any num; \"white\")",
  "mxCol" : "max columns in input to parse",
  "errate": "size tables to make err `nSamp\\*this`",
  "cover" : "enough tables to make coverage this",
  "salts" : "override random salts"}
