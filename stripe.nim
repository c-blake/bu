{.push hint[Performance]: off.}         # No warn about token copy in bu/execstr
import std/[strutils, parseutils, os, posix, random],
       cligen, cligen/posixUt, bu/execstr
when not declared(stderr): import std/syncio
when defined(release): randomize()

proc `$`(tv: Timeval): string =         # For Rusage.ru_utime, Rusage.ru_stime
  $clong(tv.tv_sec) & "." & intToStr(tv.tv_usec, 6)
proc timeOfDay(): Timespec = discard clock_gettime(CLOCK_REALTIME, result)
proc `$`(t: Timespec):string = $clong(t.tv_sec) & intToStr(t.tv_nsec div 1000,6)
proc ERR(x: string) = stderr.write(x)

const BefDfl = "$tm \e[1mslot: $nm $cmd\e[m"
const AftDfl = "$tm \e[7mslot: $nm usr: $u sys: $s\e[m"
const IrpDfl = "$tm interrupt $nm after $w: $cmd"
var bef, aft, irp: string; var binsh,fancy,numMo,putSN: bool # How prog called

var sh_cmd: int                         # Shared between bg_setup() & bg()
var sh_av: cstringArray
var dSlot = 0                           # Signal handlers access these globals
var sumSt, nKid: int                    # sum(exCodes) & num live kids
var rs: seq[tuple[pid: Pid; nm, sub, cmd: string; t0: Timespec]]
proc rsFind(p: Pid): int =
  result = -1; for i, r in rs: (if r.pid == p: return i)

proc overloaded(loadSlot, n: int): bool =
  proc getloadavg(avs: pointer, nelem: int): int {.importc, header: "stdlib.h".}
  var avs: array[3, float]
  if loadSlot notin 0..2: return false  # Could raise ValueError
  let got = getloadavg(avs[0].addr, 3)
  if got == -1 or loadSlot > got: return false
  avs[loadSlot] > n.float               # Fastest=300s-avg means sleep >= 3 sec

proc maybeSleep(secs: float; seqNo, load: int) =
  if   secs > 0.0 and seqNo > 1: discard usleep(Useconds(secs * 1000000))
  elif secs < 0.0 and seqNo > 1: discard usleep(Useconds(rand(-secs * 1000000)))
  while overloaded(load,rs.len): discard usleep(Useconds(max(3.0,secs.abs)*1e6))

iterator lines2(f: File, tot: var int): string =
  if "$tot" in bef:                     # `bef` requests $tot =>read all upfront
    var all: seq[string]                # std/sugar.collect fails in iterators?
    for line in f.lines: all.add line
    tot = all.len                       # Provide for $tot interpretation
    for line in all: yield line         #  ..as in $seq/$tot message with -b
  else:
    for line in f.lines: yield line

proc bg_setup(run: string): File =      #NOTE: Immediately dups stdin for result
  discard open(result, dup(0), fmRead)  # Keep kids away from stdin; FD_CLOEXEC
  discard close(0)                      #..borks due to misinterp.of reused fd0
  discard open("/dev/null", O_RDONLY)   # Replace original fd0 with /dev/null
  binsh = run == "/bin/sh"
  if binsh: return
  var sh = run.split()                  # PRE-ARRANGE so can do _av[_cmd]=cmd
  if sh[^1] != "-c": sh.add("-c")       # Assume -c option has sh meaning
  sh_cmd = len(sh)                      # array slot of cmd string
  sh.add("dummyArg")
  sh_av = allocCStringArray(sh)

