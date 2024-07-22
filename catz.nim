import std/[os,posix,strutils,strformat] #LESSOPEN="|-catz %s";tar t -Icatz -f -
when not declared(stderr): import std/syncio

proc errstr: string = $strerror(errno)      # Helper proc
var av0, stdinName, catz_stderr: string     # Global string vars

type Decoder = tuple[ext, hdr: string, inputSlot: int, av: seq[string]]

const htmlDecode = @["html2text", "-nobs", "-width", "8192", "-"]
const decs: seq[Decoder] = @[
  (".zip"    , "PK\x03"     , 2, @["unzip", "-p", ""]),
  (".ZIP"    , "PK\x03"     , 2, @["unzip", "-p", ""]),
  (".gz"     , "\x1Fã"   , 0, @["gzip", "-cdqf"]),
  (".tgz"    , "\x1Fã"   , 0, @["gzip", "-cdqf"]),
  (".Z"      , "\x1Fù"   , 0, @["uncompress"]),
  (".z"      , "\x1Fù"   , 0, @["uncompress"]),
  (".bz"     , "BZ0"        , 0, @["bunzip", "-Q"]),
  (".tbz"    , "BZ0"        , 0, @["bunzip", "-Q"]),
  (".bz2"    , "BZh"        , 0, @["bunzip2"]),
  (".tbz2"   , "BZh"        , 0, @["bunzip2"]),
  (".lzo"    , "âLZO"    , 0, @["lzop", "-df"]),
  (".toz"    , "âLZO"    , 0, @["lzop", "-df"]),
  (".lz"     , "]\x00\x00"  , 0, @["lzmadec", "-cd"]),
  (".lzma"   , "]\x00\x00"  , 0, @["lzmadec", "-cd"]),
  (".tlz"    , "]\x00\x00"  , 0, @["lzmadec", "-cd"]),
  (".xz"     , "˝7zX"    , 0, @["pixz", "-d"]),
  (".txz"    , "˝7zX"    , 0, @["pixz", "-d"]),
  (".Lz"     , "LZIP"       , 0, @["plzip", "-d"]),
  (".tLz"    , "LZIP"       , 0, @["plzip", "-d"]),
  (".lz4"    , "\x04\"M\x18", 0, @["lz4c", "-cdT0"]),
  (".zst"    , "P*M\x18"    , 0, @["pzstd", "-cdq"]),
  ( ".zs"    , "P*M\x18"    , 0, @["pzstd", "-cdq"]),
  (".tzs"    , "P*M\x18"    , 0, @["pzstd", "-cdq"]),
  (".pdf"    , "%PDF"       , 1, @["pdftotext", "", "-"]),
  (".ps"     , "%!PS"       , 0, @["ps2ascii"]),
  (".ps.gz"  , ";xx;"       , 0, @["pz2ascii"]), # Bad header sentinel
  (".ps.bz"  , ";xx;"       , 0, @["pz2ascii"]), # Bad header sentinel
  ( ".ps.bz2", ";xx;"       , 0, @["pz2ascii"]), # Bad header sentinel
  (".ps.xz"  , ";xx;"       , 0, @["pz2ascii"]), # Bad header sentinel
  (".ps.zs"  , ";xx;"       , 0, @["pz2ascii"]), # Bad header sentinel
  (".html"   , "<!DO"       , 0, htmlDecode),
  (".html"   , "<htm"       , 0, htmlDecode),
  (".htm"    , "<htm"       , 0, htmlDecode)]
const PEEK = static: (var mx = 0; (for d in decs: mx = max(mx, d.hdr.len)); mx)

proc decode(decIx: int; path: string) = # Use above table to execvp a decoder
  var dc = decs[decIx]
  if dc.inputSlot != 0:
    if   path.len > 0     : dc.av[dc.inputSlot] = path
    elif stdinName.len > 0: dc.av[dc.inputSlot] = stdinName
    else: quit(&"catz: decoder {dc.av[0]} needs a path but has none", 2)
  if catz_stderr.len > 0:               # Q: optionally open per-path file?
    let fd = open(catz_stderr.cstring, O_WRONLY or O_APPEND or O_CREAT, 0o666)
    if fd != cint(-1): discard dup2(fd, cint(2))
  discard execvp(dc.av[0].cstring, allocCStringArray(dc.av))
  quit(&"catz: decoder \"{dc.av[0]}\": {errstr()}", 1)

proc sfx2ix(file: string): int =        # Find decoder from sfx/extension
  result = -1
  for i, d in decs: (if file.endsWith(d.ext): return i)

proc hdr2ix(hdr: string): int =         # Find decoder from hdr/magic number
  result = -1
  for i, d in decs: (if hdr.startsWith(d.hdr): return i)

proc file2ix(path: string; fd: cint; hdr: var string; off: var int): int =
  result = -1                           # Find decoder from either
  hdr.setLen PEEK
  off = 0
  if path.len > 0:                      # Try to infer via sfx & return if can
    if (result = sfx2ix(path); result != -1): return
  off = read(fd, hdr[0].addr, PEEK)     # ..then via hdr/aka magic number.
  if off == PEEK: result = hdr2ix(hdr)  # Have read enough bytes to classify
  if lseek(fd, -off, SEEK_CUR) != -1:   # Rewind by whatever was read, if can
    off = 0                             # Register no stolen bytes.

proc writeAll(fd: cint; buf: var openArray[char]; n0: int): int =
  var n = n0; var off = 0               # Loop control & buf offset
  while n > 0:
    if (let did = write(fd, buf[off].addr, n.int); did) > 0:
      inc off, did; dec n, did
    elif errno == EINTR: continue       # Good for SIGWINCH,SIGTSTP&such
    else: break
  return n0 - n

