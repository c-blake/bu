when not declared(stderr): import std/syncio
import std/[os, times, sets, sugar], cligen, cligen/[strUt, mslice, mfile, osUt]
when defined linux: import cligen/statx

var TBAD: Time                          # The zero time is our sentinel
proc get(times: var seq[Time], paths: seq[MSlice], keep=false) =
  times.setLen paths.len
  when defined linux:
    when defined(batch) and not defined(android):          #-d:batch => @c-blake
      const BAT = getEnv("BAT") & "/include/linux/batch.h" #.. batch in $BAT
      type SysCall {.importc: "syscall_t", header: BAT.} =
        object
          nr, jumpFail,jump0,jumpPos: cshort  # callNo,jmpFor:-4096<r<0,r==0,r>0
          argc: cchar                         # arg count. XXX argc[nr]
          arg: array[6, clong]                # args for this call
      proc batch(rets: ptr clong, calls: ptr SysCall, ncall: culong, flags:
                 clong, size: clong): clong {.importc, nodecl.}
      let SYS_statx = 332 # {.importc: "__NR_statx", nodecl.}: cint #CodeGenBUG
      let nB = paths.len.culong
      var ba = newSeq[SysCall](nB)
      var sx = newSeq[Statx](nB)
      var rv = newSeq[clong](nB)
      for i in 0 ..< nB.int:
        ba[i].nr     = cshort(SYS_statx)
        ba[i].argc   = cchar(5)
        ba[i].arg[0] = AT_FDCWD
        ba[i].arg[1] = cast[clong](paths[i].mem)
        ba[i].arg[2] = AT_NO_AUTOMOUNT or AT_STATX_DONT_SYNC #_SYMLINK_NOFOLLOW
        ba[i].arg[3] = STATX_MTIME      # We only want MTIME
        ba[i].arg[4] = cast[clong](sx[i].addr)
      for i in 0 .. batch(rv[0].addr, ba[0].addr, nB, 0.clong, 0.clong):
        if rv[i] == 0:
          times[i] = initTime(sx[i].stx_mtime.tv_sec, sx[i].stx_mtime.tv_nsec)
        elif i mod 2 == 0 and not keep: return
    else:
      var stx: Statx
      for i, p in paths:                # Nim alloc0 => No need to set TBAD
        if statx(cast[cstring](p.mem), stx, AT_STATX_DONT_SYNC, STATX_MTIME)==0:
          times[i] = initTime(stx.stx_mtime.tv_sec, stx.stx_mtime.tv_nsec)
        elif i mod 2 == 0 and not keep: return
  else:
    for i, p in paths:
      times[i] = try: getLastModificationTime($p) except Ce: TBAD
      if times[i] == TBAD and i mod 2 == 0 and not keep: return

proc add0(buf: var seq[char], ms: MSlice): MSlice = # Add w/0 but return ptr2cpy
  result.mem = cast[pointer](buf.len)         # ptr ~ global 0 offset memory
  result.len = ms.len                         #NOTE: does not cover NUL term
  var n = buf.len                             # Allocate more space
  buf.setLen n + ms.len + 1                   #NOTE: This CAN relocate buf
  copyMem buf[n].addr, ms.mem, ms.len         # Copy-in data
  buf[n + ms.len] = '\0'                      # NUL terminate for OS

proc relTo(ms: MSlice, base: pointer): MSlice = # Make input ms relative to base
  result.mem = cast[pointer](cast[uint](ms.mem) + cast[uint](base))
  result.len = ms.len

var hunks: seq[MSlice]
proc sQuote(f: File, a: MSlice) =       #Q: Condition upon need to quote at all?
  putchar '\''                          # If a starts or ends with ' this could
  discard a.msplit(hunks, '\'', 0)      #..save an empty string ('') catenation
  for i, hunk in hunks:                 #..w/a little more logic, but probably
    f.urite hunk                        #..testing if quoting is needed at all
    if i != 0: f.urite "'\\''"          #..has priority.
  putchar '\''

proc cInterPrint(why, cmd0: string, prs: seq[MacroCall]; iPath, oPath: MSlice) =
  for (id, arg, call) in prs:
    if id == 0..0: stdout.urite cmd0, arg
    else:       # Only test 1st char on purpose so user can say %in or %output.
      case cmd0[id.a]
      of 'i': stdout.sQuote iPath
      of 'o': stdout.sQuote oPath
      else: stdout.urite cmd0, call
  stdout.urite why
  stdout.urite "\n"

