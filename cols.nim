when not declared(fmWrite): import std/syncio
import std/sets, cligen, cligen/[mfile, mslice, osUt] # mSlices MSlice Sep

type Ranges = seq[Slice[int]] # cg wants `seq[T]` syntax *OR* its semantics
proc cols(input="/dev/stdin", rowDlm='\n', delim="white", output="/dev/stdout",
          sepOut=" ", blanksOk=false, cut=false, origin=1, O0=false, term='\n',
          colRanges: Ranges) =
  ## Write just some columns of input to output; Memory map input if possible.
  let origin = if O0: 0 else: origin
  var outFile = open(output, fmWrite)
  var colSet = initHashSet[int](colRanges.len)
  if cut:
    for r in colRanges:
      for c in r: colSet.incl c
  let sep = initSep delim
  var cols: seq[MSlice] = @[ ]
  for line in mSlices(input, sep=rowDlm, eat='\0'): # RO mmap | 1-use slices
    var wrote = false                   # wrote something &so need sepOut|\n
    sep.split line, cols
    if cut:
      for j, f in cols:
        if (origin + j) in colSet or (origin + j - cols.len) in colSet:
          continue
        if wrote: outFile.urite sepOut
        outFile.urite f
        wrote = true
    else:
      for r in colRanges:
        for i in r:
          let j = if i < 0: i + cols.len else: i - origin
          if j < 0 or j >= cols.len:
              continue
          if wrote: outFile.urite sepOut
          outFile.urite cols[j]
          wrote = true
    if wrote or blanksOk: outFile.urite term

when isMainModule: include cligen/mergeCfgEnv; dispatch cols, help={
  "colRanges": "colNums or A..B | X:Y (in|ex)clusive ranges thereof",
  "input"    : "path to mmap|read as input",
  "rowDlm"   : "inp *row* delimiter character",
  "delim"    : "inp *field* dlm chars; len>0 => fold",
  "output"   : "path to write output file",
  "sepOut"   : "output field separator",
  "blanksOk" : "allow blank output rows",
  "cut"      : "cut/censor specified columns, not keep",
  "origin"   : "origin for colNums; 0=>signed indexing",
  "O0"       : "shorthand for `--origin=0`",
  "term"     : "set output row terminator (e.g. \\\\0)"}, short={"O0": '0'}
