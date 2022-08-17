import cligen, cligen/[textUt, mslice]  # printedLen Sep
from strutils import nil #unqualifiedVisibility(strutils.align) breaks dispatch

proc pr(str: string; sWidth, width: int; algn, pad: string) {.inline.} =
  proc prPad(n: int, p=pad) {.inline.} =
    if n < 0: return                    # cannot possibly pad
    discard stdout.writeBuffer(cast[pointer](cstring(p)), n)
  let extra = max(1, width) - sWidth
  case algn[0]
  of '-': stdout.write(str); prPad(extra)
  of '+': prPad(extra); stdout.write(str)
  of '0':
    let nL = extra div 2
    prPad(nL); stdout.write(str); prPad(extra - nL)
  else: discard #raise?

proc findSGR(row: seq[string]): bool {.inline.} =
  for w in row:
    if strutils.startsWith(w, "\e[") and w.len > 2 and w[2] in strutils.Digits:
      return true

var usePrLen = false

proc mpl(s: string): int {.inline.} =   #mpl=(m)aybe(p)rinted(l)en
  result = if usePrLen: printedLen(s): else: s.len

proc align(delim=",", sepOut=" ", origin0=false, origin1=false, widths=false,
           Widths=false, HeadersOnly=false, empty="", null="", prLen=false,
           maxCol=0, alignSpecs: seq[string]): int =
  ## This stdin-out filter aligns an ASCII table & optionally emits header rows
  ## with widths/colNos.  Zero or more alignSpecs control output alignment:
  ##   - left aligned (default)
  ##   + right aligned
  ##   0 centered
  ## The final alignSpec is used for any higher, unspecified columns.  E.g.:
  ##   ``align -d : - + + + - < /etc/passwd``
  ## left aligns all but 2nd,3rd,4th
  let nEmpty = empty.mpl                #Some minor parameter postprocessing
  let nNull  = null.mpl
  let origin = if origin0: 0 elif origin1: 1 else: -1
  var rows: seq[seq[string]] = @[ ]     #Our main data table
  var w = newSeqOfCap[int](8)           #Running max width of each column
  var blanks: seq[int] = @[ ]           #Record of blank locations
  var N = 0                             #Input line number
  var M = 0                             #Number of columns in table
  let sep = initSep(delim)              #Compile delim string into a splitter
  for line in lines(stdin):             #PASS1: COLLECT WIDTHS AND MAYBE DATA
    inc(N)
    if line.len == 0:                   #Blank line:
      blanks.add(N)                     #  Record its location
      continue                          #  but otherwise nothing to do
    let row = sep.split(line, maxCol)
    if N == 1: usePrLen = prLen or row.findSGR
    if row.len > M:                     #Table width is max of all row lens
      w.setLen(row.len)                 #Expand col width tracker..
      for j in M ..< row.len:           #  ..and init to get the right w[j]
        w[j] = if M == 0: 0 else: nNull #  ..1st time 0, after missing value
      M = row.len
    if not (Widths and rows.len == 0):  #Skip max track only if Widths&&1st row
      for j in 0 ..< row.len:           #Track per column max width
        let jl = row[j].mpl
        w[j] = max(w[j], if jl > 0: jl else: nEmpty)
      for j in row.len ..< M:           #include nNull if missing val ever occur
        w[j] = max(w[j], nNull)
    if rows.len==0 or not HeadersOnly:  #Either 1st Row (Hdrs) or Saving Table
      rows.add(row)
  if rows.len == 0:                     #No real data
    return 2
  var aligns = alignSpecs               #Pad align specs to max columns seen, M
  if aligns.len == 0: aligns.add("-")   #Default empty alignSpecs => @["-"]
  while aligns.len < M:
    aligns.add(aligns[^1])

  var wPr = w                           #PASS2: WIDTHS FOR TEXT TO BE PRINTED
  if HeadersOnly: zeroMem(addr wPr[0], wPr.len * sizeof wPr[0])
  let hdr = rows[0]
  for j in 0 ..< hdr.len: wPr[j] = max(wPr[j], hdr[j].mpl)  #header widths
  for j in hdr.len ..< M: wPr[j] = max(wPr[j], nNull)       #Inp maybe irregular
  if origin >= 0:                                           #index widths
    for j in 0 ..< M: wPr[j] = max(wPr[j], len($(origin + j)))
  if widths:                                                #width widths
    for j in 0 ..< M:                                       #must come LAST
      if Widths: wPr[j] = max(wPr[j], len($w[j]))
      else: #Tricky since this can change very thing being max(,) updated!
            #base10 grows slowly=>Only an issue w/HeadersOnly & width>>hdrWidth.
        let tmp = len($wPr[j])          #start with existing len of string
        if tmp > wPr[j]:                #The width number determines wPr
          wPr[j] = len($tmp)            #but need to use len of *new* width.
  var pad = strutils.repeat(' ', max(wPr)) #wPr now correct; Create pad buffer

  if widths:                            #PASS3a: PRINT FORMATTED METADATA
    for j in 0 ..< M:                   #print column width header
      if j != 0: stdout.write(sepOut)   #Count w/for separator|NULL
      let o = $(if Widths: w[j] else: wPr[j])
      pr(o, o.len, wPr[j], aligns[j], pad)
    stdout.write('\n')
  if origin >= 0:                       #print numeric column headers
    for j in 0 ..< M:
      if j != 0: stdout.write(sepOut)
      let o = $(origin + j)
      pr(o, o.len, wPr[j], aligns[j], pad)
    stdout.write('\n')
  if HeadersOnly:                       #print only header (rows[0])
    let row = rows[0]
    for j in 0 ..< row.len:
      if j != 0: stdout.write(sepOut)
      let jl = row[j].mpl
      if jl > 0:
        pr(row[j], jl, wPr[j], aligns[j], pad)
      else:
        pr(empty, nEmpty, wPr[j], aligns[j], pad)
    for j in row.len ..< M:
      stdout.write(sepOut)
      pr(null, nNull, wPr[j], aligns[j], pad)
    stdout.write('\n')
    return 0
  var blankIx = 0                       #PASS3b: PRINT FORMATTED DATA
  N = 0                                 #This loop basically just reproduces..
  for i in 0 ..< rows.len:              #..the recorded parsing state machine.
    inc(N)                              #bump line number
    while blankIx < blanks.len and blanks[blankIx] == N:
      stdout.write("\n")                #Emit any blank sequence
      inc(blankIx)
      inc(N)
    let row = rows[i]                   #Emit the formatted row
    for j in 0 ..< row.len:
      if j != 0: stdout.write(sepOut)
      let jl = row[j].mpl
      if jl > 0:
        pr(row[j], jl, wPr[j], aligns[j], pad)
      else:
        pr(empty, nEmpty, wPr[j], aligns[j], pad)
    for j in row.len ..< M:
      stdout.write(sepOut)
      pr(null, nNull, wPr[j], aligns[j], pad)
    stdout.write('\n')

dispatch(align, help = {
      "delim"      : "inp delim chars; Any repeats => foldable",
      "sepOut"     : "output separator (beyond just space padding)",
      "HeadersOnly": "only print column headers, widths, labels.",
      "origin0"    : "print a header of 0-origin column labels",
      "origin1"    : "print a header of 1-origin column labels",
      "widths"     : "first output row is column widths in bytes",
      "Widths"     : "printed widths DO NOT reflect header row(s)",
      "empty"      : "output string for empty internal cell/header",
      "null"       : "output string for cell introduced as padding",
      "maxCol"     : "max columns to form for aligning;0=unlimited",
      "prLen"      : "force adjust for ANSI SGR escape sequences" },
    short = { "origin0" : '0', "origin1" : '1' } )
