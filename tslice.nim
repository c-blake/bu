iterator printedChars*(s:openArray[char],skip=0,lim=int.high): (Slice[int],int)=
  ## 1-pass iterate over SGR-embellished utf8 `s` yielding slices rendering to
  ## 0|1|2 terminal char cells & number of cells rendered.  Includes trailing
  ## SGR codes & allows skipping `skip` cells & limiting to <= `lim` cells.
  let lim = if lim >= 0: skip + lim else: int.high
  var pastLim = false
  var i, wDid: int
  while i < s.len:
    let i0 = i; var isSGR = false; var w = 1
    if s[i] == '\e':                    # ANSI SGR seqs match \e[[0-9;]*m
      if i+1 < s.len and s[i+1] == '[':
        i += 2
        while i < s.len and (s[i] in {'0'..'9', ';', 'm'}):
          if s[i] == 'm': isSGR = true; break
          i += 1
        i += 1                          # Include 'm'
    elif (let c = s[i].uint; c > 127):  # UTF8 multi-byte input
      let x = if   c shr 5 == 0b110:     1 elif c shr 4 == 0b1110:   2
              elif c shr 3 == 0b11110:   3 elif c shr 2 == 0b111110: 4
              elif c shr 1 == 0b1111110: 5 else: 0
      if x == 0 or i + x >= s.len: raise newException(IOError, "Bad UTF8")
      i += x
#     w = 2;    # 2-cell output chars, eg. CJK; Doing this right needs something
    else:       #..like Python's unicodedata (or Nim's unicodedb.nimble).
      i += 1                    # US-ASCII; Do not worry about unprintable < 32
    if not isSGR and wDid + w > lim:
      pastLim = true
    if wDid >= skip and (not pastLim or isSGR):
      yield (i0..<i, if isSGR: 0 else: w)
    if not isSGR and not pastLim:
      wDid += w

when isMainModule:
  import std/[os, syncio, strutils], cligen/osUt
  let ac = paramCount() 
  let av1   = if ac >= 1: paramStr(1)   else: ""
  var colon = if ac >= 1: av1.find(':') else: -1
  if ac < 1 or colon == -1:
    quit "Usage:\n  "&paramStr(0)&" [a]:[b]\n" &
         "does UTF8-SGR aware Py-like slices of terminal columns on stdin", 1
  let A = av1[0 ..< colon]
  let B = av1[colon+1..^1]
  let a = if A.len > 0: A.parseInt else: 0
  let b = if B.len > 0: B.parseInt else: int.high
  let nl = "\n"
  if a < 0 or b < 0:
    for line in stdin.lines:
      var tot = 0
      for (_, w) in printedChars(line): inc tot, w
      let a = if a < 0: tot + a else: a
      let b = if b < 0: tot + b else: b
      let n = b - a
      for (s, _) in printedChars(line, a, n): stdout.urite line, s
      discard stdout.uriteBuffer(nl[0].addr, 1)
  else:
    let n = b - a
    for line in stdin.lines:
      for (s, _) in printedChars(line, a, n): stdout.urite line, s
      discard stdout.uriteBuffer(nl[0].addr, 1)
