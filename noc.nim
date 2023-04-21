when not declared(stdin): import std/syncio
import cligen/[mfile, osUt, sysUt, textUt], std/terminal

if stdin.isatty: quit ("Usage:\n    noc < someInput\n" &
  "strips ANSI CSI/OSC/SGR color escape sequences"), 1

if (let mf = mopen("/dev/stdin", err=nil); mf.mem != nil):
  discard c_setvbuf(stdout, nil, IOFBF, 32768) # Boost
  for c in toOa[char](mf.mem, 0, mf.len - 1).noCSI_OSC:
    putchar c
else:
  var io = newSeq[char](32768)  # (i)nput-(o)utput buffer
  var nc: NoCSI_OSC             # call-to-call parser state
  while not stdin.eof:
    let nI = stdin.ureadBuffer(io[0].addr, io.len)
    var nO = 0
    for c in toOa[char](io[0].addr, 0, nI-1).noCSI_OSC(nc):
      io[nO] = c        # seq[char] faster than string here
      nO.inc            # Clobber input w/stripped output
    if nO > 0:          # 0 => Neither progress nor clobber
      if stdout.uriteBuffer(io[0].addr, nO) < nO:
        quit "stdout write fail; out of space?", 1
