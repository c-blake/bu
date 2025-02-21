when not declared(stdout): import std/syncio
import std/[strutils, strformat], cligen, cligen/osUt, std/posix as px

type BInp* = tuple[fd: cint; st: Stat; name, buf: string; used: int]

proc biOpen*(name: string, mode=O_RDONLY.cint, ibuf=4096, ep=""): BInp =
  if (result.fd = open(name.cstring, mode); result.fd != -1):
    if fstat(result.fd, result.st) != 0:
      raise newException(OSError, &"{ep}: fstat({result.fd}): {errstr()}")
    result.buf.setLen ibuf
  else: raise newException(OSError, &"{ep}: open({name}): {errstr()}")

proc fill*(b: var BInp) =
  if (let r = b.fd.read(b.buf[b.used].addr, b.buf.len - b.used); r >= 0):
    b.used += r.int                     # Update Re: the data that was read
  else: raise newException(OSError, errstr())

template maybeWriteShiftGrow*(b: var BInp; term; o: File, wrErr) =
  if (let nW = b.buf.rfind(term, last=b.used-1) + 1; nW != 0): # hasRecTerm
    if (let wr = o.uriteBuffer(b.buf[0].addr, nW); wr < nW): wrErr
    else:
      moveMem b.buf[0].addr, b.buf[nW].addr, b.used - nW # RingBuf+readv?
      b.used -= nW                      # Partial last record buffer shift
  elif b.used == b.buf.len:             # No Term & Full Buf => GROW buf
    b.buf.setLen b.buf.len*2            # Double; Could grow more slowly

proc flush*(b: var BInp, o: File): bool =
  o.uriteBuffer(b.buf[0].addr, b.used) == b.used

type Unterm* = enum add, log, drop
const ep = "funnel: "                   # Error Prefix
proc funnel*(fin="", rm=false, term='\n', unterm=add, sec=0.002,
             ibuf=4096, obuf=65536, fs: seq[string]) =
  ## Read `term`-inated records from FIFOS as ready, writing ONLY WHOLE RECORDS
  ## to stdout.  (GNU `tail -qfn+1 --pid=stopIfGone A B..` is wary of partial
  ## lines w/input from *stdin* pipes but NOT multi-input FIFOs.  If you are ok
  ## with PID wraparound races, this program may be unneeded -- someday.)
  let nF = fs.len
  if nF < 1: raise newException(HelpError, "Too few FIFOs; Full ${HELP}")
  var saRS = Sigaction(sa_flags: SA_RESTART) # Make EINTR checks unneeded
  for sig in [SIGTSTP, SIGSTOP, SIGCONT]: discard sigaction(sig, saRS)
  var bfs = newSeq[BInp](nF)            # Open files we are tracking
  var fdMx, nS: cint                    # select call & return params
  let tO0 = Timeval(tv_sec: px.Time(sec), tv_usec: Suseconds(sec*1e6))
  var st: Stat                          # Used to check for `fin`
  var done = false                      # flag indicating empty FIFOs => done
  var fR0: TFdSet #; FD_ZERO fR0        # mask of all FIFO fds; Nim auto-zeros
  discard c_setvbuf(stdout, nil, osUt.IOFBF, obuf.csize_t)
  for i in 0 ..< nF:                    # Open fs[]
    try: # Open FIFOs O_RDWR+select allows blocking IO. `fin` says writer done.
      bfs[i] = biOpen(fs[i], O_RDWR, ibuf, ep)
      if not S_ISFIFO(bfs[i].st.st_mode): quit &"{ep}{fs[i]} not a named pipe",3
      FD_SET bfs[i].fd, fR0; fdMx = fdMx.max bfs[i].fd      # Add fd for select
    except: quit &"{ep}open('{fs[i]}'): {errstr()}\n", 4
  inc fdMx; var fR = fR0; var tO = tO0; let tOA = tO.addr   # Set up for select
  while (fR = fR0; tO = tO0; nS = select(fdMx, fR.addr, nil, nil, tOA); true):
    if not done and fin.len > 0 and lstat(fin, st) == 0: # Signal file present
      done = true                       # Set flag saying how to interpret nS==0
    if nS == -1: quit &"{ep}select: {errstr()}\n", 6 # Select error
    elif nS == 0:                       # Select timed out with all empty pipes
      if done: break else: continue     #   => Either `done` or loop again
    for b in mitems bfs:                # For all possible fds:
      if b.fd < 0 or b.fd.FD_ISSET(fR) == 0: continue # Not Ready
      try: b.fill
      except OSError as e: stderr.urite &"{ep}read(b.name): {e.msg}\n"; continue
      b.maybeWriteShiftGrow term, stdout, quit(&"{ep}short write: {errstr()}\n",7)
  for b in mitems bfs:                  # Handle residual unterminated data
    if b.used > 0:
      case unterm
      of add: discard b.flush(stdout); stdout.urite term
      of log: (stderr.urite fmt("<ep><b.name>: unterminated: {", '<', '>');
               discard b.flush(stderr); stderr.urite "}\n")
      of drop: discard                  # Just drop the data
  if rm:                                # Remove FIFOs
    for path in fs:
      if path.cstring.unlink!=0: stderr.urite &"{ep}rm('{path}'): {errstr()}\n"

when isMainModule: include cligen/mergeCfgEnv; dispatch funnel, help={
  "fs"    : "FIFOs...",
  "fin"   : "once `fin` exists, empty pipes => end",
  "rm"    : "unlink FIFOs `fs` when done",
  "term"  : "IO terminator",
  "unterm": "unterminated last record: add=AddTermAsNeeded\n" &
            "log=LogLabeledToStderr; drop=DiscardData",
  "sec"   : "select timeout in seconds (to look for `fin`)",
  "ibuf"  : "initial input buf size (doubled as needed)",
  "obuf"  : "output buf size"}
