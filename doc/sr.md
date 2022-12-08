Motivation
----------

Linux can misbehave, especially on more exotic hardware or with untested
software.  So, the kernel provides a way to interpret special keys on the
keyboard and a more remote-friendly "/proc/sysrq-trigger" interpretation.
This program wraps all of that to make it easy to just run a command to
get the intended results.

For example, if programs and libc are all breaking but you have a statically
linked `sr` and can still get a few pages off the disk you may be able to run
`sr u; sr s; sr b` with some success.

Usage (***NOT*** a cligen utility)
-----
Usage (as root!):
  sr <CODE>
where CODE is:
  b  immediately reboot without syncing or unmounting
  c  crash system by NULL pointer deref, leave crashdump if configured
  d  shows locks that are held
  e  send SIGTERM to all processes, except for init
  f  call OOM killer to kill memory hogs; No panic if nothing can be killed
  g  used by kgdb (kernel debugger)
  i  send SIGKILL to all processes, except for init
  j  forcibly "Just thaw it" - filesystems frozen by FIFREEZE ioctl
  k  secure Access Key (SAK); Kill programs on current virtual console
  l  shows stack backtrace for active CPUs
  m  dump current memory info to your console
  n  used to make RT tasks nice-able
  o  shut your system off (if configured & supported)
  p  dump current registers & flags to your console
  q  dump armed hrtimers (NOT regular timer_list timers) & clockevent dev info
  r  turns off keyboard raw mode & sets it to XLATE
  s  attempt to sync mounted filesystems
  t  dump current tasks & their information to your console
  u  attempt to remount mounted filesystems read-only
  v  forcefully restores framebuffer console; causes ETM buffer dump on ARM
  w  dumps tasks that are in uninterruptable (blocked) state
  x  used by xmon on PPC; Show global PMU Regs on sparc64; Dump TLBs on MIPS
  y  show global CPU Registers [SPARC-64 specific]
  z  dump FTRACE buffer
 0-9 set console log level; 0=emergency messages (PANICs|OOPSes) only
