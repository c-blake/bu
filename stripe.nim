{.push hint[Performance]: off.}         # No warn about token copy in bu/execstr
import std/[strutils, parseutils, os, posix, random],
       cligen, cligen/posixUt, bu/execstr
when not declared(stderr): import std/syncio
when defined(release): randomize()

proc overloaded(loadSlot, n: int): bool =
  proc getloadavg(avs: pointer, nelem: int): int {.importc, header: "stdlib.h".}
  var avs: array[3, float]
  if loadSlot notin 0..2: return false  # Could raise ValueError
  let got = getloadavg(avs[0].addr, 3)
  if got == -1 or loadSlot > got: return false
  avs[loadSlot] > n.float

proc `$`(tv: Timeval): string =         # For Rusage.ru_utime, Rusage.ru_stime
  $clong(tv.tv_sec) & "." & intToStr(tv.tv_usec, 6)
proc timeOfDay(): Timespec = discard clock_gettime(CLOCK_REALTIME, result)
proc `$`(t: Timespec):string = $clong(t.tv_sec) & intToStr(t.tv_nsec div 1000,6)

proc ERR(x: string) = stderr.write(x)
const BefDfl = "$tm \e[1mslot: $nm $cmd\e[m"
const AftDfl = "$tm \e[7mslot: $nm usr: $u sys: $s\e[m"
var bef, aft: string
var binsh = false; var fancy = false    # Flags based on how we are called
var sh_cmd: int                         # Shared between bg_setup() & bg()
var sh_av: cstringArray
var exportSeqNo: bool = false           # Export STRIPE_SEQ if user-requested
var dSlot = 0                           # Signal handlers update this global
var t0: seq[Timespec]                   # Wall clock start times

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

proc bg(cmd: string; verb, seqNo, i, tot: int; name, sub: seq[string]): int =
  if (verb and 1) != 0:
    t0[i] = timeOfDay()
    ERR bef % ["tm",$t0[i], "nm",name[i], "cmd",cmd, "seq",$seqNo, "tot",$tot]
  if exportSeqNo:                       # Sequence number export was requested
    putEnv("STRIPE_SEQ", $seqNo)
  putEnv("STRIPE_SLOT", $i)             # This & next both cycle over small sets
  if sub.len != 0:                      #..So, could maybe be optimized to save
    putEnv("STRIPE_SUB", sub[i])        #..0.5-1 microsec so per kid launch.
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

var nKid, sumSt: int = 0                # num live kids & sum(exCodes)

proc wait(verb: int, slot: seq[int], name: seq[string]): int =
  var ru: Rusage
  var st: cint
  var i = -1
  while i < 0:                          # 1st|pid from prior prog of same parent
    let pid = wait4(Pid(-1), addr st, cint(0), addr ru)
    i = slot.find(pid)                  # Unfound => not a kid of ours!
  nKid -= 1                             # Count kid & accum exit status
  if WIFEXITED(st): sumSt += WEXITSTATUS(st)
  if (verb and 2) != 0:                 # Maybe report rusage
    let t1 = timeOfDay(); var w: Timeval; var pc: string; var mr: string
    if fancy:
      let dt     = t1 - t0[i]
      w.tv_sec   = Time(dt div 1_000_000_000)
      w.tv_usec  = clong(dt mod 1_000_000_000) div 1_000
      let tSched = ru.ru_utime.tv_sec.int*1_000_000 + ru.ru_utime.tv_usec +
                   ru.ru_stime.tv_sec.int*1_000_000 + ru.ru_stime.tv_usec
      pc = formatFloat(tSched.float * 1e5 / dt.float, ffDecimal, 1)
      mr = formatFloat(ru.ru_maxrss.float/1024.0, ffDecimal, 1)
    ERR aft % ["tm",$t1, "nm",name[i], "w",$w, "pcpu",pc, "m",mr, #%cpu,MiB RSS
               "u",$ru.ru_utime, "s",$ru.ru_stime]
  return i

