##[ Since any dir/path component can be renamed/removed/re-permissioned at any
time, the very idea of `cdable` itself is a race condition.  `vip` caches return
for UI logic simplicity & efficiency.  So even more stale info can be displayed
if FS changes fast relative to interactive pick sessions - hopefully rare. ]##

#nim c --app=lib -d=danger -o=bu/libvip.so bu/libvip.nim && install bu/libvip.so
import std/posix        # .so source for use in `dirs|vip -k libvip.so:cdable`

var cpath = ""                            # Reused path buffer to be NUL/\0-term
proc cdableP*(path: pointer, nPath: clong): cint {.noconv, exportc, dynlib.} =
  if nPath == 0 or path.isNil:
    return 0
  cpath.setLen nPath    # `vip` does not open any files post `parseIn()`
  copyMem cpath[0].addr, path, nPath
  cint(chdir(cast[cstring](cpath[0].addr)) == 0)
#NOTE: Above assumes strings come as rooted paths ("/a/b/leafDir").  Lacking a
#      leading "/" makes it a relative path which can succeed relative to the
#      (newly, per all our chdirs) current working directory, but which would
#      fail relative to the original parent process.

#[ To cursor down, `vip` must test one at a time until a success.  To get more
async/scalable needs a batch interface with forked kids which is an ok idea
since hanging NFS mounts can hang kid procs & we may want to kill it.  Laziness
of outer validation may mean only 0..3 timeouts in any given UI interaction.
So, they could be made 50..100ms.  There may be a way to build a critbit tree,
monitor /proc/mounts, and only time out once per mount prefix or etc.  Of
course, a file system could also come back online at any moment as well.

On systems with nice enough terminal interaction for `vip` to make sense but
poor dynamically loadable lib support (are there any??), `vip` *could* add a
`--validation-coprocess=foo` to make a kid process to delegate requests to,
mostly blocked on IPC read, but ready to read a path, do whatever user-program
tests & write 1-byte.  While 2 syscalls per request (in both parent & kid +
whatever validation work), they are at least fast-ish pipe-IO calls.

This module could grow a large family of `bu/ft`-like tests.  PRs welcome if
this would help your specific application setting. ]#

const O_DIRECTORY = 0x10000 #[ No words for how lame std/posix support is
                               to have O_PATH but NOT have O_DIRECTORY. ]#
proc cdable*(path: pointer, nPath: clong): cint {.noconv,exportc,dynlib.} =
  ##[ Needs extra read access on final path component on BSDs & 2 syscalls, but
  said calls are cheap in combination & global state (PWD) isn't altered. ]##
  if nPath == 0 or path.isNil: return 0
  let flags = when defined linux: O_PATH or O_DIRECTORY else: O_DIRECTORY
  cpath.setLen nPath #^^ illumos O_SEARCH?
  copyMem cpath[0].addr, path, nPath
  let fd = open(cast[cstring](cpath[0].addr), flags.int32)
  discard close(fd)
  cint(fd != -1)
