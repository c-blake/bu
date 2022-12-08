import posix

proc fread*(bsz=16384, paths: seq[string]) =
  ## This is like `cat`, but just discards data.  Empty `paths` => just read
  ## from stdin.  That can be useful to ensure data is in an OS buffer cache,
  ## measure drive/pipe throughput, etc.  Eg. in Zsh you can say: `fread \*\*`.
  ##
  ## Users may pass paths to FIFOs/named pipes or other block-on-open special
  ## files. We want to skip those but also avoid check-then-use races.  So, open
  ## O_NONBLOCK, but then immediately fstat to skip non-regular & reactivate
  ## blocking with fcntl to be CPU-sharing-friendly.
  var buf = newString(bsz)
  if paths.len == 0:
    while read(0, buf[0].addr, bsz) > 0: discard
  else:
    var fd, flags: cint
    var st: Stat
    for path in paths:
      if (fd = open(path.cstring, O_RDONLY or O_NONBLOCK); fd >= 0) and
          fstat(fd, st) == 0 and S_ISREG(st.st_mode) and
          (flags = fcntl(fd, F_GETFL); flags >= 0) and
          fcntl(fd, F_SETFL, flags and not O_NONBLOCK) == 0:
        while read(fd, buf[0].addr, bsz) > 0: discard
      if fd >= 0 and fd.close < 0:
        break

when isMainModule: import cligen; dispatch fread, help={
  "bsz": "buffer size for IO", "paths": "paths: paths to read in"}
