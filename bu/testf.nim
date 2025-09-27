import std/[posix, tables], cligen/mslice # For `dirs|vip -k libtestf.so:cdable`

# Using temporally maybe stale caching is probably wanted if interactive pick
# sessions are short-lived relative to filesystem dynamics.
var cdableCache: Table[MSlice, bool]    # CALLER MUST NEVER RELOCATE BACKING MEM
                                        # (`vip` does not after `parseIn`.)
var buf = ""                            # Reused path buffer to be NUL/\0-term
proc cdable(path: pointer, nPath: clong): cint {.noconv, exportc, dynlib.} =
  let ms = MSlice(mem: path, len: nPath)
  try: cdableCache[ms].cint             # Try cache & then `stat` first since ..
  except:                               #..most likely failure is vanishing & ..
    var st: Stat                        #..system more likely optimizes `stat`.
    buf.setLen nPath; copyMem buf[0].addr, path, nPath
    let cpath = cast[cstring](buf[0].addr)
    let res = stat(cpath, st) == 0 and st.st_mode.S_ISDIR and
              access(cpath, X_OK) == 0  # Net FS/ACLs/etc.=> `access` to confirm
    cdableCache[ms] = res
    res.cint
# This module could grow a large family of `bu/ft`-like tests.  PRs welcome if
# this would help your specific application setting.

# On systems with nice enough terminal interaction for `vip` to make sense but
# poor dynamically loadable lib support (are there any??), `vip` *could* add a
# `--validation-coprocess=foo` to make a kid process to delegate requests to,
# mostly blocked read, but ready to read a path, do whatever user-program tests
# & write 1-byte.  While still 2 syscalls per request (in both parent & kid +
# whatever validation work), they are at least fast-ish pipe-IO calls.
