when not declared(addFloat): import std/formatfloat
import cligen/[mfile, mslice, strUt], adix/uniqce

proc uce*(input="/dev/stdin", k=1024, re=0..5, fmt1="$val0 +- $err0",
          expF="($valMan +- $errV)$valExp") =
  ## Emit Unique Count Estimate of `input` lines to stdout.  Algo is fast, low
  ## space 1-pass KMV over mmap | stream input. (For exact, see `lfreq`.)
  var uce = initUniqCe[float](k)
  for line in mSlices(input, eat='\0'): # RO mmap | slices from stdio
    when defined(cHash):
      let h = float(cast[uint64](hash(line)))*(1.0/1.8446744073709551615e19)
    else:                               # std/hashes(data) sadly only 32-bits!
      let h = float(cast[uint32](hash(line)))*(1.0/4294967295.0)
    uce.push h
  if fmt1.len == 0:                     # The 2 estimates to full float prec
    echo uce.nUnique, " ", uce.nUniqueErr
  else: # Near-exact to fmt as "15.00"; Err is technically hash-collision rate
    echo fmtUncertain(uce.nUnique, max(uce.nUniqueErr, 0.1), fmt1, expF, re)

when isMainModule:
  import cligen                                       # Wide defaults => drop
  clCfg.hTabCols = @[clOptKeys, clDflVal, clDescrip]  #..the data type column
  include cligen/mergeCfgEnv                          # Allow cfg files for +-
  dispatch uce, help={"input": "input data path",
                      "k"    : "size of the sketch in float64 elts",
                      "re"   : "range of 10expon defining 'near 1'",
                      "fmt1" : "fmt for uncertain num near 1",
                      "expF" : "fmt for uncertain num beyond `re`"}
