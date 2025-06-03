when not declared(File): import std/syncio
import cligen, cligen/[sysUt, mfile, mslice, osUt], std/parseutils

proc anyNegative(xs: seq[int]): bool = (for x in xs: (if x < 0: return true))
proc outOfOrder(xs: seq[int]): bool =
  for j in 1..<xs.len: (if xs[j] <= xs[j-1]: return true)
proc urite(f: File, ms: MSlice) = discard f.uriteBuffer(ms.mem, ms.len)

const ess: seq[string] = @[]
proc colps(cols: seq[int], origin=1, O0=false, prefix=ess, suffix=ess, input="",
           rowDlm='\n', delim="w", output="") =
  ## COLumn PrefixSuffix: `input`-`output` filter adding `prefix` &| `suffix` to
  ## specified `delim`-delimited `cols`, preserving all delimiting.  Columns,
  ## prefix, suffix *share indexing* (so you may need to pad with `""`).  E.g.:
  ##   **paste <(seq 1 3) <(seq 4 6)  <(seq 7 9) | colps -pA -sB 1 -pC 3**
  if cols.len < 1: Help !! "Need >= 1 column; Full $HELP"
  if cols.outOfOrder: Help !! "Need firstCol < secondCol ...; Full $HELP"
  let origin = if O0: 0 else: origin
  var outp = if output.len > 0: open(output, fmWrite) else: stdout
  let sep = initSep delim                                 # Parse delimiter
  let xfm = origin == 0 and cols.anyNegative              # Transform indexing
  var fs: seq[TextFrame]                                  # Frames
  var ac = cols; var m0 = 0                               # Absolute Column
  for ln in mSlices(input, sep=rowDlm, eat='\0'):         # RO mmap|1-use slices
    let m = ln.frame(fs, sep)                             # Make frames
    if m == 0: discard outp.uriteBuffer(ln.mem, ln.len)
    else:
      if xfm:
        if m != m0:             # Re-use last ac[] if `m` same as last loop
          copyMem ac[0].addr, cols[0].addr, ac.len*ac[0].sizeof
          for c in mitems ac: (if c < 0: c += (m + 1) div 2)
          m0 = m
      var dc, par = 0   # 3 indices: Raw fs[j], dataCol, param (& ac[that]==dc)
      for j in 0..<m:   #NOTE Lines starting|ending w/delimiters get "".ms ..
        if fs[j].isSep: #  .. frames.  Maybe bubble up something to CLI?
          outp.urite fs[j].ms; inc dc
        elif par < ac.len and origin + dc == ac[par]:
          if prefix.len > par and prefix[par].len > 0: outp.urite prefix[par]
          outp.urite fs[j].ms
          if suffix.len > par and suffix[par].len > 0: outp.urite suffix[par]
          inc par
        else: outp.urite fs[j].ms
    outp.urite "\n"

when isMainModule: dispatch colps, help={
  "cols"  : "`origin`-origin column numbers",
  "origin": "origin for `cols`; 0=>signed indexing",
  "O0"    : "shorthand for `--origin=0`",
  "prefix": "strings to prepend to listed columns",
  "suffix": "strings to append to listed columns",
  "input" : "path to mmap|read as input; \"\" => stdin",
  "rowDlm": "`input` *row* delimiter character",
  "delim" : "`input` *field* dlm chars; len>0=>fold;w=white",
  "output": "path to write output file; \"\" => stdout"}, short={"output":'o'}