proc stripe(jobs: File, slot: var seq[int], name,sub: var seq[string],
            secs = 0.0, load = -1, verb = 0): int =
  var nSlot = len(slot); t0.setLen nSlot
  var seqNo = 1; var tot = 0
  for job in lines2(jobs, tot):         # Get a job, maybe wait for slot
    var i = if nKid == nSlot: wait(verb, slot, name) else: slot.find(0)
    if sub.len == 0:
      let diff = dSlot                  # Minimize real time window for..
      dSlot = 0                         # ..signal deliveries to be lost.
      if diff > 0:                      # At least one SIGUSR1 during wait
        let n = min(1024, nSlot + diff)
        for j in nSlot ..< n:
          slot.add(0)
          name.add($j); t0.add t0[0]
      elif diff < 0:                    # At least one SIGUSR2 during wait
        let n = max(1, nSlot + diff)    # NOTE: wait does the nKid -= 1
        while nKid + 1 > n:             # nKid will usually start @nSlot-1..
          slot.delete(i)                # ..but a signal could hit while..
          name.delete(i); t0.delete(i)  # ..stripe is still ramping up kids.
          i = wait(verb, slot, name)    # Either way wait until nKid=n is ok
      nSlot = len(slot)
    if secs > 0.0 and seqNo > 1:        # Maybe sleep before launch
      discard usleep(Useconds(secs * 1_000_000))
    elif secs < 0.0 and seqNo > 1:
      discard usleep(Useconds(rand(-secs * 1_000_000)))
    while overloaded(load, slot.len):   # While overloaded sleep >= 1 second
      discard usleep(Useconds(max(1.0, secs.abs) * 1_000_000.float))
    slot[i] = bg(job, verb, seqNo, i, tot, name, sub)
    nKid += 1                           # Count kid as spawned
    seqNo += 1
  while nKid > 0:                       # No more to start =>
    discard wait(verb, slot, name)      # Wait for any until nKid == 0
  return sumSt                          # Exit w/informative status

proc CLI(run="/bin/sh", nums=false, secs=0.0, load = -1, before=false,
         after=false, BefFmt="", AftFmt="", posArgs: seq[string]) =
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
  ## If `BefFmt` uses `$tot`, job lines are read upfront to provide that count.
  var verb = (if before: 1 else: 0) or (if after: 2 else: 0) # verbosity mask
  exportSeqNo = nums
  if len(posArgs) < 1:
    raise newException(ValueError, "Too few posArgs; need { num | 2+ slots }")
  bef = (if BefFmt.len > 0: BefFmt else: BefDfl) & "\n"
  aft = (if AftFmt.len > 0: AftFmt else: AftDfl) & "\n"
  fancy = "$w" in aft or "$pcpu" in aft or "$m" in aft
  var slot: seq[int]
  var name, sub: seq[string]
  if len(posArgs) == 1:                 # FIXED NUM JOBS MODE
    var n: int
    if parseInt(posArgs[0], n) == 0 or n <= 0:
      raise newException(ValueError, "Only one slot but not a positive int.")
    slot = newSeq[int](n)               #   impossible zero PID
    name = newSeq[string](n)
    for i in 0 ..< n: name[i] = $i      #   slot names == nums
    sub = newSeq[string](0)             #   0 len => no substs
  else:                                 # STRIPE ID SUBST MODE
    slot = newSeq[int](len(posArgs))    #   impossible zero PID
    name = posArgs                      #   successive vals of
    sub  = posArgs                      #   $STRIPE_SLOT,_SUB
  try:
    quit(min(127, stripe(run.bg_setup, slot, name, sub, secs, load, verb)))
  except IOError:
    stderr.write "No file descrip 0/stdin | stdout/err output space issue.\n"
    quit(min(127, sumSt))

when isMainModule:
  proc ctrlC() {.noconv.} = quit(min(127, sumSt)) # Could be 2-128 dep on which
  setControlCHook(ctrlC)                          #..consistency we want.

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
                 "before": "emit pre-run report to *stderr*",
                 "after" : "emit post-complete to *stderr*",
                 "BefFmt":"""\"\": $tm \\\\e[1mslot: $nm $cmd\\\\e[m
also avail: \$seq \$tot""",
                 "AftFmt": """\"\": $tm \\\\e[7mslot: $nm usr: $u sys: $s\\\\e[m
also avail: \$w (wall) \$m (MiB RSS) \$pcpu"""}