proc bg(cmd: string; seqNo, i, tot: int): Pid =
  if bef.len > 1:                       # `> 1` since \n is always appended.
    rs[i].t0 = timeOfDay()
    ERR bef%["tm",$rs[i].t0, "nm",rs[i].nm, "cmd",cmd, "seq",$seqNo, "tot",$tot]
  if aft.len > 1: rs[i].cmd = cmd       # Maybe save for `wait` report
  if putSN: putEnv "STRIPE_SEQ", $seqNo # Sequence number export was requested
  putEnv("STRIPE_SLOT", $i)             # This & next both cycle over small sets
  if rs[i].sub.len != 0:                #..So, could maybe be optimized to save
    putEnv("STRIPE_SUB", rs[i].sub)     #..0.5-1 microsec so per kid launch.
  var pid: Pid = vfork()                # MUST BE C-ish between vfork & exec
  if pid == -1: exitnow(3)              # vfork failed! => DIE NOW
  if pid != 0: return pid               # Parent returns
  if binsh:                             # Replace kid w/my "execstr" of cmd
    if execStr(cmd) == 0: exitnow(0)    # Auto-fallback to /bin/sh -c 'cmd'
  else:
    sh_av[sh_cmd] = cstring(cmd)
    discard execvp(sh_av[0], sh_av)     # Replace kid w/shell to run cmd
  ERR("Cannot run \"$#\"\n" % cmd)
  exitnow(113)                          # ..or exit kid on failed exec

proc wait(): int =
  var ru: Rusage
  var st: cint
  var i = -1
  while i < 0:                          # 1st|pid from prior prog of same parent
    let pid = wait4(Pid(-1), addr st, cint(0), addr ru)
    i = rsFind(pid)                     # Unfound => not our kid! (Pre-exec)
  nKid -= 1                             # Count kid & accum exit status
  rs[i].pid = 0.Pid                     # Mark run slot free (Maybe unneeded)
  if WIFEXITED(st): sumSt += WEXITSTATUS(st)
  if aft.len > 1:                       # Maybe report rusage
    let t1 = timeOfDay(); var w: Timeval; var pc: string; var mr: string
    if fancy:
      let dt     = t1 - rs[i].t0; w = dt.nsToTimeVal
      let tSched = ru.ru_utime.tv_sec.int*1_000_000 + ru.ru_utime.tv_usec +
                   ru.ru_stime.tv_sec.int*1_000_000 + ru.ru_stime.tv_usec
      pc = formatFloat(tSched.float * 1e5 / dt.float, ffDecimal, 1)
      mr = formatFloat(ru.ru_maxrss.float/1024.0, ffDecimal, 1)
    ERR aft % ["tm",$t1, "nm",rs[i].nm, "w",$w, "pcpu",pc, "m",mr, #%cpu,MiB RSS
               "u",$ru.ru_utime, "s",$ru.ru_stime, "cmd",rs[i].cmd]
  rs[i].cmd.setLen 0
  i

proc stripe(jobs: File, secs = 0.0, load = -1): int =
  var nSlot = rs.len
  var seqNo = 1; var tot = 0
  for cmd in lines2(jobs, tot):         # Get a cmd, maybe wait for slot
    var i = if nKid == nSlot: wait() else: rsFind(0.Pid)
    if numMo:                           # MAYBE ADJUST NUMBER OF RUN SLOTS
      let diff = dSlot                  # Minimize real time window for..
      dSlot = 0                         # ..signal deliveries to be lost.
      if diff > 0:                      # At least one SIGUSR1 during wait
        let n = min(1024, nSlot + diff)
        for k in nSlot ..< n: rs.add (0.Pid, $k, "", "", rs[0].t0)
      elif diff < 0:                    # At least one SIGUSR2 during wait
        let n = max(1, nSlot + diff)    # NOTE: wait does the nKid -= 1
        while nKid + 1 > n:             # nKid usually starts @nSlot-1, but SIG
          rs.delete i                   # ..can hit while still ramping up kids.
          i = wait()                    # ..Either way wait until nKid=n is ok.
      nSlot = rs.len   
    maybeSleep(secs, seqNo, load)       # MAYBE SLEEP BEFORE LAUNCH
    rs[i].pid = bg(cmd, seqNo, i, tot)
    nKid += 1                           # Count kid as spawned
    seqNo += 1
  while nKid > 0: discard wait()        # No more new=>Wait for any until 0 kids
  sumSt                                 # Exit w/informative status

