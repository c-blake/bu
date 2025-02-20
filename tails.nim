when not declared(stdout): import std/syncio
import std/[os, terminal, parseutils]; import std/strutils except parseInt

proc bump(j: var int, m: int) = (inc j; if j == m: j = 0) # Ring index helper
template headTail*(R,E: type; get,put,copy,drop,rest; head, tail: int; divide) =
  ## 1-pass, small mem Python-like b<0 [a:b] slices | their logical complements.
  ## Here head<0 drops@start & tail<0 drops@end (swapped from GNU coreutils -n).
  var r: R
  for _ in 1 .. head.abs:           ##### MAYBE EMIT HEAD
    if not r.get: r.drop; return        # Early end of input; Done
    if head > 0: put r.cs, r            # Write lines|skip in emit|skip modes
  if tail == 0:                         # Finish up no-TAIL case
    if head < 0: rest r                 # Copy rest of file
    r.drop; return                      # Done
  let nTail = tail.abs              ##### MAYBE EMIT|BUFFER !TAIL
  var buf = newSeq[E](nTail)            # Cyclic buf for TAIL
  var i, j: int                         # Total (from EOHead) & Cyclic index
  while r.get:                          # Get new record | EOF
    if tail < 0 and i >= nTail:         # If clipping tail & have enough, emit..
      put buf[j], r                     #..about to be clobbered non-tail saved.
    copy buf[j], r                      # Save data & bump; Could become 1 big..
    inc i; j.bump nTail                 #..buffer instead of nTail line bufs.
  if tail > 0:                      ##### MAYBE EMIT TAIL
    if head > 0 and i > tail: r.divide  # Non-contiguity detected! Show caller
    if i <= tail: j = 0                 # Not wrapped => Reset
    for _ in 1 .. min(i, tail):         # For however many after EOHead we got..
      put buf[j], r; j.bump nTail       #..emit & cycle forward.
  r.drop                                # Free input buffer

from cligen/osUt import urite, uriteBuffer, ureadBuffer, c_getdelim
template rest(r) =    # Input buffer to drop on write error
  var buf = newString(65536)
  while true:         # Nixing stdio use can elim work; Also sendfile/splice?
    let n = f.ureadBuffer(buf[0].addr, buf.len)
    if n > 0 and stdout.uriteBuffer(buf[0].addr, n) < n:
      r.drop; return true               # Write Error => true
    if n < buf.len: break

proc rowFilter(f: File; head,tail: int; ird,eor: char; divr="--\n"): bool =
  proc free(pointr: cstring) {.importc, header: "stdlib.h".}
  type Rec = tuple[cs: cstring; len: int; room: uint]
  template get(r): untyped =
    r.len = c_getdelim(r.cs.addr, r.room.addr, cint(ird), f)
    r.len + 1 > 0
  template copy(d, s) = d.setLen s.len; copyMem d[0].addr, s.cs, s.len - 1
  template drop(r) = free(r.cs)
  template put(b, r) =  # Buffer to write, Input buffer to drop on write error
    let n = b.len - 1
    if stdout.uriteBuffer(b[0].addr, n) < n or
       stdout.uriteBuffer(eor.addr, 1) < 1:
      r.drop; return true               # Write error; Return true
  template divide(r) =
    if divr.len > 0 and stdout.uriteBuffer(divr[0].addr, divr.len) < divr.len:
      r.drop; return true               # Write error; Return true
  headTail Rec, string, get, put, copy, drop, rest, head, tail, divide

proc byteFilter(f: File; head,tail: int; divr="--\n"): bool =
  when defined(linux) and not defined(android):
    proc fgetc(f: File): cint {.importc: "fgetc_unlocked".}
    proc putchar(c: cint): cint {.importc: "putchar_unlocked".}
  else:
    proc fgetc(f: File): cint {.importc.}
    proc putchar(c: cint): cint {.importc.}
  type Rec = tuple[cs: char]
  template get(r): untyped = (let i = f.fgetc; r.cs = char(i); i >= 0)
  template copy(d, s) = d = s.cs
  template drop(r) = discard
  template put(b, r) =  # Buffer to write, Input buffer to drop on write error
    if putchar(b.cint) < 0: return true # Write error; Return true
  template divide(r) =  # A bit questionable if both-mode+bytes should divide.
    if divr.len > 0 and stdout.uriteBuffer(divr[0].addr, divr.len) < divr.len:
      r.drop; return true               # Write error; Return true
  headTail Rec, char, get, put, copy, drop, rest, head, tail, divide

type NKind = enum doN=0, plusN, fitN
type NRow = object
  kind: NKind
  n: int

proc toI(a:string):int = (if a.len>0 and parseInt(a, result)<a.len: result = 0)
proc nToFit(height, nH1, nH, nF: int): int =
  let budget = height - 1 - nH1 - (nF - 1)*nH # - shellPrompt 1stHeader OtherHdr
  result = budget div nF
  if result*nF > budget: dec result

