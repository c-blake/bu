when not declared(stdout): import std/syncio
from std/strutils import `%`, strip, count; from parseutils import parseInt
import std/[os, terminal]; include cligen/unsafeAddr
from cligen/osUt import getDelims, urite, uriteBuffer, ureadBuffer, c_getdelim
proc free(pointr: cstring) {.importc, header: "<stdlib.h>".}

proc wrec(cs: cstring, n: int, eor: char): bool {.inline.} = # NOTE n-1
  stdout.uriteBuffer(cs, n-1) < n-1 or stdout.uriteBuffer(eor.unsafeAddr, 1) < 1

proc bumpMod(j: var int; m: int): int {.inline.} = # circ.buffer helper
  j.inc; if j >= m: j = 0
  j

proc outer(f: File; head,tail: int; ird,eor: char; sep="--",repeat=false): int =
  var tBuf = newSeq[cstring](max(1, tail))
  var tLen = newSeq[int](max(1, tail))
  var room = newSeq[csize_t](max(1, tail))
  var i, j: int
  var wrote = false
  while (let n = c_getdelim(tBuf[j].addr, room[j].addr, cint(ird), f);n)+1 > 0:
    tLen[j] = n
    if i < head:
      if wrec(tBuf[j], tLen[j].int, eor): return 1 #Q: chk for disk full/ENOSPC?
      wrote = true
    elif i==head and tail <= 0: return  # no tail; done
    discard j.bumpMod(tail)
    i.inc
  if i <= head and tail <= 0: return    # no tail; done
  let j0 = j
  if not repeat and head + tail > i:    # head & tail degenerate into `cat`
    for it in 0 ..< head + tail - i:
      discard j.bumpMod(tail)
  while true:
    if sep.len > 0 and wrote: stdout.write sep, eor; wrote = false
    if tLen[j] > 0: (if wrec(tBuf[j], tLen[j].int, eor): return 1)
    if tBuf[j] != nil: free(tBuf[j])
    if j.bumpMod(tail) == j0:
      break

proc inner(f: File; head,tail: int; ird,eor: char): int =
  var i = 0
  if tail > 0:                          # Inefficient/high resource use case
    var bBuf: string                    # O(input - (head+tail)) body buffer
    var rows = newSeq[int](head + tail) # offset can be a circ.buf, though.
    var j = 0
    for (cs, n) in f.getDelims(ird):
      if i >= head:
        rows[j.bumpMod tail] = bBuf.len
        bBuf.setLen bBuf.len + n
        copyMem bBuf[^n].addr, cs, n - 1
        bBuf[^1] = eor
      i.inc
    let n = if head + tail <= i: rows[j.bumpMod tail] else: 0
    if bBuf.len > 0:
      if stdout.uriteBuffer(bBuf[0].addr, n) < n: return 1
  else:                                 # Very efficient/low resource case
    for (cs, n) in f.getDelims:
      if i >= head:
        if wrec(cs, n, eor): return 1   # write head-th line and then IO loop
        var buf = newString(65536)
        while true: # Nixing stdio abstraction elims work;Or sendfile+splice
          let n = f.ureadBuffer(buf[0].addr, buf.len)
          if n > 0:
            if stdout.uriteBuffer(buf[0].addr, n) < n: return 1
          if n < buf.len:
            break
      i.inc

type NKind = enum doN=0, plusN, fitN
type NRow = object
  kind: NKind
  n: int

proc toI(a:string):int = (if a.len>0 and parseInt(a, result)<a.len: result = 0)
proc nToFit(height, nH1, nH, nF: int): int =
  let budget = height - 1 - nH1 - (nF - 1)*nH # - shellPrompt 1stHeader OtherHdr
  result = budget div nF
  if result*nF > budget: dec result

proc tails(head=NRow(), tail=NRow(), follow=false, bytes=false, sep="--",
           body=false, repeat=false, header="", quiet=false, verbose=false,
           ird='\n', eor='\n', paths: seq[string]): int =
  ## Emit|cut head|tail|both.  This combines & generalizes normal head/tail.
  ## "/[n]" for `head|tail` infers a num.rows s.t. output for n files fits in
  ## ${LC_LINES:-${LINES:-ttyHeight}} rows. "/" alone infers that n=num.inputs.
  let paths = if paths.len > 0: paths else: @[""]
  var head = head; var tail = tail
  let doHeaders = verbose or (not quiet and paths.len > 1)
  var hdr, hdr1: string; var nH, nH1: int
  if doHeaders:
    hdr = if header.len>0: header else: $eor & "==> $1 <==" & $eor
    hdr1 = header.strip(trailing=false, chars={eor})
    nH = header.count(eor); nH1 = hdr1.count(eor)
  let height = if head.kind != fitN and tail.kind != fitN: 0
               elif (let i=toI(getEnv("LC_LINES",getEnv("LINES",""))); i > 0): i
               else: terminalHeight()
  if head.kind == fitN and head.n == 0: head.n = paths.len
  if tail.kind == fitN and tail.n == 0: tail.n = paths.len
  if head.kind==fitN and tail.kind==fitN: # Approximate; Could be enhanced.
    let nSep = sep.count(eor) + 1         # E.g., -h2 -t4 => 2x more hd than tl.
    let n2 = height.nToFit(nH1+nSep, nH+nSep, max(head.n, tail.n))
    head.n = n2 div 2; tail.n = n2 div 2
  elif head.kind == fitN: head.n = height.nToFit(nH1, nH, head.n)
  elif tail.kind == fitN: tail.n = height.nToFit(nH1, nH, tail.n)
  var firstHeader = true
  for path in paths:
    if doHeaders:
      let path = if path.len > 0: path else: "standard input"
      if firstHeader:                     # Strip only leading newlines
        firstHeader = false
        stdout.urite hdr1%path
      else: stdout.urite header%path
    var f = if path.len > 0: open(path) else: stdin
    if body: (if f.inner(head.n, tail.n, ird, eor) != 0: return 1)
    else   : (if f.outer(head.n, tail.n, ird, eor, sep, repeat) != 0: return 1)
    if f != stdin: f.close

when isMainModule:
  import cligen, cligen/argcvt; include cligen/mergeCfgEnv

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
    elif parseInt(s, dst.n) < s.len:
      a.msg = "Bad value: \"$1\" for option \"$2\"; expecting int\n$3" %
              [a.val, a.key, a.help]; return false
    return true
  proc argHelp*(defVal: NRow, a: var ArgcvtParams): seq[string] =
    @[a.argKeys, if a.parNm in ["head","tail"]: "int|/[n]" else: "int", "0"]

  dispatch tails, short={"help": '?', "bytes": 'c', "header": 'H'}, help={
    "paths"  : "[paths: string...; '' => stdin]",
    "head"   : "number of rows at the start",   # TODO <0
    "tail"   : "number of rows at the end",     # TODO <0
    "follow" : "CLIGEN-NOHELP", # --follow & --bytes are To Be Done
    "bytes"  : "CLIGEN-NOHELP", # units of `head` & `tail` are bytes
    "sep"    : "separator, for non-contiguous case",
    "body"   : "body not early/late tail",
    "repeat" : "repeat rows when head + tail >= n",
    "header" : "header format; \"\" => \\n==> $1 <==\\n",
    "quiet"  : "never print file name headers", # --silent alias?
    "verbose": "always print file name headers",
    "ird"    : "input record delimiter",
    "eor"    : "output end of row/record char"}
