import std/[posix, tables]      # Lets you say `dirs|vip -k libtestf.so:cdable`

# Using temporally maybe stale caching is probably wanted if interactive pick
# sessions are short-lived relative to filesystem dynamics.
var cdableCache: Table[cstring, bool]   # CALLER MUST NEVER RELOCATE CSTRINGS

proc cdable(path: cstring): cint {.noconv, exportc, dynlib.} =
  try: cdableCache[path].cint           # Try cache & then `stat` first since ..
  except:                               #..most likely failure is vanishing & ..
    var st: Stat                        #..system more likely optimizes `stat`.
    let res = stat(path, st) == 0 and st.st_mode.S_ISDIR and
              access(path, X_OK)==0     # Net FS/ACLs/etc.=> `access` to confirm
    cdableCache[path] = res
    res.cint
# This module could grow a large family of `bu/ft`-like tests.  PRs welcome if
# this would help your specific application setting.

# On systems with nice enough terminal interaction for `vip` to make sense but
# poor dynamically loadable lib support (are there any??), `vip` *could* add a
# `--validation-coprocess=foo` to make a kid process to delegate requests to,
# mostly blocked read, but ready to read a path, do whatever user-program tests
# & write 1-byte.  While still 2 syscalls per request (in both parent & kid +
# whatever validation work), they are at least fast-ish pipe-IO calls.
