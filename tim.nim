when not declared(addfloat): import std/[syncio, formatfloat]
import std/[os, times, strformat, math, tables, strutils, deques],
       cligen, cligen/[sysUt, strUt], bu/emin
proc timePrefix(s: string): string =   # A very "big tent" setup supporting..
  if   s.endsWith("seconds"): s[0..^8] #..short&long, singular&plural, sec, s.
  elif s.endsWith("secs"): s[0..^5]
  elif s.endsWith("sec"): s[0..^4] elif s.endsWith("s"): s[0..^2] else: s
let timeScales={"n":1e9, "nano":1e9, "micro":1e6, "u":1e6, "μ":1e6, "m":1e3,
                "milli":1e3, "":1.0, "min":1.0/60.0, "minute":1.0/60.0}.toTable

var seqNo = 0
template runOrQuit(c, x) =
  inc seqNo; putEnv "TIM_SEQ", $seqNo # Exported sequence number
  if execShellCmd(c)!=0: quit "\""&c&"\" failed", x

proc sample1(f: File; cmd, prepare, cleanup: string): float =
  if prepare.len > 0: prepare.runOrQuit 2                          # Maybe prep
  let t0 = epochTime(); cmd.runOrQuit 3; let dt = epochTime() - t0 # Time
  if cleanup.len > 0: cleanup.runOrQuit 4                          # Maybe Clean
  if not f.isNil: f.write $dt,'\t',cmd,'\n'                        # Maybe log
  dt

proc maybeRead(path: string): Table[string, Deque[float]] = # Parse saved data
  if path.len > 0:                      # Use Deque[] since temporal correlation
    for line in path.lines:             #..may matter a lot in later analyses.
      let cols = line.split('\t', 1)
      result.mgetOrPut(cols[1], Deque[float]()).addLast parseFloat(cols[0])

proc padWithLast(xs: seq[string], n: int): seq[string] =
  result = xs; if xs.len == 0: result.add ""
  for i in xs.len ..< n: result.add result[^1]

proc writeFile(ix: int; me: MinEst; paths: var seq[string]) =
  let nm = "dt" & $ix; paths.add $nm
  let f = open(nm, fmWrite)
  f.write &"# {me.est} +- {me.err}\n"
  for t, dt in me.all: f.write $dt, '\n'
  f.close

proc tim(warmup=1, n=6, k=1, m=4, oHead=6, save="", read="", cmds: seq[string],
         prepare: seq[string]= @[], cleanup: seq[string] = @[], timeUnit="ms",
         graph="", verbose=false) =
  ## Time shell cmds. Finds best `k/n` `m` times.  Merge results for a final
  ## time & error estimate, maybe running plots.  `doc/tim.md` explains more.
  let n = max(n, 2*k + 1)       # Adapt `n` rather than raise on too big `k`
  if cmds.len == 0: Help !! "Need cmds; Full $HELP"
  let dtScale = (try: timeScales[timeUnit.timePrefix] except KeyError:
                   Help !! &"Bad time unit '{timeUnit}'; Full $HELP")
  let prepare = prepare.padWithLast(cmds.len)
  let cleanup = cleanup.padWithLast(cmds.len)
  if verbose:stderr.write &"tim: warmup  {warmup}\ntim: k       {k}\n",
                          &"tim: n       {n}\ntim: m       {m}\n",
                          &"tim: oHead   {max(n,oHead)}\ntim: save    {save}\n",
                          &"tim: read    {read}\ntim: cmds    {cmds}\n",
                          &"tim: prepare {prepare}\ntim: cleanup {cleanup}\n"
  let f = if save.len > 0: open(save, fmAppend) else: nil
  var r = read.maybeRead
  proc get1(cmd: string, i = -1): float =             # Either use read times..
    result = if cmd in r:                             #..or sample new ones, but
        try   : r[cmd].popFirst                       #..don't cross mode perCmd
        except: IO !! "`"&cmd&"`: undersampled in `read`"
      else: f.sample1 cmd, if i<0:"" else:prepare[i], if i<0:"" else:cleanup[i]
    result *= dtScale
  var e = newSeq[MinEst](cmds.len + 1)                # Auto-Inits to 0.0+-0.0
  var paths: seq[string]        # Optional deep dives run cmds taking solo paths
  if oHead.abs > 0:                                   # Measure overhead
    for t in 1..warmup: discard "".get1(0)
    e[0] = eMin(max(n,oHead.abs), k, m, get1="".get1(0)) # Measure&Report oHead
    echo fmtUncertain(e[0].est, e[0].err)," ",timeUnit,
           if oHead > 0: "\t(AlreadySubtracted)Overhead" else: "\tRawOverhead"
    if graph.len > 0: writeFile 0, e[0], paths
  for i, cmd in cmds:                                 # Measure each cmd
    let j = i + 1
    for t in 1..warmup: discard cmd.get1(j)
    e[j] = eMin(n, k, m, get1=cmd.get1(j))            # Below maybe -= oHd
    if oHead > 0: e[j].est -= e[0].est; e[j].err = sqrt(e[j].err^2 + e[0].err^2)
    echo fmtUncertain(e[j].est, e[j].err)," ",timeUnit,"\t",cmd # Report AsWeGo
    if graph.len > 0: writeFile j, e[j], paths
  if graph.len > 0: runOrQuit graph % paths, 5

when isMainModule: include cligen/mergeCfgEnv; dispatch tim, help={
  "cmds"   : "'cmd1' 'cmd2' ..",
  "warmup" : "number of warm-up runs to discard",
  "n"      : "number of inner trials; `>=2k`; `1/m` total",
  "k"      : "number of best tail times to use/2",
  "m"      : "number of outer trials",
  "oHead": """number of \"\" overhead runs;  If >0, value
(measured same way) is taken from each time""",
  "save"   : "also save TIMES<TAB>CMD<NL>s to this file",
  "read"   : "read output of `save` instead of running",
  "prepare": "cmd run before each *corresponding* cmd<i>",
  "cleanup": "cmd run after each *corresponding* cmd<i>",
"timeUnit":"""(n|nano|micro|μ|u|m|milli)(s|sec|second)[s]
OR min[s] minute[s] { [s]=an optional 's' }""",
  "graph" :"""a command to plot durations/distributions;
$1 $2 .. become dt0, dt1 parallel to cmds""",
  "verbose": "log parameters & some activity to stderr"}, short={"timeUnit":'u'}
