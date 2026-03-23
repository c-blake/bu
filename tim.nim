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

proc writeFile(name: string; me: MinEst) =
  let f = open(name, fmWrite)
  f.write &"# {me.est} +- {me.err}\n"
  for t, dt in me.all: f.write $dt, '\n'
  f.close

type Rpt = enum diffs, ratios
proc tim(warmup=1, n=6, k=1, m=4, oHead=6, save="", read="", cmds: seq[string],
         prepare: seq[string]= @[], cleanup: seq[string] = @[], timeUnit="ms",
         delim=':', OHead="", Delim="",Report={diffs}, graph="", verbose=false)=
  ## Time shell commands printing min time estimate += est.error-hardTAB-label.
  ## Merge results for a final time & error estimate, maybe running plots.
  ## `https://github.com/c-blake/bu/blob/main/doc/tim.md` explains more.
  let n = max(n, 2*k + 1)       # Adapt `n` rather than raise on too big `k`
  if cmds.len == 0: Help !! "Need cmds; Full $HELP"
  let dtScale = (try: timeScales[timeUnit.timePrefix] except KeyError:
                   Help !! &"Bad time unit '{timeUnit}'; Full $HELP")
  let prepare = prepare.padWithLast(cmds.len)
  let cleanup = cleanup.padWithLast(cmds.len)
  if verbose:stderr.write &"tim: warmup  {warmup}\ntim: k       {k}\n",
                          &"tim: n       {n}\ntim: m       {m}\n",
                          &"tim: oHead   {oHead}\ntim: save    {save}\n",
                          &"tim: read    {read}\ntim: cmds    {cmds}\n",
                          &"tim: prepare {prepare}\ntim: cleanup {cleanup}\n",
                          &"tim: Report  {Report}\n"
  let f = if save.len > 0: open(save, fmAppend) else: nil
  var r = read.maybeRead
  proc get1(cmd: string, i = -1): float =             # Either use read times..
    result = if cmd in r:                             #..or sample new ones, but
        try   : r[cmd].popFirst                       #..don't cross mode perCmd
        except: IO !! "`"&cmd&"`: undersampled in `read`"
      else: f.sample1 cmd, if i<0:"" else:prepare[i], if i<0:"" else:cleanup[i]
    result *= dtScale
  var e = newSeq[MinEst](cmds.len + int(oHead > 0))   # Auto-Inits to 0.0+-0.0
  var names: seq[string]        # Optional deep dives run cmds taking solo paths
  if oHead > 0:                                       # Measure overhead
    for t in 1..warmup: discard "".get1(0)
    e[0] = eMin(max(n, oHead), k, m, get1="".get1(0)) # Measure&Report oHead
    names.add (if OHead.len > 0: OHead
      elif card(Report) > 0: "AlreadySubtractedOverhead" else: "RawOverhead")
    if Report != {ratios}:
      echo fmtUncertain(e[0].est, e[0].err)," ",timeUnit,'\t',names[^1]
    if graph.len > 0: writeFile names[^1], e[0]
  var iMin = 0; var eMin = float.high
  for i, cmd in cmds:                                 # Measure each cmd
    let j = i + int(oHead > 0)
    let cols = cmd.split(delim, 1)
    let name = cols[0]; let cmd = if cols.len > 1: cols[1] else: name
    names.add name
    for t in 1..warmup: discard cmd.get1(j)
    e[j] = eMin(n, k, m, get1=cmd.get1(j))            # Below maybe -= oHd
    if oHead > 0 and (diffs in Report or ratios in Report):
      e[j].est -= e[0].est
      e[j].err = sqrt(e[j].err^2 + e[0].err^2)
    if Report != {ratios}:
      echo fmtUncertain(e[j].est, e[j].err)," ",timeUnit,"\t",name
    if ratios in Report and e[j].est < eMin: eMin=e[j].est; iMin=j # Track min
    if graph.len > 0: writeFile name, e[j]
  if ratios in Report:
    if Delim.len > 0: echo Delim
    let ferrMin = e[iMin].err/e[iMin].est             # fractional err(min time)
    for i, name in names:
      if oHead > 0 and i==0: echo fmtUncertain(0.0, e[0].err/e[0].est),"\t",name
      elif i == iMin: echo fmtUncertain(1.0, ferrMin),"\t*",name # min time
      elif i > 0:                                     # (e[i] - e[0])/e[iMin]
        e[i].err = sqrt(ferrMin^2 + (e[i].err/e[i].est)^2)
        e[i].est = e[i].est/e[iMin].est
        e[i].err *= e[i].est
        echo fmtUncertain(e[i].est, e[i].err),"\t",name
  if graph.len > 0: runOrQuit graph % names, 5

when isMainModule: include cligen/mergeCfgEnv; dispatch tim, help={
  "cmds"   : "[label1:]'command1' [label2:]'command2' ..",
  "warmup" : "number of warm-up runs to discard",
  "n"      : "number of inner trials; `>=2k`; `1/m` total",
  "k"      : "number of best tail times to use/2",
  "m"      : "number of outer trials",
  "oHead"  : "number of \"\" overhead runs",
  "save"   : "also save TIMES<TAB>CMD<NL>s to this file",
  "read"   : "read output of `save` instead of running",
  "Report" : "Report flags: `diffs`, `ratios`; {}=raw",
  "prepare": "cmd run before each *corresponding* cmd<i>",
  "cleanup": "cmd run after each *corresponding* cmd<i>",
"timeUnit":"""(n|nano|micro|μ|u|m|milli)(s|sec|second)[s]
OR min[s] minute[s] { [s]=an optional 's' }""",
  "delim"  : "between each *OPTIONAL* `label` & `command`",
  "Delim"  : "line before ratio report, if any",
  "OHead"  : "label for overhead itself (`sh -c ''`)",
  "graph" :"""a command to plot durations/distributions;
$1 $2 .. become dt0, dt1 parallel to cmds""",
  "verbose": "log parameters & some activity to stderr"}, short={"timeUnit":'u'}
