import std/[os, posix, strformat]       # Nim program to measure Resource Usage
# Many globals since `report` is sighandler to print even if session is killed.
var pid: Pid                            # Process Id of kid we monitor
var st: cint                            # Exit status of same kid
var ruV: Rusage; var ruA = ruV.addr     # Holds resource usage data from OS
template r(nm): untyped = ruV.`ru nm`   # Abbreviate field access
var oh0, oh1, t0, t1: Timespec          # For timing overhead & timing itself
var e0 = "\e[1;3m"                      # ANSI SGR color escape for bold-italic
var e1 = "\e[m"                         # Turn off colors

var fWrap, fH, fTm, fIO, fSwSh, fComm, fPlain, fUnWrp: bool #Flags: See below
const use = """Usage:
  ru [-whatiscpu] <prog> [prog args...]
No options => as if -hit; else selected subset.  Flags all in arg 1 & mean:
  w  w)rapped output without row labels (to get fields by row, e.g. grep)
  h  h)uman readable formats with (h)our:minute:seconds, MiB, etc. units
  a  a)ll of the below, in the same order
  t  t)ime,mem (wall, user, system time, CPU utilization, max Resident)
  i  i)o (inBlocks, outBlocks, swaps, majorFaults, minorFaults)
  s  s)witch/stack/sharing (volCtxSw, involSw, stack, txtResShr, datResShr)
  c  interprocess (c)ommunications (signals, IPC sent, IPC received)
  p  p)lain output (no ANSI SGR color escapes)
  u  u)nwrapped output with field labels (to get fields by column, e.g. awk)
`man getrusage` | `man time` give more details on the various stats this small
Nim program can print.  You can put options in the `RU` environment variable.
Compared to time(1), this is higher precision with more controlled units."""

proc parseArg(arg1: string) =
  fWrap  = 'w' in arg1
  fH     = 'h' in arg1
  fTm    = 't' in arg1
  fIO    = 'i' in arg1
  fSwSh  = 's' in arg1
  fComm  = 'c' in arg1
  fPlain = 'p' in arg1 or existsEnv("NO_COLOR")
  fUnwrp = 'u' in arg1
  if 'a' in arg1: fTm = true; fIO = true; fSwSh = true; fComm = true
  elif not fTm and not fIO and not fSwSh and not fComm:
    fH = true; fIO = true; fTm = true

proc err(s: string) = stderr.write e0, s, ": ", strerror(errno), e1, '\n'

proc now(ts: var Timespec) = discard clock_gettime(CLOCK_MONOTONIC.ClockId, ts)

# In case `clock_gettime` is slow, do warm-up then timed pair.  NOTE: Hot cache
# OH < colder actual, but some correction is more accurate than no correction.
proc measureOverhead() = oh0.now; oh0.now; oh1.now

proc HMS(secs: float): string =         # Human-Readability here means both
  var s = secs                          #..hour,min,sec formats as well as
  var m = secs.int div 60               #..more precision with smaller times.
  let h = m div 60
  s -= 60*m.float
  m -= 60*h                             # The C program let users futz w/formats
  if   h > 0: &"{h}h:{m:02}m:{s:04.1f}" # var "%dh:%02dm:%04.1f"
  elif m > 0: &"{m}m:{s:06.3f}"         # var "%dm:%06.3f"
  else:       &"{s:.6f}"                # var "%.6f"

