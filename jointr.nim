import std/[tables, strutils], cligen/[mfile, mslice, osUt], cligen

proc jointr*(cont=" <unfinished ...>", boc="<... ", eoc=" resumed>", all=false,
             path: seq[string]) =
  ## Multi-process programs are often usefully debugged via something like
  ##   `strace --decode-fds -fvs8192 -oFoo multi-process-program`
  ## but this breaks up a system call execution suspension into top & bottom
  ## halves with "..." indicators like:
  ##   PID (.\*)" <unfinished ...>\\\n .. samePID <... CALL resumed>
  ## where top-half parameters are elided in bottom half resumption.  This
  ## program joins these lines for easier reading, optionally retaining the
  ## "unfinished" to aid temporal reasoning.  In said retention mode,
  ## never-resumed calls print in hash order at the end.
  var top: Table[MSlice, MSlice]
  let sep = initSep "white"
  var cols: seq[MSlice]
  for line in mSlices(if path.len<1: "/dev/stdin" else: path[0], keep=true):
    sep.split line, cols, 2
    if cols.len != 2: continue
    let (pid, rest) = (cols[0], cols[1])
    if rest.startsWith boc:             # Skip to 1st eoc & output top,bottom
      let ix = line.find eoc
      if ix == -1:
        raise newException(IOError, "missing \"" & eoc & "\"")
      outu alignLeft($pid, 5), " ", top[pid], line[ix+eoc.len..^1], "\n"
      top.del pid
    elif rest.endsWith cont:            # Save for bottom half
      top[pid] = rest[0 ..^ (cont.len + 1)]
      if all: outu line, '\n'
    else: outu line, '\n'
  if not all:
    for pid, rest in top:               # Would be nicer to emit in orig order,
      outu alignLeft($pid, 5), rest     #..but that needs more subtle buffering
      outu cont, '\n'                   #..& never-resumed calls must be rare.

dispatch jointr, help={"path": "strace log path (or none for stdin)",
  "cont": "line suffix saying it continues",
  "boc" : "beg of contin. indication to eat",
  "eoc" : "end of contin. indication to eat",
  "all" : "retain \"unfinished ...\" in-place"}
