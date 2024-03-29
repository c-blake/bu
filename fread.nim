when not declared(addFloat): import std/formatFloat
when defined(windows):
  import std/[winlean, times]
  let sin = getStdHandle(STD_INPUT_HANDLE)
  proc read(fd: Handle, buf: pointer, len: int): int =
    let len = min(int32.high.int, len).int32
    var nRd: cint
    if readFile(fd, buf, len, nRd.addr, nil) == 0: -1 else: int(nRd)
else:
  import std/[posix, times]

proc fread*(bsz=65536, limit=0u64, verb=false, paths: seq[string]) =
  ## This is like `cat`, but just discards data.  Empty `paths` => just read
  ## from stdin.  That can be useful to ensure data is in an OS buffer cache
  ## or try to evict other data (more portably than /proc/sys/vm/drop_caches)
  ## for cold-cache runs, measure drive/pipe or device throughput, etc.  Eg. in
  ## Zsh you can say: `fread \*\*` or `fread -l $((1<<30)) < /dev/urandom`.
  ##
  ## Users may pass paths to FIFOs/named pipes or other block-on-open special
  ## files. We want to skip those but also avoid check-then-use races.  So, open
  ## O_NONBLOCK, but then immediately fstat to skip non-regular & reactivate
  ## blocking with fcntl to be CPU-sharing-friendly.
  var buf = newString(bsz)
  var n = 0u64
  let mx = if limit != 0: limit else: uint64.high
  let t0 = if verb: epochTime() else: 0
  when defined(windows):
    if paths.len == 0:
        while n < mx and (let k = read(sin, buf[0].addr, bsz); k > 0): inc n, k
  else:
   if paths.len == 0:
    while n < mx and (let k = read(0, buf[0].addr, bsz); k > 0): inc n, k
   else:
    var fd, flags: cint
    var st: Stat
    for path in paths:
      if (fd = open(path.cstring, O_RDONLY or O_NONBLOCK); fd >= 0) and
          fstat(fd, st) == 0 and S_ISREG(st.st_mode) and
          (flags = fcntl(fd, F_GETFL); flags >= 0) and
          fcntl(fd, F_SETFL, flags and not O_NONBLOCK) == 0:
        while n < mx and (let k = read(fd, buf[0].addr, bsz); k > 0): inc n, k
      if fd >= 0 and fd.close < 0:
        break
  if verb:
    let dt = epochTime() - t0
    echo "fread ", n, " bytes in ", dt, " sec = ", n.float/dt/1e9, " GB/s"

when isMainModule: import cligen; dispatch fread, help={
  "bsz": "buffer size for IO", "limit": "max bytes to read; 0=>unlimited",
  "paths": "paths: paths to read in", "verb": "print bytes read"}
