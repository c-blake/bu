when not declared(stdout): import std/syncio
import cligen/[sysUt, osUt, textUt, mslice, mfile]; const f=false
type
  Align = enum L, R, C
  Col = object                  ## Per-Column Metadata Encapsulation
    al: Align                   ## Align code
    w, bc, ac,                  ## Rendered Width, Before, After `ch`,
      cEm, cNil, wEm: int       ##   ix(ch) within empty & null strings; em.pL
    em: string                  ## How to spell Internal Empty fields
    ch: char                    ## Radix-like align char; '\0'=>none
    cs: set[char]               ## DecimalDigits-like ChSet w/implied radix @end

var doPL = f
proc pL(s: MSlice): int = printedLen(s.toOpenArrayChar) # shorthand
proc mPL(s: MSlice): int = (if doPL: s.pL else: s.len)  # M)aybe P)rinted L)en

func findA(col: MSlice, ch: char, cs: set[char]): int =
  if ch == '\0': return -1              #TODO To work w/SGR|utf8 in play this..
  result = col.rfind(ch)                #..must do RENDERED not BYTE distance.
  if result < 0:                        # Last radix point OR..
    result = col.rfind(cs)              #   just after final ASCII dig
    if result >= 0: inc result          #   (if there even is one)

proc acParse(s: string): set[char] =    # Micro ASCII character set parser:
  var start, last: char                 # Leading "---" puts '-' itself in set
  for ch in s:                          # No negations; only chs & inclusive -
    if   start == '\0' and ch == '-': start = last
    elif start != '\0':
      for e in start .. ch: result.incl e
      start = '\0'
    else: result.incl ch
    last = ch

proc init(cms: var seq[Col]; alignSpecs, aSet, empties: seq[string];
          null: string) =
  var acKey: seq[char]; var acVal: seq[set[char]]
  for ac in aSet: acKey.add ac[0]; acVal.add ac[1..^1].acParse
  var emKey: seq[char]; var emVal: seq[string]
  for empty in empties:
    if empty.len > 0:                   # Ignore empty empties
      if (let i=emKey.find('e'); i >= 0): emVal[i] = empty[1..^1]
      else: emKey.add empty[0]; emVal.add empty[1..^1]
  let emDef = if (let i=emKey.find('e'); i >= 0): emVal[i]
              else: IO!!"no empty default 'e'"
  for asp in alignSpecs:
    if asp.len < 1: IO!!"empty string alignSpec"
    cms.setLen cms.len + 1              # New slot is zero initialized
    cms[^1].em = emDef
    cms[^1].al = case asp[0]            #<AL>[(emptyCode|aByte|setCode)*][<R>]
      of '-': L
      of '0': C
      of '+': R
      else: IO!!"unknown alignment: " & asp[0]
    for j, ch in asp[1 ..< min(5, asp.len)]: # Digit for <R> must occur by [4]
      if   (let i=emKey.find(ch); i>=0): cms[^1].em = emVal[i]
      elif (let i=acKey.find(ch); i>=0): cms[^1].cs  = acVal[i]
      elif ch in {'0'..'9'}:            # Repetition count <R>
        var s = asp[j..^1]
        for k in 0 ..< parseInt(s.toMSlice) - 1: cms.add cms[^1]
      else: cms[^1].ch = ch
  if cms.len == 0: cms.add Col(al: L)
  for cm in cms.mitems:
    cm.wEm  = cm.em.toMSlice.pL
    cm.cEm  = cm.em.toMSlice.findA(cm.ch, cm.cs)
    cm.cNil = null.toMSlice.findA(cm.ch, cm.cs)

var pad: string                         # reused pad buffer
template prPad(n: int) =
  if n > pad.len:                       # should achieve steady state fast
    pad.setLen n
    for c in pad.mitems: c = ' '
  if n >= 0: discard stdout.uriteBuffer(cast[pointer](pad.cstring), n)

proc pr(str: MSlice; sWidth, width, bc, ci: int; al: Align; last: bool) =
  if ci < 0:                            # Ordinary alignment OR no ch present
    let extra = max(1, width) - sWidth
    case al                             # pad w/space to left|right|center align
    of L: outu str; (if not last: prPad extra)
    of C: (let nL = extra div 2; prPad nL; outu str; prPad extra - nL)
    of R: prPad extra; outu str
  else:                                 # ch-aligned; this field char ix is `ci`
    let leading = max(0, bc - ci)
    prPad leading; outu str; prPad width - str.len - leading