proc tails(head=NRow(), tail=NRow(), follow=false, bytes=false, divide="--",
           header="", quiet=false, verbose=false, ird='\n', eor='\n',
           paths: seq[string]): int =
  ## Unify & enhance normal head/tail to emit|cut head|tail|both.  "/[n]" for
  ## `head|tail` infers a num.rows s.t. output for n files fits in
  ## ${LC_LINES:-${LINES:-ttyHeight}} rows. "/" alone infers that n=num.inputs.
  let paths = if paths.len > 0: paths else: @[""]
  let divider = divide & $eor
  var head = head; var tail = tail
  let doHeaders = verbose or (not quiet and paths.len > 1)
  var hdr, hdr1: string; var nH, nH1: int
  if doHeaders:
    hdr = if header.len>0: header else: $eor & "==> $1 <==" & $eor
    hdr1 = hdr.strip(trailing=false, chars={eor})
    nH = header.count(eor); nH1 = hdr1.count(eor)
  let height = if head.kind != fitN and tail.kind != fitN: 0
               elif (let i=toI(getEnv("LC_LINES",getEnv("LINES",""))); i > 0): i
               else: terminalHeight()
  if head.kind == fitN and head.n == 0: head.n = paths.len
  if tail.kind == fitN and tail.n == 0: tail.n = paths.len
  elif tail.kind == plusN: head.n = 1-tail.n; tail.kind = doN; tail.n = 0
  if head.kind==fitN and tail.kind==fitN: # Approximate; Could be enhanced.
    let nSep = divider.count(eor)         # E.g., -h2 -t4 => 2x more hd than tl.
    let n2 = height.nToFit(nH1+nSep, nH+nSep, max(head.n, tail.n))
    head.n = n2 div 2; tail.n = n2 div 2
  elif head.kind == fitN: head.n = height.nToFit(nH1, nH, head.n)
  elif tail.kind == fitN: tail.n = height.nToFit(nH1, nH, tail.n)
  var firstHeader = true
  for path in paths:
    if doHeaders:
      let path = if path.len > 0: path else: "standard input"
      if firstHeader:                   # Strip only leading newlines
        firstHeader = false
        stdout.urite hdr1%path
      else: stdout.urite hdr%path
    let f = if path.len > 0: open(path) else: stdin
    if bytes: (if f.byteFilter(head.n, tail.n, divider): return 1)
    else: (if f.rowFilter(head.n, tail.n, ird, eor, divider): return 1)
    if f != stdin: f.close

when isMainModule:
  import cligen, cligen/[argcvt, cfUt]  # ArgcvtParams&friends, cfToCL,envToCL

  let argc {.importc: "cmdCount".}: cint        # Use ACTUAL OS-passed $0, ..
  let argv {.importc: "cmdLine".}: cstringArray # not the cligen-passed one.
  proc mergeParams(cmdNames:seq[string],cmdLine=commandLineParams()):seq[string]=
    let cn = splitPath($argv[0]).tail   # Like `cligen/mergeCfgEnv` BUT adapt..
    let up = cn.toUpperAscii            #..$0 = head|tail -[nc] to "-ch|-ct".
    var cf = getEnv(up & "_CONFIG")     # Check for $(HEAD|TAIL|TAILS)_CONFIG
    if cf.len == 0:                     # No $X_CONFIG override, go by $0
      cf = getConfigDir()/cn/"config"
      if not cf.fileExists: cf = cf[0..^8]
    if cf.fileExists: result.add cf.cfToCL
    result.add envToCL(up)              # Does not handle combiners like "-fn5"
    result.add cmdLine                  #..but such are super rare usage; POSIX
    if cn == "head":                    #..`head` literally only has -n option. 
      for clp in mitems result:
        if clp == "--": break           # Also translate -z -> -i\0 \e\0
        if   clp.startsWith("-n"): clp = "-h"  & clp[2..^1]
        elif clp.startsWith("-c"): clp = "-ch" & clp[2..^1]
    elif cn == "tail":
      for clp in mitems result:
        if clp == "--": break           # Also translate -z -> -i\0 \e\0  
        if   clp.startsWith("-n"): clp = "-t"  & clp[2..^1]
        elif clp.startsWith("-c"): clp = "-ct" & clp[2..^1]

  proc argParse*(dst: var NRow, dfl: NRow; a: var ArgcvtParams): bool =
    let s = a.val.strip                 # Accept tail -n/3, tail -n+2, head -n5
    if s.len > 0 and s[0] == '/':
      dst.kind = fitN
      if s.len > 1 and parseInt(s, dst.n, start=1) + 1 < s.len:
        a.msg = "Bad value: \"$1\" for \"$2\"; expecting \"/\" | \"/int\"\n$3" %
                [a.val, a.key, a.help]; return false
    elif s.len > 0 and s[0] == '+':
      dst.kind = plusN
      if s.len == 1 or parseInt(s, dst.n) < s.len:
        a.msg = "Bad value: \"$1\" for \"$2\"; expecting \"+INTEGER\"\n$3" %
                [a.val, a.key, a.help]; return false
    elif s.len == 0 or parseInt(s, dst.n) < s.len:
      a.msg = "Bad value: \"$1\" for option \"$2\"; expecting int\n$3" %
              [a.val, a.key, a.help]; return false
    return true

  proc argHelp*(defVal: NRow, a: var ArgcvtParams): seq[string] =
    @[a.argKeys, "int|/[n]", "0"]

  dispatch tails, short={"help": '?', "bytes": 'c', "header": 'H'}, help={
    "paths"  : "[paths: string...; '' => stdin]",
    "head"   : ">0 emit | <0 cut this many @start",
    "tail"   : ">0 emit | <0 cut this many @end;\n" &
               "Leading \"+\" => `head` = 1 - THIS.",
    "bytes"  : "`head` & `tail` units are bytes not rows",
    "follow" : "CLIGEN-NOHELP", # --follow is To Be Done
    "divide" : "separator, for non-contiguous case",
    "header" : "header format; \"\" => \\n==> $1 <==\\n",
    "quiet"  : "never print file name headers", # --silent alias?
    "verbose": "always print file name headers",
    "ird"    : "input record delimiter",
    "eor"    : "output end of row/record char"}
