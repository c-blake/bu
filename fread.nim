when not declared(addFloat): import std/formatFloat
import std/times, cligen/[mfile, mslice]
when defined(windows):
  import std/winlean
  let sin = getStdHandle(STD_INPUT_HANDLE)
  proc read(fd: Handle, buf: pointer, len: int): int =
    let len = min(int32.high.int, len).int32
    var nRd: cint
    if readFile(fd, buf, len, nRd.addr, nil) == 0: -1 else: int(nRd)
else: import std/posix

proc fread*(bsz=65536, lim=0i64, nPass=1, off=64, verb=false,paths:seq[string])=
  ## This is like `cat`, but just discards data.  Empty `paths` => just read
  ## from stdin.  That can be useful to ensure data is in an OS buffer cache
  ## or try to evict other data (more portably than /proc/sys/vm/drop_caches)
  ## for cold-cache runs, measure drive/pipe or device throughput, etc.  Eg. in
  ## Zsh you can say: `fread \*\*` or `fread -l $((1<<30)) < /dev/urandom`.
  ##
  ## Users may pass paths to FIFOs/named pipes/other block-on-open special files
  ## which are skipped.  Anything named is only used if mmap-able & only 1 byte
  ## (really 1 cache line) per 4096 is used by the process.  Can use multiple
  ## passes to measure DIMM bandwidth through a CPU prefetching lens.
  var buf = newString(bsz)
  var n = 0i64
  let mx = if lim != 0: lim else: int64.high
  let t0 = if verb: epochTime() else: 0
  var s = 0
  if paths.len == 0:
    when defined(windows):
      while n < mx and (let k = read(sin, buf[0].addr, bsz); k > 0): inc n, k
    else:
      while n < mx and (let k = read(0, buf[0].addr, bsz); k > 0): inc n, k
  else:
    for path in paths:
      if (let mf = mopen path; mf.mem != nil):
        for pass in 0..<nPass: # Use pass-scaled within page offset (line size)
          for o in countup(pass*off and 4095, mf.len - 1, 4096):
            inc s, mf.mslc[o.int].int
            if o > mx: break
          inc n, mf.mslc.len # Pass1: OS do VM page; Pass2+: CPU do 1 cache line
        mf.close             # BUT above^can vary; Can measure via Lin.Regress.
  if verb:
    let dt = epochTime() - t0
    echo "fread ",n," bytes in ",dt," s: ",n.float/dt/1e9," GB/s par",s and 1

when isMainModule: import cligen; dispatch fread, help={
  "bsz": "buffer size for stdin IO", "lim": "max bytes to read; 0=>unlimited",
  "nPass": "passes per file", "off": "total [off*0-origin-pass within pages]",
  "verb": "print bytes read", "paths": "paths: paths to read in"}