proc align(input="-", delim=",", maxCol=0, prLen=f, aSet = @["d0-9"],
           sepOut=" ", origin0=f, origin1=f, null="", empties = @["e"],
           debug=false, alignSpecs: seq[string]): int =
  ## stdInOut filter to align an ASCII table & optionally emit colNo header row.
  ## Zero or more alignSpecs control output alignment:
  ##   -[(emptyCode|aByte|setCode)*][<R(1)>] Left Align R columns (default)
  ##   0[(emptyCode|aByte|setCode)*][<R(1)>] Center R columns
  ##   +[(emptyCode|aByte|setCode)*][<R(1)>] Right Align R columns
  ## where
  ##   `emptyCode` Names the empty string for a column; absent => 'e'
  ##   `aByte`     Specifies '.'|','-like alignment byte; cannot be 'e'
  ##   `setCode`   Names digit-like set w/an implied trailing align byte (only
  ##               if byte missing).  Cannot collide with char code emptyCode.
  ## The final `alignSpec` is used for any higher, unspecified columns.  E.g.:
  ##   ``align -d=: -enN/A - + +. +.nd - < /etc/passwd | less -S``
  ## left aligns all 7 but 2nd,3rd,4th w/3&4th '.'-align w/fallback to right &
  ## 4th w/"N/A" empties & implicit '.' (all others have a default "" empty).
  template maxEq(mx,x) = mx = max(mx,x) # Accumulate in analogy with += | *=
  template cm:untyped {.dirty.}= cms[j] # Consistently index `cms` w/`j`
  template cUp(j, rexp, cL) =           # radix char column widths update
    let c = rexp
    cm.bc.maxEq if c >= 0: c.int      else: 0
    cm.ac.maxEq if c >= 0: cL - c.int else: 0
  var cms: seq[Col]                     # Metadata for all columns
  let nNull  = null.printedLen          # Minor parameter postprocessing
  let origin = if origin0: 0 elif origin1: 1 else: -1
  var rows: seq[MSlice]                 # Our main data table
  var blanks: seq[int]                  # Run max width, blankLn locs
  var n, m: int                         # Input line number, Num of columns
  cms.init alignSpecs,aSet,empties, null # empty=>left, padded to max seen
  let dlm = delim.initSep               # Compile delim string into a splitter
  var cols: seq[MSlice]
  var mf: MFile                         # mf.mem.isNil => allocated & copied
  for line in mSlices(input, mf=mf):    # stdio RO mmap | slices
    inc n                               # PASS1: COLLECT WIDTHS & DATA
    if line.len == 0:                   # Blank line:
      blanks.add n; continue            #  Record its location, but nothing else
    dlm.split line, cols, maxCol
    if n < 20:                          # Heuristic on head sample decides doPL
      doPL = doPL or prLen or line.pL != line.len
    while cms.len < cols.len:           # Maybe expand col width tracker..
      cms.add cms[^1]                   # Copy last spec onward
      cms[^1].w = if m>0: nNull else: 0 # 0 for 1st row, after a null pad value
    m.maxEq cms.len
    for j, col in cols:                 # Track per column max width
      let wj = col.mPL
      cm.w.maxEq if wj>0: wj else: cm.wEm
      if cm.ch != '\0':                 # CAN save all @maybe much mem expense
        if col.len>0: cUp(j, col.findA(cm.ch, cm.cs), col.len)
        else:         cUp(j, cm.cEm                 , cm.wEm)
    for j in cols.len ..< m:            # Include nNull if miss vals ever occur
      cm.w.maxEq nNull
      cUp(j, cm.cNil, nNull)
    rows.add if mf.mem.isNil: line.dup else: line # Split fastEnough2save `line`
  if rows.len == 0: return 2            # No non-empty lines; DONE; (Likely err)
  for cm in cms.mitems:                 # Accumulate B)efore&A)fter C)har widths
    cm.w = max(cm.w, cm.bc + cm.ac)
  if origin >= 0:                       # PASS2a: PRINT FORMATTED METADATA
    for j in 0..<m:                     # Print numeric column headers
      if j != 0: outu sepOut
      let s = $(origin + j)
      cm.w.maxEq s.len                  # Index may be wider than header/data!
      pr s.toMSlice, s.len, cm.w, 0, -1, cm.al, j+1 == m
    outu '\n'
  if debug: (for cm in cms: erru ' ', cm.repr, '\n')
  var bIx = 0; n = 0                    # PASS2b: PRINT FORMATTED DATA
  for line in rows:                     # Reproduce parse-recorded state machine
    inc n                               # Bump line number to ape blank pattern
    while bIx < blanks.len and blanks[bIx] == n: outu "\n"; inc bIx; inc n
    dlm.split line, cols, maxCol
    for j, col in cols:                 # 2b1: Print aligned leading columns
      if j != 0: outu sepOut
      let wj = col.mPL                  # Get m)aybe-p)rinted-l)en of this col
      let ci = col.findA(cm.ch, cm.cs)  # Find "Radix" or Just after in `cs`
      if wj>0: pr col,             wj, cm.w, cm.bc, ci    , cm.al, j+1 == m
      else: pr cm.em.toMSlice, cm.wEm, cm.w, cm.bc, cm.cEm, cm.al, j+1 == m
    for j in cols.len ..< m:            # 2b2: Maybe add null padding
      outu sepOut; pr null.toMSlice, nNull, cm.w, cm.bc, cm.cNil, cm.al, j+1==m
    outu '\n'

when isMainModule:
  import cligen; include cligen/mergeCfgEnv; dispatch align, help={
    "input"  : "path to mmap|read as input; \"-\" => stdin",
    "delim"  : "inp delim chars; Any repeats => foldable",
    "maxCol" : "max columns to form for aligning;0=unlimited",
    "prLen"  : "force adjust for ANSI SGR escape sequences",
    "aSet"   : "byteCharacterSet bindings; \"-\" => a range",
    "sepOut" : "output separator (beyond just space padding)",
    "origin0": "print a header of 0-origin column labels",
    "origin1": "print a header of 1-origin column labels",
    "null"   : "output string for cell introduced as padding",
    "empties": "byteString binds for missing internal cells",
    "debug"  : "emit indented alignment metadata to stderr"},
    short={"origin0": '0', "origin1": '1', "debug": 'g'}
