when not declared(stdout): import std/syncio
import cligen/[osUt, textUt, mslice]

var pad: string                         # reused pad buffer
template prPad(n: int) =
  if n > pad.len:                       # should achieve steady state fast
    pad.setLen n
    for c in pad.mitems: c = ' '
  if n >= 0: discard stdout.uriteBuffer(cast[pointer](pad.cstring), n)

proc pr(str: string; sWidth, width: int; algn: string; last: bool) =
  let extra = max(1, width) - sWidth
  case algn[0]
  of '-': outu str; (if not last: prPad extra)
  of '+': prPad extra; outu str
  of '0': (let nL = extra div 2; prPad nL; outu str; prPad extra - nL)
  else: discard #raise?

var doPL = false
proc mPL(s: string): int = (if doPL: s.printedLen else: s.len) # MaybePrintedLen

proc align(delim=",", maxCol=0, prLen=false, sepOut=" ", origin0=false,
           origin1=false, null="", empty="", alignSpecs: seq[string]): int =
  ## This stdin-out filter aligns an ASCII table & optionally emits header rows
  ## with widths/colNos.  Zero or more alignSpecs control output alignment:
  ##   - left aligned (default)
  ##   + right aligned
  ##   0 centered
  ## The final alignSpec is used for any higher, unspecified columns.  E.g.:
  ##   ``align -d : - + + + - < /etc/passwd``
  ## left aligns all but 2nd,3rd,4th
  template maxEq(mx,x) = mx = max(mx,x) # Accumulate in analogy with += | *=
  let nEmpty = empty.mPL                # Some minor parameter postprocessing
  let nNull  = null.mPL
  let origin = if origin0: 0 elif origin1: 1 else: -1
  var rows: seq[seq[string]]            # Our main data table
  var blanks: seq[int]                  # Run max width, blankLn locs
  var n, m: int                         # Input line number, Num of columns
  var aligns = alignSpecs               # `alignSpecs` padded to max cols seen
  if aligns.len == 0: aligns.add "-"    # Default empty `alignSpecs` => @["-"]
  var w = newSeq[int](aligns.len)
  let dlm = delim.initSep               # Compile delim string into a splitter
  for line in stdin.lines:              # PASS1: COLLECT WIDTHS AND MAYBE DATA
    inc n
    if line.len == 0:                   # Blank line:
      blanks.add n; continue            #  Record its location, but nothing else
    let cols = dlm.split(line, maxCol)
    if n < 20:                          # Heuristic on head sample decides doPL
      doPL = doPL or prLen or line.printedLen != line.len
    while aligns.len < cols.len:        # Maybe expand col width tracker..
      aligns.add aligns[^1][0..^1]      # Copy last spec onward
      w.add if m == 0: 0 else: nNull    # 0 for 1st row, after a null pad value
    m.maxEq w.len
    for j, col in cols:                 # Track per column max width
      let wj = col.mPL
      w[j].maxEq if wj>0: wj else: nEmpty
    for j in cols.len ..< m:            # Include nNull if miss vals ever occur
      w[j].maxEq nNull
    rows.add cols                       # Save Table
  if rows.len == 0: return 2            # No non-empty lines; DONE; (Likely err)
  if origin >= 0:                       # PASS2a: PRINT FORMATTED METADATA
    for j in 0..<m:                     # Print numeric column headers
      if j != 0: outu sepOut
      let s = $(origin + j)
      w[j].maxEq s.len                  # Index may be wider than header/data!
      pr s, s.len, w[j], aligns[j], j+1 == m
    outu '\n'
  var bIx = 0                           # PASS2b: PRINT FORMATTED DATA
  n = 0                                 # This loop basically just reproduces..
  for cols in rows:                     # ..the recorded parsing state machine.
    inc n                               # bump line number
    while bIx < blanks.len and blanks[bIx] == n: outu "\n"; inc bIx; inc n
    for j, col in cols:
      if j != 0: outu sepOut
      let wj = col.mPL
      if wj>0: pr col  , wj    , w[j], aligns[j], j+1 == m
      else   : pr empty, nEmpty, w[j], aligns[j], j+1 == m
    for j in cols.len ..< m:
      outu sepOut; pr null, nNull, w[j], aligns[j], j+1 == m
    outu '\n'

when isMainModule:
  import cligen; include cligen/mergeCfgEnv; dispatch align, help={
    "delim"  : "inp delim chars; Any repeats => foldable",
    "maxCol" : "max columns to form for aligning;0=unlimited",
    "prLen"  : "force adjust for ANSI SGR escape sequences",
    "sepOut" : "output separator (beyond just space padding)",
    "origin0": "print a header of 0-origin column labels",
    "origin1": "print a header of 1-origin column labels",
    "null"   : "output string for cell introduced as padding",
    "empty"  : "output string for empty internal cell/header"},
    short={"origin0": '0', "origin1": '1'}
