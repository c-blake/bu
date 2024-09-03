when not defined(linux):
  echo """This is a Linux-only program although ports to other OSes like
FreeBSD kqueue are possible, likely with translation of abstractions."""
else:
 import posix/inotify, std/posix, cligen, cligen/[sysUt, posixUt]
 when not declared(stderr): import std/syncio

 type Event* = enum
  inAccess    ="access"   , inAttrib ="attrib"    , inModify    ="modify"      ,
  inOpen      ="open"     , inCloseWr="closeWrite", inCloseNoWr ="closeNoWrite",
  inMovedFrom ="movedFrom", inMovedTo="movedTo"   , inMoveSelf  ="moveSelf"    ,
  inCreate    ="create"   , inDelete ="delete"    , inDeleteSelf="deleteSelf"

 proc mask(es: set[Event]): uint32 =
  template `|=`(r, f) = r = r or f
  for e in es:
    case e
    of inAccess    : result |= IN_ACCESS
    of inAttrib    : result |= IN_ATTRIB
    of inModify    : result |= IN_MODIFY
    of inOpen      : result |= IN_OPEN
    of inCloseWr   : result |= IN_CLOSE_WRITE
    of inCloseNoWr : result |= IN_CLOSE_NOWRITE
    of inMovedFrom : result |= IN_MOVED_FROM
    of inMovedTo   : result |= IN_MOVED_TO
    of inMoveSelf  : result |= IN_MOVE_SELF
    of inCreate    : result |= IN_CREATE
    of inDelete    : result |= IN_DELETE
    of inDeleteSelf: result |= IN_DELETE_SELF

 iterator dqueues*(events: set[Event]; dirs: seq[string]):
    tuple[i, len: int; name: cstring] =
  ## Set up event watches on dirs & forever yield NUL-term (i, len, ptr char).
  var rd0: TFdSet; var fdMax = 0.cint
  FD_ZERO rd0
  var fds = newSeq[cint](dirs.len)
  for i, dir in dirs:
    fds[i] = cint(inotify_init())
    if fds[i] == -1: raise newException(OSError, "inotify_init")
    if inotify_add_watch(fds[i], dir.cstring, events.mask or IN_ONLYDIR) == -1:
      raise newException(OSError, "inotify_add_watch")
    FD_SET fds[i], rd0
    fdMax = max(fdMax, fds[i])
    discard fcntl(fds[i], F_SETFL, O_NONBLOCK)  # Set to non-blocking
  var evs = newSeq[byte](8192)
  var rd = rd0
  while select(fdMax + 1, rd.addr, nil, nil, nil) != -1 or errno == EINTR:
    for i, fd in fds:
      if FD_ISSET(fd, rd) != 0:
        while (let n = read(fd, evs[0].addr, 8192); n) > 0 or errno == EINTR:
          for ev in inotify_events(evs[0].addr, n):
            yield (i, int(ev[].len), cast[cstring](ev[].name.addr))
        if errno notin [EAGAIN, EWOULDBLOCK]:
          stderr.write "dirq errno: ",errno,"\n"
    rd = rd0

 when isMainModule:
  var parse: seq[ClParse]
  proc dirq(events={inMovedTo, inCloseWr}; wait=false; dir=".";
            cmdPrefix: seq[string]) = discard
  dispatchGen dirq, help={"events": "inotify event types to use",
                          "dir"   : "directory to watch",
                          "wait"  : "wait4(kid) until re-launch"},
              setByParse=addr parse, doc="""
chdir(*dir*) & wait for events to occur on it.  For each delivered event, run
*cmdPrefix* **NAME** where **NAME** is the filename (*NOT* full path) delivered.

Handleable events are:
  `access`    `attrib`  `modify`   `open`   `closeWrite` `closeNoWrite`
  `movedFrom` `movedTo` `moveSelf` `create` `delete`     `deleteSelf`

Default events `closeWrite` (any writable fd-close) | `movedTo` (renamed into
*dir*) usually signal that **NAME** is ready as an input file.

**dirq** can watch & dispatch for many dirs at once with repeated *--dir=A
cmdPfx for A --dir=B cmdPfx for A* patterns; *events* & *wait* are global."""
  dispatchdirq parseOnly=true
  if clHelpOnly in parse:
    stdout.write parse[parse.next({clHelpOnly})].message; quit 0
  for pe in parse:
    if pe.status notin [clOk, clPositional]: stderr.write pe.message,'\n';quit 1
  let eventsD = {inMovedTo, inCloseWr}; var events: set[Event]
  let waitD = false; var wait = waitD
  var dirs: seq[string]; var args: seq[seq[string]] # Folders & Initial args
  var a: ArgcvtParams
  for pe in parse:                              # Parses must all succeed since
    case pe.paramName                           #..all got clOk|Pos in 1st pass.
    of "wait"  : discard argParse(wait, waitD, a)
    of "events": # Need parseopt3 for fancy `sep`; Instead start {}, only add &
      a.key = "events"; a.sep = "="; a.val = pe.unparsedVal #..fallback to Defl.
      discard argParse(events, eventsD, a); echo "new events: ", events
    of "dir"   : dirs.add pe.unparsedVal
    else: # Above clOk check ensures clPositional here; Accumulate onto args[].
      if dirs.len == 0: dirs.add "."
      if args.len != dirs.len: args.add @[]
      args[^1].add pe.unparsedVal
  if events.card==0: events = eventsD           # End of verbose~manual CL-parse
  if not wait: signal(SIGCHLD, reapAnyKids)     # Block zombies
  var cmds = newSeq[cstringArray](dirs.len)     # Setup ready-to-exec buffer
  var ns   = newSeq[int](dirs.len)              # Indices of new last slots
  for arg in args.mitems: arg.add ""            # Pre-prepare CStringArray's
  for i, arg in args: ns[i] = arg.len - 1; cmds[i] = arg.allocCStringArray
  for (i, nmLen, name) in dqueues(events, dirs):
    if nmLen > 0 or name != nil:
      if chdir(dirs[i].cstring) == -1:
        raise newException(OSError, "chdir \"" & dirs[i] & "\"")
      cmds[i][ns[i]] = name                     # Poke ptr char into slot and..
      discard cmds[i].system(wait)              #..run command, maybe in bkgd