proc report(sno: cint) {.noconv.} =     # handlers get passed the signal number
  template ts_sec(ts): untyped = ts.tv_sec.float + ts.tv_nsec.float*1e-9
  template tv_sec(tv): untyped = tv.tv_sec.float + tv.tv_usec.float*1e-6
  type F = float
  var sTm, sUs, sSy, sUt, sRS, sIn, sOu, mjF, mnF, swp, vsw, isw, isr, ixr, idr,
      nsg, msn, mrc, s, gap: string
  # WAIT4+ECHILD ignore is unneeded as non-handler, correct as handler.  Signal
  # race between end of main wait4 & call to report(0) is hard to test, though.
  if sno!=0 and wait4(pid,st.addr, 0, ruA)!=pid and errno!=ECHILD: err "WAIT4"
  t1.now                    # Record end time
  if sno != 0: s.add '\n'   # Ensure report begins at start of a terminal line
  let pad = not fWrap and not fUnwrp
  if fTm:
    let tW  = (t1.ts_sec - t0.ts_sec) - (oh1.ts_sec - oh0.ts_sec)
    let tU  = tv_sec(r utime); let tS = tv_sec(r stime)
    if pad:
      sTm = if fH: &"{tW.HMS:>13} wall" else: &"{tW:>13.9f} wall"
      sUs = if fH: &"{tU.HMS:>10} usr"  else: &"{tU:>10.6f} usr"
      sSy = if fH: &"{tS.HMS:>10} sys"  else: &"{tS:>10.6f} sys"
      sUt = &"{100*(tU+tS)/tW:>7.1f} %" # CPU utilization
      sRS = if fH: &"{F(r maxrss)/1024.0:>.3f} mxRM" else: &"{r maxrss} mxRS"
    else:
      sTm = if fH: &"{tW.HMS} wall" else: &"{tW:>13.9f} wall"
      sUs = if fH: &"{tU.HMS} usr"  else: &"{tU:>10.6f} usr"
      sSy = if fH: &"{tS.HMS} sys"  else: &"{tS:>10.6f} sys"
      sUt = &"{100*(tU+tS)/tW:.1f} %" # CPU utilization
      sRS = if fH: &"{F(r maxrss)/1024.0:.3f} mxRM" else: &"{r maxrss} mxRS"
  if fIO: # Divide by 2048 to get MiB from 512 Byte blocks
    if pad:
      sIn = if fH: &"{F(r inblock)/2048:>13.6f} inMB" else: &"{r inblock:>13} inBl"
      sOu = if fH: &"{F(r oublock)/2048:>10.6f} ouMB" else: &"{r oublock:>10} ouBl"
    else:
      sIn = if fH: &"{F(r inblock)/2048:.6f} inMB" else: &"{r inblock} inBl"
      sOu = if fH: &"{F(r oublock)/2048:.6f} ouMB" else: &"{r oublock} ouBl"
    mjF = if pad: &"{r majflt:>9} majF" else: &"{r majflt} majF"
    mnF = if pad: &"{r minflt:>6} minF" else: &"{r minflt} minF"
    swp = &"{r nswap} swap"
  if fSwSh:
    vsw = if pad: &"{r nvcsw:>11} vCSw"  else: &"{r nvcsw} vCSw" 
    isw = if pad: &"{r nivcsw:>10} iCSw" else: &"{r nivcsw} iCSw"
    isr = if pad: &"{r isrss:>9} stck"   else: &"{r isrss} stck"  
    ixr = if pad: &"{r ixrss:>6} tRS"    else: &"{r ixrss} tRS"   
    idr = &"{r idrss} dRS"
  if fComm:
    nsg = if pad: &"{r nsignals:>11} sigs" else: &"{r nsignals} sigs"
    msn = if pad: &"{r msgsnd:>10} sent"   else: &"{r msgsnd} sent"
    mrc = if pad: &"{r msgrcv:>9} rcvd"    else: &"{r msgrcv} rcvd"
  if fWrap:     # 3 layout modes: rows (wrapped), table, columns (unwrapped)
    if fTm  : s.add &"{sTm}\n{sUs}\n{sSy}\n{sUt}\n{sRS}\n"
    if fIO  : s.add &"{sIn}\n{sOu}\n{mjF}\n{mnF}\n{swp}\n"
    if fSwSh: s.add &"{vsw}\n{isw}\n{isr}\n{ixr}\n{idr}\n"
    if fComm: s.add &"{nsg}\n{msn}\n{mrc}\n"
  elif not fUnwrp:
    if fTm  : s.add &"{e0}TM{e1} {sTm}  {sUs}  {sSy}  {sUt} {sRS}\n"
    if fIO  : s.add &"{e0}IO{e1} {sIn}  {sOu}  {mjF}  {mnF}  {swp}\n"
    if fSwSh: s.add &"{e0}SwSh{e1} {vsw}  {isw}  {isr}  {ixr}   {idr}\n"
    if fComm: s.add &"{e0}Comm{e1} {nsg}  {msn}  {mrc}\n"
  else:
    if fTm  : s.add &"{sTm} {sUs} {sSy} {sUt} {sRS}"     ; gap = " "
    if fIO  : s.add &"{gap}{sIn} {sOu} {mjF} {mnF} {swp}"; gap = " "
    if fSwSh: s.add &"{gap}{vsw} {isw} {isr} {ixr} {idr}"; gap = " "
    if fComm: s.add &"{gap}{nsg} {msn} {mrc} "
    s.add '\n'
  # 1 write+immediate exit ensures 1 print EVEN IF sig delivered DURING report 0
  exitnow(if write(2, s[0].addr, s.len) == s.len: st.WEXITSTATUS else: 99)

let argc {.importc: "cmdCount".}: cint          # On POSIX, not a lib; importc
let argv {.importc: "cmdLine".}: cstringArray   #..is both simpler & faster.
let nOpt = if argc>1 and argv[1][0] == '-': 1 else: 0 # cstring has at least \0
parseArg(if nOpt>0: $argv[1] else: getEnv("RU", "hit"))
if fPlain: e0 = ""; e1 = ""
measureOverhead()
for sn in [SIGHUP, SIGINT, SIGQUIT, SIGILL, SIGBUS, SIGFPE, SIGSEGV, SIGPIPE,
           SIGALRM, SIGTERM, SIGURG, SIGXCPU, SIGXFSZ, SIGPOLL, SIGSYS]:
  signal(sn, report)                    # Install report() for most signals
if argc > 1 + nOpt:                     # Measure the program ...
  if (pid = vfork(); pid != 0):         # If vfork fails, -1 => so will wait4
    t0.now
    if wait4(pid, st.addr, 0, ruA) != pid and errno != EINTR: err "wait4"
    report 0                            # Report Usage & exitnow
  else:
    let cmd = cast[cstringArray](argv[1 + nOpt].addr)
    discard execvp(cmd[0], cmd); err "execvp"; quit 1
else: quit use, 1