proc fdCopy(src, dst: cint) =           # File descriptor copy loop
  when defined(linux):                  # Optimize a few cases for Linux
    proc copy_file_range(fdI: cint, offI: ptr int64, fdO: cint, offO: ptr int64,
      len: csize_t, flags: cuint): int64 {.importc, header: "unistd.h".}
    proc sendfile(fdO: cint, fdI: cint, offI: ptr int64, len: csize_t):
      int64 {.importc: "sendfile", header: "unistd.h".}
    proc splice(fdI: cint, offI: ptr int64, fdO: cint, offO: ptr int64,
      len: csize_t, flags: cuint): int64 {.importc, header: "unistd.h".}
    template tryLoopRet(call) =
      if (let r = call; r >= 0):
        if r == 0: return
        while (let r = call; r != 0):
          if r == -1 and errno != EINTR and errno != EAGAIN: return
        return
    tryLoopRet copy_file_range(src,nil, dst,nil, csize_t.high, 0) # Src&Dst REGF
    tryLoopRet sendfile(dst, src, nil, csize_t(int32.high))       # Src Seekable
    tryLoopRet splice(src,nil, dst,nil, csize_t.high, 0)          # >=1 pipe fds
  var buf: array[65536, char]
  var nR: int
  while (nR = read(src, buf[0].addr, buf.sizeof); nR) > 0:
    if writeAll(dst, buf, nR) != nR: quit(17)
  if nR < 0: quit("catz: read: {errstr()}", 3)

proc oneFile(path: string; do_fork: bool) = # Dispatch just one file
  var hdr = newStringOfCap(PEEK)
  var off: int
  if path.len > 0:
    discard close(0)
    if open(path, O_RDONLY) != 0:
      stderr.write &"{av0}: open(\"{path}\"): {errstr()}\n"; return
  let decIx = file2ix(path, 0, hdr, off)
  if off > 0:                           # Unseekable; fork to re-prepend hdr
    var fds: array[2, cint]
    if pipe(fds) == -1: stderr.write &"{av0}: pipe: {errstr()}\n"; return
    let pipe_writer = fork()
    case pipe_writer
    of 0:                               # Child: stdin -> from parent
      discard dup2(fds[0], 0)
      discard close(fds[1])
      if decIx >= 0: decode(decIx, path)
      else: fdCopy(0, 1); quit(0)
    of -1: stderr.write &"{av0}: fork: {errstr()}\n"
    else:                               # Parent:
      discard close(fds[0])
      if write(fds[1], hdr[0].addr, off) != off: # restore hdr
        stderr.write &"{av0}: {errstr()}\n"; return
      fdCopy(0, fds[1])                 # Blocking RW loop
      discard close(fds[1])
  elif decIx >= 0:
    if not do_fork:                     # Replace current process
      decode(decIx, path)
    let pipe_writer = fork()
    case pipe_writer                    # Child shares stdout
    of 0: decode(decIx, path)
    of -1: stderr.write &"{av0}: {errstr()}\n"
    else:                               # Do any other input files upon fail
      var st: cint; discard waitpid(pipe_writer, st, 0)
  else: fdCopy(0, 1)

proc nFiles(av: seq[string]) =          # Drive oneFile case for n>1
  var fd: array[2, cint]
  var didStdin = false
  var stdin_orig: cint
  if pipe(fd) == -1: quit(&"{av0}: pipe: {errstr()}", 1)
  let pipe_reader = fork()
  if pipe_reader != 0:                  # Make pipe0->orig stdout copier
    discard close(fd[1])
    fdCopy(fd[0], 1)
    quit(0)
  discard close(1)                      # Make pipe1 == stdout for current..
  if dup(fd[1]) != 1:                   #               ..and all subprocs
    discard close(fd[0])
    discard close(fd[1])
    quit(&"{av0}: cannot get stdout", 1)
  discard close(fd[1])
  stdin_orig = dup(0)                   # Save stdin
  for a in av:                          # Create decoders arg-by-arg
    if a == "-":
      if not didStdin:
        discard close(0)
        if dup(stdin_orig) == 0: oneFile("", true)
        didStdin = true
    else: oneFile(a, true)
  discard close(1)                      # Send EOF for out streamer child
  var st: cint; discard waitpid(pipe_reader, st, 0)

catz_stderr = getEnv("CATZ_STDERR")     # Save some globals
av0 = paramStr(0)
let av = commandLineParams()            # CLoption potato parsing
if av.len>0 and av[0] == "-l":          # Dump decoder table & exit
  echo av0," decodes via this table:"; echo "Ext\tByte0-3\tNmSlot\tCommand"
  for (ext, hdr, slot, av) in decs: echo ext,'\t',hdr,'\t',$slot,'\t',av
  quit 0
var o = 0                               # Virtual zero (after next stmt)
if av.len>0 and av[0] == "-d": inc o    # GNU tar -I option needs a "-d"
if av.len>o and av[o].startsWith("-v"): # Specify envVar giving stdin name
  var stdinNameVar: string              # -v$ => stdinName = /dev/stdin
  if av[o].len == 2 and av.len > o + 1: # -v FOO ..
    stdinNameVar = av[o + 1]; inc o, 2  # Shift for option&arg
  else:                                 # -vFOO
    stdinNameVar = av[o][2..^1]; inc o  # Shift for option&arg
  stdinName = getEnv(stdinNameVar, "")
if av.len > o + 1: nFiles av[o..^1]     # Dispatch to nFiles|oneFile
else: oneFile (if av.len > o and av[o] != "-": av[o] else: ""), false
