import std/[os,osproc,posix, strformat,strutils,re, times, sets], cligen/osUt
when not declared(File): import std/[syncio, formatfloat]

proc `$`(x: HashSet[Pid]): string = 
  for pid in x: (if result.len > 0: result.add ' '); result.add $pid

proc log(o: File, t0: var DateTime, msg: string) =
 try:
  let t1 = now(); let diff = t1 - t0; t0 = t1
  o.write t1.format("yyyy/MM/dd-HH:mm:ss,ffffff")#'.' notin times.FormatLiterals
  o.write ": ", msg, " after ", diff.inMilliseconds, " ms\n"; o.flushFile
 except Ce: discard

proc pidStCmd(pid: string): (Pid, char, string) =
  let ps = readFile("/proc/" & pid & "/stat") # Parse PID (CMD) STATE...
  let eoPid = ps.find(" (")      # Bracket CMD. Works even if CMD has
  let eoCmd = ps.rfind(") ")     #..parens or whitespace chars in it.
  if eoPid != -1 and eoCmd != -1 and pid == ps[0 ..< eoPid]:
    result[0] = parseInt(ps[0 ..< eoPid]).Pid
    if (let eoSt = ps.find(' ', start=eoCmd + 2); eoSt != -1):
      result[1] = ps[eoCmd + 2 ..< eoSt][0]
    result[2] = ps[eoPid + 2 ..< eoCmd]

iterator pidStates(): (Pid, char, string) = # yield (pid, st, cmd)
  try:      # Process list is dynamic => time-of-walk/time-of-parse|act errors
    for pcKind, pid in walkDir("/proc", relative=true):
      if pcKind == pcDir and pid.len>0 and pid[0] in Digits: yield pidStCmd(pid)
  except Ce: discard

var pids: HashSet[Pid]

proc stop(o: File; t0: var DateTime; T: float; incl, excl: seq[string]) =
  for (pid, state, cmd) in pidStates():
    if cmd notin excl and (cmd in incl or state == 'R'):
      discard kill(pid, SIGSTOP); pids.incl pid
  o.log t0, &"T {T} C; Paused [{$pids}]"

proc cont(o: File; t0: var DateTime; T: float) =
  for pid in pids:
    let (_, state, _) = pidStCmd($pid)
    if state == 'T': discard kill(pid, SIGCONT)
  o.log t0, &"T {T} C; Resume [{$pids}]"
  pids.clear

proc thermctl*(qry="auto", delay=1.0, match=".", temp=80.0..90.0, log="",
               incl = @["ffmpeg"], excl = @["thermctl"]) =
  ## OS kernels can down clock CPUs but may not be aggressive enough to block
  ## thermal shutdown. This controller can sometimes do better. At `T > temp.b`,
  ## it SIGSTOPs runnable PIDs & at `T <= temp.a`, it SIGCONTs PIDs it stopped.
  ##
  ## NOTE: Pausing can fail to block future work (loadAvg-targeting dispatch,
  ## perms, hot procs often put to sleep just before scheduling thermctl itself,
  ## etc.).  So, this approach is limited, but maybe useful (e.g. on old laptops
  ## with failing fans &| overclocked gamer rigs).
  var excl  = excl
  var qry   = qry                           # Default&massage qry&match params
  var match = match
  if qry == "auto":
   if "Intel" in (try: execCmdEx("uname -p")[0] except Ce: ""): # Nim for $()
    qry="exec turbostat -s CPU,CoreTmp -q -i $1";match="^-";excl.add "turbostat"
   else:
    qry="exec cpuTemp $1"; match = "."; excl.add "cpuTemp"; excl.add "sensors"
  let rx      = re(match)
  let o       = if log.len > 0: open(log, fmAppend) else: stdout
  var t0      = now()                       # Want to log time of stop & cont
  var cooling = false
  for line in popenr(qry % $delay).lines:   # WANT to die if raises IOError here
    if line.contains(rx):                   # Only whole CPU records not /Core
      var cpuTemp = 0.0
      try      : cpuTemp = parseFloat(line.split()[^1])
      except Ce: o.log t0, &"no cpuTemp in: {line}"; continue
      if cooling and cpuTemp <= temp.a:
        o.cont t0, cpuTemp; cooling = false
      elif cpuTemp > temp.b:
        o.stop t0, cpuTemp, incl, excl; cooling = true

when isMainModule:
  import cligen; include cligen/mergeCfgEnv; dispatch thermctl, help={
    "qry"  : "auto:Intel?turbostat -sCPU,CoreTmp:cpuTemp",
    "delay": "$1 param to `qry` (likely a delay)",
    "match": "pattern selecting cpuTemp line",
    "temp" : "`> b` => pause; `< a` => resume",
    "log"  : "path to log control transitions to",
    "incl" : "cmd names to always SIGSTOP *if hot*",
    "excl" : "cmd names to never SIGSTOP"}
