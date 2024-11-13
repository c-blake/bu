when not declared stdin: import std/syncio
import std/[algorithm, sugar], cligen/[textUt, tab], cligen

proc flow*(input="", output="", pfx="", width=0, gap=1, byLen=false, maxPad=99)=
  ## Read maybe utf8-colored lines from `input` & flow them into shortest height
  ## table of top-to-bottom, left-to-right columns & write to `output`.
  let i = if input.len  > 0: open(input) else: stdin
  var strs = collect(for line in i.lines: line)
  if byLen: strs.sort cmp=proc(a, b: string): int = a.printedLen - b.printedLen
  let wids = collect(for str in strs: -str.printedLen) # - here means left-align
  let o = if output.len > 0: open(output, fmWrite) else: stdout
  if gap < 0: (for x in strs: o.write x)
  else:
    let W = if width == 0: ttyWidth elif width < 0: ttyWidth + width else: width
    let w = W - pfx.len
    var nrow, ncol: int; let m = 1
    var colWs = layout(wids, w, gap, maxPad, m, nrow, ncol)
    colPad(colWs, w, maxPad, m)
    o.write(strs, wids, colWs, m, nrow, ncol, 0, pfx)

dispatch flow, help={"input" : "use this input file; \"\"=>stdin",
                     "output": "use this output file; \"\"=>stdout",
                     "pfx"   : "pre-line prefix (e.g. indent)",
                     "width" : "rendered width; 0: auto; <0: auto+THAT",
                     "gap"   : "max inter-column gap; <0: 1-column",
                     "byLen" : "sort by printed-length of row",
                     "maxPad": "max per-column padding"}
