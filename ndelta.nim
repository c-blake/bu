import cligen/[mfile, mslice], cligen
from parseutils import parseFloat
import strutils except parseFloat
when not declared(stderr): import std/syncio

type DKind = enum absolute, ratio, relative, perCent

proc load(path: string): MSlice =
  if (let m = mopen(path); m != nil): m.toMSlice
  else: path.readFile.toMSlice(keep=true)

proc delta(num0, num1: float, kind: DKind, n: int): string =
  template ffDec(x: float): untyped = formatFloat(x, ffDecimal, n)
  case kind:
    of absolute: ffDec(num1 - num0)
    of ratio   : (if num0 != 0.0: ffDec(num1/num0) else: "INF")
    of relative: (if num0 != 0.0: ffDec(num1/num0 - 1) else: "INF")
    of perCent : (if num0 != 0.0: ffDec(100.0*num1/num0 - 1) else: "INF")

proc ndelta(paths: seq[string], kind=ratio, delims="white", n=3, sloppy=false) =
  ## Replace numbers in token-compatible spots of `paths[0]` & `paths[1]` with
  ## (absolute | ratio | relative | perCent) deltas.  To trap out-of-order data,
  ## differences in context are highlighted unless `sloppy` is true.
  if paths.len != 2: raise newException(HelpError, "Need 2 paths; Full ${HELP}")
  let sep = initSep(delims)
  let tok0 = paths[0].load.frame(sep)   # Fully split both files into 2..
  let tok1 = paths[1].load.frame(sep)   #.. seq[TextFrame]s of tokens.
  if tok0.len != tok1.len:              # Check compatibility
    stderr.write "WARNING: files have different token structure\n"
  for i in 0 ..< tok0.len:              # Now loop: identify & compare floats
    if tok0[i].ms.len == 0: continue    # Empty data frame (if not repeat)
    if tok0[i].isSep:
      stdout.write tok0[i].ms
    else:                               # Both tokens are non-separator text
      var num0, num1: float
      let s0 = $tok0[i].ms              # An interesting but tricky extension..
      let s1 = $tok1[i].ms              #.. would be optional parse of x +- dx
      if s0.parseFloat(num0) == s0.len and s1.parseFloat(num1) == s1.len:
        stdout.write delta(num0, num1, kind, n)
        if kind == perCent: stdout.write '%'
      elif not sloppy and tok0[i].ms != tok1[i].ms: # Differing Context
        stdout.write "\e[1m", tok0[i].ms, "\e[22m<>\e[3m", tok1[i].ms, "\e[23m"
      else:                             # Same context/labels/etc.
        stdout.write tok0[i].ms

dispatch ndelta,help={"kind"  : "DiffKind: absolute, ratio, relative, perCent",
                      "delims": "repeatable delim chars",
                      "n"     : "FP digits to keep",
                      "sloppy": "allow non-numerical context to vary silently"}
