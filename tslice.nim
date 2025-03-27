when isMainModule:
  import std/[os, syncio, strutils], cligen/[osUt, textUt]
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
