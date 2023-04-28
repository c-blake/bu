when not declared(stderr): import std/syncio
import std/[os, times, sets, sugar], cligen, cligen/[strUt, mslice, mfile, osUt]

func ioInterp(path: var string, fmt: string, prs: seq[MacroCall], ms: MSlice) =
  path.setLen 0                         # Both this & next macro expander
  for (id, arg, call) in prs:           # accept anything *starting with*
    if id == 0..0: path.add fmt[arg]    # '[sio]', e.g. %stub %in %out.
    elif fmt[id.a] == 's': path.add ms
    else: path.add fmt[call]

proc sQuote(f: File, a: string) =       # Works for POSIX shell, not Windows
  f.urite '\''                          #Q: Condition upon need to quote at all?
  for c in a:
    if c == '\'': f.urite "'\\''" else: f.urite c
  f.urite '\''

proc cInterPrint(c, iPath, oPath: string, prs: seq[MacroCall], ms: MSlice) =
  for (id, arg, call) in prs:
    if id == 0..0: stdout.urite c[arg]  # urite(c, arg) to avoid alloc?
    else:
      case c[id.a]
      of 's': stdout.urite ms
      of 'i': stdout.sQuote iPath
      of 'o': stdout.sQuote oPath
      else: stdout.urite c[call]        # urite(c, call) to avoid alloc?

var emptySeq: seq[string]
proc mk1(file="/dev/stdin", nl='\n', meta='%', explain=false, keep=false,
         alwaysMake=false, question=false, oldFile=emptySeq, whatIf=emptySeq,
         ioc: seq[string]): int =
  ## A fast build tool for a special but common case when, for many pairs, just
  ## 1 inp makes just 1 out by just 1 rule.  `file` has only "stubs", `%s` which
  ## are interpolated into `[io]p` - the [io]paths used to test need and `%[io]`
  ## are then interpolated into `cmd` (with POSIX sh single quotes).  This only
  ## prints commands.  Pipe to `/bin/sh`, `xargs -n1 -P$(nproc)`.. to run. Egs.:
  ##   ``touch a.x b.x; printf 'a\\nb\\n' | mk1 %s.x %s.y 'touch %o'``
  ##   ``find -name '\*.c' | sed 's/.c$//' | mk1 %s.c %s.o 'cc -c %i -o %o'``
  ## Best yet, save `file` somewhere & update only if needed based on other
  ## context, such as dir mtimes.  Options are gmake-compatible (where sensible
  ## in this much more limited role).
  if ioc.len != 3:
    raise newException(HelpError, "Need `ip` `op` `cmd`; Full ${HELP}")
  let oldFile = collect(for path in oldFile: {path})
  let whatIf = collect(for path in whatIf: {path})
  let (i ,o ,c)  = (ioc[0], ioc[1], ioc[2])
  let (iP,oP,cP) = (i.tmplParsed(meta), o.tmplParsed(meta), c.tmplParsed(meta))
  var iPath, oPath: string
  var iTm, oTm: Time
  var nDo = 0
  for ms in mSlices(file, sep=nl, eat='\0'):
    iPath.ioInterp i, iP, ms
    if alwaysMake or (whatIf.len>0 and iPath in whatIf):
      oPath.ioInterp o, oP, ms
      inc nDo
      if not question:
        cInterPrint c, iPath, oPath, cP, ms; stdout.urite "\n"
      continue
    try:
      iTm = iPath.getLastModificationTime
    except CatchableError:
      stderr.write "mk1: cannot age: ", iPath, "\n"
      if keep:
        inc result
        continue
      else: quit 1
    oPath.ioInterp o, oP, ms
    let absent = try: oTm = oPath.getLastModificationTime; false except Ce: true
    if absent or (iTm > oTm and not (oldFile.len>0 and oPath in oldFile)):
      inc nDo
      if not question:
        cInterPrint c, iPath, oPath, cP, ms
        if explain:
          stdout.urite if absent: " #absent" else: " #stale"
        stdout.urite "\n"
  if question: result = int(nDo > 0) # Any work => 1 => shell-false
  elif nDo == 0: stderr.write "mk1: no work to do\n"

when isMainModule:
  dispatch mk1, short={"alwaysMake": 'B', "whatIf": 'W', "explain": 'x'},
    help={"ioc": "ip op cmd",
          "file"       : "input file of name stubs",
          "nl"         : "input string terminator",
          "meta"       : "self-quoting meta for %sub",
          "explain"    : "add #(absent|stale) at EOL",
          "keep"       : "keep going if cannot age %i",
          "always-make": "always emit build commands",
          "question"   : "question if work is empty",
          "old-file"   : "keep %o if exists & is stale",
          "what-if"    : "pretend these %i are fresh"}
