import std/[os, posix]
const SRQ = "/proc/sysrq-trigger"
const use = """Usage (as root!): sr <CODE> where CODE is:
  b  immediately reboot without syncing or unmounting
  c  crash system by NULL pointer deref, leave crashdump if configured
  e  send SIGTERM to all processes, except for init
  f  call OOM killer to kill memory hogs; No panic if nothing can be killed
  i  send SIGKILL to all processes, except for init
  j  forcibly \"Just thaw it\" - filesystems frozen by FIFREEZE ioctl
  k  secure Access Key (SAK); Kill programs on current virtual console
  l  shows stack backtrace for active CPUs
  m  dump current memory info to your console
  n  used to make RT tasks nice-able
  o  shut your system off (if configured & supported)
  p  dump current registers & flags to your console
  q  dump armed hrtimers (NOT regular timer_list timers)&clockevent dev info
  r  turns off keyboard raw mode & sets it to XLATE
  s  attempt to sync mounted filesystems
  t  dump current tasks & their information to your console
  u  attempt to remount mounted filesystems read-only
  w  dumps tasks that are in uninterruptable (blocked) state
  x  used by xmon on PPC; Show global PMU Regs on sparc64; Dump TLBs on MIPS
  y  show global CPU Registers [SPARC-64 specific]
  z  dump FTRACE buffer
 0-9 set console log level; 0=emergency messages (PANICs|OOPSes) only"""

if paramCount() < 1 or paramStr(1).len < 1 or paramStr(1) == "h":
  quit use, 0
if geteuid() != 0:
  quit "only root can use "&SRQ&"\n", 2
let c = paramStr(1)[0]
if c in {'b','c', 'e','f', 'i'..'u', 'w'..'z', '0'..'9'}:
  if (let fd = open(SRQ, O_WRONLY); fd >= 0):
    var buf = [c, '\n']
    if write(fd, buf[0].addr, 2) != 2:
      quit "write()!=2: " & $errno.strerror, 4
  else:
    quit "open "&SRQ&": " & $errno.strerror, 3
else:
  quit use, 1