var emptySeq: seq[string]
proc mk1(file="/dev/stdin", nl='\n', meta='%', explain=false, keep=false,
         alwaysMake=false, question=false, oldFile=emptySeq, whatIf=emptySeq,
         batch=32, cmd: seq[string]): int =
  ## A fast build tool for a special but common case when, for many pairs, just
  ## 1 inp makes just 1 out by just 1 rule.  `file` has back-to-back even-odd
  ## pathnames.  If ages indicate updating, `mk1` prints `cmd` with `%[io]`
  ## interpolated (with POSIX sh single quotes).  To run, pipe to `/bin/sh`,
  ## `xargs -n1 -P$(nproc)`.. E.g.:
  ##   ``touch a.x b.x; printf 'a.x\\na.y\\nb.x\\nb.y\\n' | mk1 'touch %o'``
  ##
  ## Ideally, save `file` somewhere & update that only if needed based on other
  ## context, such as dir mtimes.  Options are gmake-compatible (where sensible
  ## in this much more limited role).
  if cmd.len != 1: raise newException(HelpError, "Need `cmd`; Full ${HELP}")
  let oldFile = collect(for path in oldFile: {path.toMSlice})
  let whatIf = collect(for path in whatIf: {path.toMSlice})
  let cmdP = cmd[0].tmplParsed(meta)    # Pre-parsed command template
  var buf: seq[char]                    # seq[] to advertise many embedded NUL
  var paths: seq[MSlice]                # pointers to path data in `buf`
  var times: seq[Time]                  # Current batch of times
  var nDo = 0                           # Job counter

  template doBatch =                    # How to process a batch of pairs
    for path in mitems(paths):          # Adjust ptrs now that `buf` cannot move
      path = path.relTo(buf[0].addr)
    times.get paths, keep               # Collect mtimes - somehow
    for i in countup(0, paths.len - 1, 2):
      let o = i + 1                     # [io] = index for input|output
      if times[i] == TBAD:              # No input: Done either w/loop|program
        stderr.urite "mk1: cannot age: ", paths[i], "\n"
        if keep: inc result; continue
        else: quit 1
      let absent = times[o] == TBAD     # Output absent indicator
      if absent or (times[i] > times[o] and not
                    (oldFile.len > 0 and paths[o] in oldFile)):
        inc nDo                         # Register that there is work to do
        if not question:                # If above is not all that's wanted: Prn
          let why = if explain: (if absent: " #absent" else: " #stale") else: ""
          cInterPrint why, cmd[0], cmdP, paths[i], paths[o]

  var iPath: MSlice; var n = 0          # Last loop iPath; Loop parity counter
  for ms in mSlices(file, sep=nl, eat='\0'):
    inc n                               # Do right away since continue can occur
    if n mod 2 == 1: iPath = buf.add0(ms)
    else:                               # Even count => `ms` == oPath
      if alwaysMake or (whatIf.len > 0 and iPath.relTo(buf[0].addr) in whatIf):
        inc nDo                         # Register that there is work to do
        if not question:                # If above is not all that's wanted: Prn
          let why = if explain: " #forced" else: ""  # always|whatIf => forced
          cInterPrint why, cmd[0], cmdP, iPath.relTo(buf[0].addr), ms
        buf.setLen buf.len - (iPath.len + 1)  # Pair is handled; Release copy
        continue
      paths.add iPath                   # Accumulate pair into paths[]
      paths.add buf.add0(ms)
      if paths.len >= 2*batch:          # If we have enough do the batch
        doBatch; buf.setLen 0; paths.setLen 0; times.setLen 0
  if paths.len > 0:                     # Do rest (when number mod 2*batch != 0)
    doBatch
  if question: result = int(nDo > 0)    # Any work => 1 => shell-false
  elif nDo == 0: stderr.write "mk1: no work to do\n"

when isMainModule:
  dispatch mk1, short={"alwaysMake": 'B', "whatIf": 'W', "explain": 'x'},
    help={"cmd"        : "command using %i%o",
          "file"       : "input file of name stubs",
          "nl"         : "input string terminator",
          "meta"       : "self-quoting meta for %sub",
          "explain"    : "add #(absent|stale|forced) @EOL",
          "keep"       : "keep going if cannot age %i",
          "always-make": "always emit build commands",
          "question"   : "question if work is empty",
          "old-file"   : "keep %o if exists & is stale",
          "what-if"    : "pretend these %i are fresh",
          "batch"      : "CLIGEN-NOHELP"} # Doubled to enforce pair constraint