proc CLI(run="/bin/sh", nums=false, secs=0.0, load = -1, before="", after="",
         irupt="", posArgs: seq[string]) =
  ## where `posArgs` is either a number `<N>` *or* `<sub1 sub2..subM>`, reads
  ## job lines from *stdin* and keeps up to `N` | `M` running at once.
  ## 
  ## In sub mode, each job has **$STRIPE_SUB** set, in turn, to `subJ`.  Eg.:
  ##   ``find . -printf "ssh $STRIPE_SUB FileJob \'%P\'\\n" | stripe X Y``
  ## runs `FileJob`\s first on host X then on host Y then on whichever finishes
  ## first.  Repeat `X` or `Y` to keep more jobs running on each host.
  ## 
  ## **$STRIPE_SLOT** (arg slot index) & optionally **$STRIPE_SEQ** (job seqNum)
  ## are also provided to jobs.  In `N`-mode `SIGUSR[12]` (in|de)creases `N`.
  ## If `before` uses `$tot`, job lines are read upfront to provide that count.
  if len(posArgs) < 1:
    raise newException(ValueError, "Too few posArgs; need { num | 2+ slots }")
  putSN = nums
  bef   = (if before in ["d", "D"]: BefDfl else: before) & "\n"
  aft   = (if after  in ["d", "D"]: AftDfl else: after ) & "\n"
  irp   = (if irupt  in ["d", "D"]: IrpDfl else: irupt ) & "\n"
  fancy = "$w" in aft or "$pcpu" in aft or "$m" in aft
  numMo = posArgs.len == 1
  if numMo:                             # FIXED NUM JOBS MODE
    var n: int
    if parseInt(posArgs[0], n) == 0 or n <= 0:
      raise newException(ValueError, "Only one slot but not a positive int.")
    rs.setLen n                         #   impossible zero PIDs
    for i in 0 ..< n: rs[i].nm = $i     #   slot names == nums
  else:                                 # STRIPE ID SUBST MODE
    rs.setLen posArgs.len               #   impossible zero PIDs
    for i, a in posArgs: rs[i].nm = a; rs[i].sub = a  # $STRIPE_SLOT,_SUB
  try:
    quit(min(127, stripe(run.bg_setup, secs, load)))
  except IOError:
    stderr.write "No file descrip 0/stdin | stdout/err output space issue.\n"
    quit(min(127, sumSt))

when isMainModule:
  proc ctrlC() {.noconv.} =
    if irp.len > 1:                     # interrupt reports requested
      let t1 = timeOfDay(); var w: Timeval
      for r in rs:
        if r.cmd.len>0:(w = nsToTimeVal(t1 - r.t0); ERR irp %
                        ["tm",$t1, "nm",r.nm, "w",$w, "cmd",r.cmd, "sub",r.sub])
    quit(min(127, sumSt))               # stdlib saturates at 127
  setControlCHook(ctrlC)

  proc sigu12(signo: cint) {.noconv.} =
    if   signo == SIGUSR1: inc(dSlot)   # SIGUSR1 increases N
    elif signo == SIGUSR2: dec(dSlot)   # SIGUSR2 decreases N
  signal(SIGUSR1, sigu12); signal(SIGUSR2, sigu12)

  include cligen/mergeCfgEnv
  dispatch CLI, cmdName = "stripe",
           help={"run"   : "run job lines via this interpreter",
                 "nums"  : "provide **STRIPE_SEQ** to job procs",
                 "secs"  : "sleep `SECS` before running each job",
                 "load"  : "0/1/2: 1/5/15-minute load average < `N`",
                 "before":"""\"D\": $tm \\e[1mslot: $nm $cmd\\e[m
alsoAvail: \$seq \$tot""",
                 "after" :"""\"D\": $tm \\e[7mslot: $nm usr: $u sys: $s\\e[m
alsoAvail: wall \$w MiBRSS \$m \$pcpu \$cmd""",
                 "irupt" :"""\"D\": $tm interrupted $nm after $w: $cmd
alsoAvail: substitution \$sub"""}
