import std/[os, osproc, posix, strformat, strutils, re, times], cligen/osUt

proc log(o: File, t0: var DateTime, msg: string) {.raises: [].} =
 try:
  let t1 = now(); let diff = t1 - t0; t0 = t1
  o.write t1.format("yyyy/MM/dd-HH:mm:ss,ffffff")#'.' notin times.FormatLiterals
  o.write ": ", msg, " after ", diff.inSeconds, " seconds\n"; o.flushFile
 except: discard

iterator pidStates(excl: seq[string]): (Pid, string) = # yield non-excl (pid,st)
  try:      # Process list is dynamic => time-of-walk/time-of-parse|act errors
    for pcKind, pid in walkDir("/proc", relative=true):
      if pcKind == pcDir and pid.len > 0 and pid[0] in Digits:
        let statB = readFile("/proc/" & pid & "/stat") #Parse PID (CMD) STATE...
        let eoPid = statB.find(" (")      # Bracket CMD. Works even if CMD has
        let eoCmd = statB.rfind(") ")     #..parens or whitespace chars in it.
        if eoPid != -1 and eoCmd != -1 and pid == statB[0 ..< eoPid]:
          let pid = parseInt(statB[0 ..< eoPid]).Pid
          let cmd = statB[eoPid + 2 ..< eoCmd]
          if cmd notin excl:
            let eoState = statB.find(' ', start=eoCmd+2)
            if eoState != -1:
              yield (pid, statB[eoCmd+2 ..< eoState])
  except: discard

proc stop(excl: seq[string]) {.raises: [].} =
  for (pid, state) in pidStates(excl):
    if state == "R": discard kill(pid, SIGSTOP)

proc cont(excl: seq[string]) {.raises: [].} =
  for (pid, state) in pidStates(excl):
    if state == "T": discard kill(pid, SIGCONT)

proc thermctl*(qry="auto", ival=1.0, match=".", excl = @["thermctl"], log="",
               temp=80.0..90.0) =
  ## OS kernels can down clock CPUs but are often not aggressive enough to block
  ## thermal shutdown. This controller can sometimes do better. At `T > temp.b`,
  ## it SIGSTOPs runnable PIDs & at `T <= temp.a`, it SIGCONTs stopped PIDs.
  ##
  ## NOTE: Pausing can fail to block future work (loadAvg-targeting work ctl,
  ## permissions, rarely scheduled dispatchers, ..).  This can also continue
  ## shell job ctl stopped jobs.  So, this approach is limited, but still useful
  ## for me (e.g. on old laptops with failing fans &| overclocked gamer rigs).
  var excl  = excl
  var qry   = qry                           # Default&massage qry&match params
  var match = match
  if qry == "auto":
    if "Intel" in (try: execCmdEx("uname -p")[0] except: ""): # Nim for $()
      qry = "turbostat -s CPU,CoreTmp -qi$1"; match = "^-"; excl.add "turbostat"
    else:
      qry = "cpuTemp $1"; match = "."; excl.add "cpuTemp"; excl.add "sensors"
  let rx      = re(match)
  let o       = if log.len > 0: open(log, fmAppend) else: stdout
  var t0      = now()                       # Want to log time of stop & cont
  var cooling = false
  for line in popenr(qry % $ival).lines:    # WANT to die if raises IOError here
    if line.contains(rx):                   # Only whole CPU records not /Core
      var cpuTemp = 0.0
      try   : cpuTemp = parseFloat(line.split()[^1])
      except: stderr.write "could not parse cpuTemp in: ", line, "\n"; continue
      if cooling and cpuTemp <= temp.a:
        o.log t0, &"cpuTemp {cpuTemp} C; Resuming"
        cont excl
        cooling = false
      elif cpuTemp > temp.b:
        o.log t0, &"cpuTemp {cpuTemp} C; Pausing"
        stop excl
        cooling = true

when isMainModule:
  import cligen
  dispatch thermctl, help={
    "qry"  : "auto:Intel?turbostat -sCPU,CoreTmp:cpuTemp",
    "ival" : "$1 param to `qry` (likely a delay)",
    "match": "pattern selecting cpuTemp line",
    "excl" : "cmd names to never SIGSTOP",
    "log"  : "path to log control transitions to",
    "temp" : "`> b` => pause; `< a` => resume"}
