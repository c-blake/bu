when not declared(addfloat): import std/[syncio, formatfloat]
import std/[os, times, strformat, math, tables, strutils, deques],
       cligen, cligen/strUt, bu/emin
proc timePrefix(s: string): string =   # A very "big tent" setup supporting..
  if   s.endsWith("seconds"): s[0..^8] #..short&long, singular&plural, sec, s.
  elif s.endsWith("secs"): s[0..^5]
  elif s.endsWith("sec"): s[0..^4] elif s.endsWith("s"): s[0..^2] else: s
let timeScales={"n":1e9, "nano":1e9, "micro":1e6, "u":1e6, "μ":1e6, "m":1e3,
                "milli":1e3, "":1.0, "min":1.0/60.0, "minute":1.0/60.0}.toTable
var dtScale = 1.0

proc sample1(f: File; cmd, prepare, cleanup: string): float =
  template runOrQuit(c, x) = (if execShellCmd(c)!=0: quit "\""&c&"\" failed", x)
  if prepare.len > 0: prepare.runOrQuit 2                          # Maybe prep
  let t0 = epochTime(); cmd.runOrQuit 3; let dt = epochTime() - t0 # Time
  if cleanup.len > 0: cleanup.runOrQuit 4                          # Maybe Clean
  if not f.isNil: f.write $dt,'\t',cmd,'\n'                        # Maybe log
  dt*dtScale

proc maybeRead(path: string): Table[string, Deque[float]] = # Parse saved data
  if path.len > 0:                      # Use Deque[] since temporal correlation
    for line in path.lines:             #..may matter a lot in later analyses.
      let cols = line.split('\t', 1)
      result.mgetOrPut(cols[1], Deque[float]()).addLast parseFloat(cols[0])

proc padWithLast(xs: seq[string], n: int): seq[string] =
  result = xs; if xs.len == 0: result.add ""
  for i in xs.len ..< n: result.add result[^1]

proc tim(warmup=1, k=2, n=7, m=3, ohead=7, save="", read="", cmds: seq[string],
         prepare: seq[string]= @[], cleanup: seq[string] = @[], timeunit="ms",
         verbose=false) =
  ## Time shell cmds. Finds best `k/n` `m` times.  Merge results for a final
  ## time & error estimate.  `doc/tim.md` explains more.
  if n < k:
    raise newException(HelpError, "Need n >= k; Full ${HELP}")
  if cmds.len == 0:
    raise newException(HelpError, "Need cmds; Full ${HELP}")
  try: dtScale = timeScales[timeunit.timePrefix]
  except KeyError: raise newException(HelpError, "Bad time unit; Full ${HELP}")
  let prepare = prepare.padWithLast(cmds.len)
  let cleanup = cleanup.padWithLast(cmds.len)
  if verbose:stderr.write &"tim: warmup  {warmup}\ntim: k       {k}\n",
                          &"tim: n       {n}\ntim: m       {m}\n",
                          &"tim: ohead   {max(n,ohead)}\ntim: save    {save}\n",
                          &"tim: read    {read}\ntim: cmds    {cmds}\n",
                          &"tim: prepare {prepare}\ntim: cleanup {cleanup}\n"
  let f = if save.len > 0: open(save, fmAppend) else: nil
  var r = read.maybeRead
  proc get1(cmd: string, i = -1): float =             # Either use read times..
    if cmd in r:                                      #..or sample new ones, but
      try   : r[cmd].popFirst                         #..don't cross mode perCmd
      except: raise newException(IOError, "`"&cmd&"`: undersampled in `read`")
    else: f.sample1 cmd, if i<0:"" else: prepare[i], if i<0:"" else: cleanup[i]
  var o: MinEst                                       # Auto-Init to 0.0 +- 0.0
  if ohead > 0:                                       # Measure overhead
    for t in 1..warmup: discard "".get1
    o = eMin(k, max(n,ohead), m, get1="".get1)        # Measure&Report overhead
    echo fmtUncertain(o.est, o.err)," ",timeunit,"\t(AlreadySubtracted)Overhead"
  for i, cmd in cmds:                                 # Measure each cmd
    for t in 1..warmup: discard cmd.get1(i)
    var e = eMin(k, n, m, get1=cmd.get1(i))
    if ohead > 0: e.est -= o.est; e.err = sqrt(e.err^2 + o.err^2) # Maybe -= ohd
    echo fmtUncertain(e.est, e.err)," ",timeunit,"\t",cmd         # Report time

when isMainModule: include cligen/mergeCfgEnv; dispatch tim, help={
  "cmds"   : "'cmd1' 'cmd2' ..",
  "warmup" : "number of warm-up runs to discard",
  "k"      : "number of best tail times to use/2",
  "n"      : "number of inner trials; 1/m total",
  "m"      : "number of outer trials",
  "ohead": """number of \"\" overhead runs;  If > 0, value
(measured same way) is taken from each time""",
  "save"   : "also save TIMES<TAB>CMD<NL>s to this file",
  "read"   : "read output of `save` instead of running",
  "prepare": "cmds to run before *corresponding* cmd<i>s",
  "cleanup": "cmds to run after *corresponding* cmd<i>s",
  "time-unit": """(n|nano|micro|μ|u|m|milli)(s|sec|second)[s]
OR min[s] minute[s] { [s]=an optional 's' }""",
  "verbose": "log parameters & some activity to stderr"}, short={"timeunit":'u'}
