import std/[strutils, posix], cligen/[osUt, statx]
when not declared(stdout): import std/syncio

proc eval(ch: char, st: Statx, euid: Uid, egid: Gid): bool =
  let m = Mode(st.stx_mode)
  case ch
  of 'e': st.stx_blksize == 1           # exists in any way
  of 'b': m.S_ISBLK                     # is block special
  of 'c': m.S_ISCHR                     # is character special
  of 'd': m.S_ISDIR                     # is a directory
  of 'f': m.S_ISREG                     # is a regular file
  of 'l','L': m.S_ISLNK                 # is a symbolic Link
  of 'p': m.S_ISFIFO                    # is a named pipe {aka FIFO}
  of 'S': m.S_ISSOCK                    # is a Socket
  of 's': st.stx_size > 0               # has a size greater than zero
  of 'h': st.stx_nlink > 1              # is a hard link; nlink > 1
  of 'N': st.stx_mtime > st.stx_atime   # New; modify time > access time
  of 'u': (m and 0o4000) != 0           # its set-user-ID bit is set
  of 'g': (m and 0o2000) != 0           # is set-group-ID
  of 'k': (m and 0o1000) != 0           # has its sticky bit set
  of 'O': st.stx_uid == euid            # is Owned by the effective user ID
  of 'G': st.stx_gid == egid            # is owned by effective Group ID
  of 'r': (m and 0o4) != 0              # user can read; Q: Add access(2) way?
  of 'w': (m and 0o2) != 0              # user can write
  of 'x': (m and 0o1) != 0              # user can execute | traverse
  of 'R': (m and 0o400) != 0            # world can read
  of 'W': (m and 0o200) != 0            # world can write
  of 'X': (m and 0o100) != 0            # world can execute | traverse
  of 'A': (m and 0o040) != 0            # group can read
  of 'I': (m and 0o020) != 0            # group can write
  of 'E': (m and 0o010) != 0            # group can execute | traverse
  else: false                           # Any unknown char => false

proc maybeFlip(flip, val: bool): bool = (if flip: not val else: val)

proc isType*(path, expr: string; euid: Uid, egid: Gid): bool =
  var st: Statx                 # Re-purpose stx_blksize as an lstatx-Ok code
  st.stx_blksize = if lstatx(path, st) == 0: 1u32 else: 0u32
  var flip = false
  result = true
  for ch in expr:
    case ch
    of '^': flip = not flip
    else:
      result = result and maybeFlip(flip, ch.eval(st, euid, egid))
      if not result: return
      flip = false

proc ft*(file="", delim='\n', term='\n', pattern="$1", expr="e",
         paths: seq[string]) =
  ## Batch (in both predicates & targets) `test` / `[` .  Emit subset of paths
  ## that pass `expr`.  E.g.: `$(ft -eL \*)` =~ Zsh extended glob `\*(@)`.  Can
  ## also read stdin as in `find -type f|ft -ew`.  (Yes, could cobble together
  ## with GNU `find -files0-from` less tersely & with more quoting concerns.)
  let (euid, egid) = (geteuid(), getegid())     # only do this *once*
  let it = both(paths, fileStrings(file, delim))
  for path in it():
    if isType(path, expr, euid, egid):
      stdout.write pattern % [path], term

when isMainModule: import cligen; dispatch ft, help={
  "file"   : "optional input ( `\"-\"` | !tty = ``stdin`` )",
  "delim"  : "input file delimiter; `\\\\0` -> NUL",
  "term"   : "output path terminator",
  "pattern": "emit some \\$1-using pattern",
  "expr"  :"""Concatenated extended one-letter test(1) codes
    e  (e)xists in any way
    b  is (b)lock special
    c  is (c)haracter special
    d  is a (d)irectory
    f  is a regular (f)ile
   l|L is a symbolic (l)ink; NOTE: h differs!
    p  is a named (p)ipe {aka FIFO}
    S  is a (S)ocket; CASE differs from ls/find
    s  has a (s)ize greater than zero
    h  is a (h)ard link; Link count > 1
    N  (N)ew; modify time > access time
    k  has its stic(k)y bit set
    u  its set-(u)ser-ID bit is set
    g  is set-(g)roup-ID
    O  is (O)wned by the effective user ID
    G  is owned by effective (G)roup ID
  r|R|A user|World|Group can (r)ead
  w|W|I user|World|Group can (w)rite
  x|X|E user|World|Group can e(x)ecute|traverse
In all cases a file must exist for 'true'
Codes are logically ANDed; '^' prefix => NOT"""}
