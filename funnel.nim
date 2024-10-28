when not declared(stdout): import std/syncio
import std/[strutils, strformat], cligen, cligen/osUt, std/posix as px

type Unterm* = enum add, log, drop
const av = "funnel"
proc funnel*(fin="", rm=false, term='\n', uterm=add, sec=0.002,
             ibuf=4096, obuf=65536, fs: seq[string]) =
  ## Read `term`-terminated records from FIFOS `fs` as ready, writing ONLY WHOLE
  ## records to stdout.  (`tail -q -n+1 -f --pid=stopIfGone A B..` is wary of
  ## partial lines w/input from *stdin* pipes but NOT multi-input FIFOs.  If you
  ## are ok with PID wraparound races, this program may be unneeded -- someday.)
  let nF = fs.len
  if nF < 1: raise newException(HelpError, "Too few FIFOs; Full ${HELP}")
  var fds = newSeq[cint](nF)            # Open FIFO file descriptor
  var buf = newSeq[string](nF)          # Buffer for each fd
  var use = newSeq[int](nF)             # Amount of each buffer in use
  var fdMx, nS: cint                    # select call & return params
  var tO = Timeval(tv_sec:px.Time sec, tv_usec:Suseconds sec*1e6); let tO0 = tO
  var st: Stat                          # Used to check FIFO-hood & `fin`
  var done = false                      # flag indicating empty FIFOs => done
  var fR: TFdSet #; FD_ZERO fR          # mask of all FIFO fds; Nim auto-zeros
  discard c_setvbuf(stdout, nil, osUt.IOFBF, obuf.csize_t)
  for i in 0 ..< nF:                    # Open fs[]
    # Open FIFOs O_RDWR+select allows blocking IO. `fin` sends EOF-in-the-large.
    if (fds[i] = open(fs[i].cstring, O_RDWR); fds[i] != -1):
      if fstat(fds[i], st) != 0: quit &"{av}: fstat({fds[i]}): {errstr()}", 3
      if not S_ISFIFO(st.st_mode): quit &"{av}: {fs[i]} is not a named pipe", 4
      FD_SET fds[i], fR                 # Add fd to master for select
      buf[i].setLen ibuf
      fdMx = max(fdMx, fds[i])
    else: quit &"{av}: open(\"{fs[i]}\"): {errstr()}\n", 5
  inc fdMx
  let fR0 = fR                          # Constant mask of non-empty FIFOs
  while (fR=fR0; tO=tO0; nS = select(fdMx, fR.addr, nil, nil, tO.addr); true):
    if not done and fin.len > 0 and lstat(fin, st) == 0: # Signal file present
      done = true                       # Set flag saying how to interpret nS==0
    if nS == -1:                        # Select error
      if errno == EINTR: continue else: quit &"{av}: select: {errstr()}\n", 6
    elif nS == 0:                       # Select timed out with all empty pipes
      if done: break else: continue     #   => Either `done` or loop again
    for i in 0 ..< nF:                  # For all possible fds:
      if fds[i] < 0 or fds[i].FD_ISSET(fR) == 0: continue           # Not Ready
      if (let r = fds[i].read(buf[i][use[i]].addr, buf[i].len - use[i]); r>=0):
        use[i] += r                     # Update Re: the data that was read
      else:                             # Read error
        if errno != EINTR: stderr.write &"{av}: read(fds[i]): {errstr()}\n"
        continue
      if (let nW = buf[i].rfind(term, last=use[i]-1) + 1; nW != 0): # hasRecTerm
        if (let wr = stdout.writeBuffer(buf[i][0].addr, nW); wr < nW):
          if errno != EINTR: quit &"{av}: wr {wr} < {nW} bytes: {errstr()}\n", 7
        else:                           # ^^Only to last term in buf
          moveMem buf[i][0].addr, buf[i][nW].addr, use[i] - nW # RingBuf+readv?
          use[i] -= nW                  # Partial last record buffer shift
      elif use[i] == buf[i].len:        # No Term & Full Buf => GROW buf
        buf[i].setLen buf[i].len*2      # Double; Could grow more slowly
  for i in 0 ..< nF:                    # Handle residual unterminated data
    if (let n = use[i]; n > 0):
      case uterm
      of add: discard stdout.writeBuffer(buf[i][0].addr, n); stdout.write term
      of log: (stderr.write fmt("<av>: <fs[i]>: unterminated: {", '<', '>');
               discard stderr.writeBuffer(buf[i][0].addr,n); stderr.write "}\n")
      of drop: discard                  # Just drop the data
  if rm:                                # Remove FIFOs
    for path in fs:
      if path.cstring.unlink != 0:
        stderr.write &"{av}: rm(\"{path}\"): {errstr()}\n"

when isMainModule: include cligen/mergeCfgEnv; dispatch funnel, help={
  "fs"    : "FIFOs...",
  "fin"   : "once `fin` exists, empty pipes => end",
  "rm"    : "unlink FIFOs `fs` when done",
  "term"  : "IO terminator",
  "uterm":"""unterminated last record: add=Add term as needed
log=write labeled to stderr; drop=discard data""",
  "sec"   : "select timeout in seconds",
  "ibuf"  : "initial input buf size (doubled as needed)",
  "obuf"  : "output buf size"}
