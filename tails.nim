from cligen/osUt import getDelims, uriteBuffer, ureadBuffer, c_getdelim
proc free(pointr: cstring) {.importc, header: "<stdlib.h>".}

proc wrec(cs: cstring, n: int, eor: char): bool {.inline.} = # NOTE n-1
  stdout.uriteBuffer(cs, n-1) < n-1 or stdout.uriteBuffer(eor.addr, 1) < 1

proc bumpMod(j: var int; m: int): int {.inline.} = # circ.buffer helper
  j.inc; if j >= m: j = 0
  j

proc outer(f: File, head=0, tail=0, eor='\n', sep="--", repeat=false): int =
  var tBuf = newSeq[cstring](max(1, tail))
  var tLen = newSeq[int](max(1, tail))
  var room = newSeq[csize_t](max(1, tail))
  var i, j: int
  var wrote = false
  while (let n = c_getdelim(tBuf[j].addr, room[j].addr, cint('\n'), f);n)+1 > 0:
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

proc inner(f: File, head=0, tail=0, eor='\n'): int =
  var i = 0
  if tail > 0:                          # Inefficient/high resource use case
    var bBuf: string                    # O(input - (head+tail)) body buffer
    var rows = newSeq[int](head + tail) # offset can be a circ.buf, though.
    var j = 0
    for (cs, n) in f.getDelims:
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

template doTails(f) =
  if compl: (if f.inner(head, tail, eor) != 0: return 1)
  else    : (if f.outer(head, tail, eor, sep, repeat) != 0: return 1)

proc tails(head=0, tail=0, sep="--", compl=false, repeat=false, eor='\n',
           quiet=false, verbose=false, paths: seq[string]): int =
  ## Generalized tail(1); Can do both head & tail of streams w/o tee FIFO.
  let doPrint = verbose or (not quiet and paths.len > 1)
  if paths.len > 0:
    for path in paths:
      if doPrint: echo "==> ", path, " <=="
      var f = open(path)
      doTails(f)
      f.close
  else:
    if doPrint: echo "==> standard input <=="
    doTails(stdin)

when isMainModule:
  import cligen; dispatch(tails, short={"help": '?'}, help={
    "head"   : "number of rows at the start",
    "tail"   : "number of rows at the end",
    "compl"  : "complement of selected rows (body)",
    "sep"    : "separator, for non-contiguous case",
    "repeat" : "repeat rows when head+tail>=n",
    "quiet"  : "never print headers giving file names",
    "verbose": "always print headers giving file names",
    "eor"    : "end of row/record char"})
