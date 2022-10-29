import std/algorithm, cligen/[mslice, osUt]
when not declared(stdout): import std/syncio

proc colSort*(fi, fo: File; iDlm="\t", oDlm='\t', skip=0) =
  let sep = initSep(iDlm)
  var cols: seq[MSlice]
  for (cs, nP1) in fi.getDelims:
    sep.split(MSlice(mem: cs, len: nP1 - 1), cols)
    var wrote = false   # flag saying we wrote & so need to delimit
    for i in 0 ..< min(skip, cols.len):
      if wrote: outu oDlm else: wrote = true
      outu cols[i]
    if cols.len > skip:
      var cols = cols[skip..^1]
      cols.sort
      for c in cols:
        if wrote: outu oDlm else: wrote = true
        outu c
    outu '\n'

proc colSort*(pi="", po="", iDlm="\t", oDlm='\t', skip=0) =
  ## Copy input->output lines, sorting columns [skip:] within each row.
  colSort if pi.len == 0: stdin  else: open(pi),
             if po.len == 0: stdout else: open(po, fmWrite), iDlm, oDlm, skip

when isMainModule:
  import cligen
  dispatch (proc(pi,po,iDlm:string; oDlm:char; skip:int))colSort, help={
    "pi"  : "path to input ; \"\" => stdin",
    "po"  : "path to output; \"\" => stdout",
    "iDlm": "input delimiter; w* => repeated whitespace",
    "oDlm": "output delimiter byte",
    "skip": "initial columns to NOT sort within rows"}
