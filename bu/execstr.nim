when not declared(stderr): import std/syncio
import posix, parseutils, strformat, os; include cligen/unsafeAddr

type
  Kind = enum word, assign, iRedir, oRedir, fddup, bkgd, tooHard
  Param = tuple[a,b: int]                   # var assign '=' off|fd,mode|fd1,fd2
  Token = tuple[kind: Kind, param: Param, ue: string] # ue: un-escaped CL-arg

iterator tokens(cmd: string): Token =
  var esc, gT: bool         # escaping mode, just saw g)reaterT)han = false
  var t: Token
  template doYield(nextKind=word) =
    if t.kind == fddup:
      if t.param[0] == -1:
        stderr.write &"execStr char{i}: fd dup LHS non-int; RHS: \"{t.ue}\"\n"
      elif t.ue.len > 0 and parseInt(t.ue, t.param[1]) == t.ue.len:
        t.ue.setLen 0; yield t
      else:
        stderr.write &"execStr char{i}: fd dup RHS non-int: \"{t.ue}\"\n"
    elif t.ue.len > 0: yield t
    elif t.kind in {iRedir, oRedir}:        # These need a non-empty `ue`
      stderr.write &"execStr char{i}: no redirect path\n"
    t.param = (-1, 0); t.ue.setLen 0        # re-initialize token `t`
    t.kind = nextKind

  for i, c in cmd:
    case c
    of '\\':                                # Add escaped '\\'
      if esc: esc = false; t.ue.add c
      else  : esc = true                    # Or activate escape mode
    of ' ', '\t':
      if esc: esc = false; t.ue.add c                      # Add escaped space
      elif t.kind notin {iRedir, oRedir} and t.ue.len > 0: # if no arg expected
        doYield                                            # terminate token
    else:                                   # Non-backslash-white chars
      if esc: esc = false; t.ue.add c       # Just add escaped
      else:                                 # Unescaped char
        case c
        of '<': doYield iRedir              # -> Input Redirect
        of '=':                             # Assignment
          if t.ue.len>0 and t.kind != assign: # ..at least if LHS is non-empty.
            t.kind = assign                 #NOTE: libc putEnv takes 1st '=' as
            t.param[0] = t.ue.len           # ..the var name sep, but that was
          t.ue.add c                        # ..failing for me.  So, save spot.
        of '>':                             # [N]>[>]data | N>&M,"".
          if t.kind == iRedir:
            doYield oRedir; gT = true
          elif t.kind == oRedir and gT:     # ">>"; Activate append mode
            gT = false; t.param[1] = 1
          else:                             # First '>'
            gT = true
            if t.ue.len > 0:                # Convert optional N
              if t.kind != oRedir and parseInt(t.ue, t.param[0]) == t.ue.len:
                t.kind = oRedir             # Purely integral; "N>"
                t.ue.setLen 0
              else:                         # Not purely integral
                t.param[0] = -1             #   Reject parse; "prior>"
                doYield oRedir              #   Yield prior; next kind oRedir
            else: t.kind = oRedir           # Maybe empty before '>'
        of '&':                             # dup2 | background
          if gT: gT = false; t.kind = fddup # ">&" changes t.kind
          else: doYield bkgd; t.ue.add c    # parser must verify this is last
        of '\'', '"', '`', '(', ')', '{', '}', ';', '\n', '~', '|', '^', '#',
           '*', '?', '[', ']', '$':         # Could handle these one day
          t.kind = tooHard; yield t         # Too fancy for us! TODO $VAR expan
        else:                               # Unescaped char that needed
          t.ue.add c; gT = false            #..no escaping; just add.
    if i+1 == cmd.len: doYield              # EOString: yield any pending

var binsh = allocCStringArray(["/bin/sh", "-c", " "]) # Reuse 3-slot in fallback

proc execStr*(cmd: string): cint =
  ## Nano-shell: named like execv(2) since it replaces calling process with new
  ## program (client code forks/waits as needed).  Supported syntax: A) pre-cmd
  ## assigns { A=a B=b [exec] CMD .. } B) IO redirect { <, [N]>[>], N>&M } C) a
  ## final '&' background D) backslash escapes E) simple $VAR expansion.  This
  ## covers all 1-cmd needs BUT ${var}expands, globbing, & quoting. $= expands
  ## to "" for $VAR$=flushText purposes (like Zsh not Bash/Dash).  Unsupported
  ## syntax causes fall back to /bin/sh -c cmd { 4..20X slower }, but that is
  ## usually only needed for multi-cmds (pipelines, cmd subst, loops, etc.).
  if cmd.len == 0: return
  result = -1                               # If we ever return, it's a failure
  var preFork = false
  var i, bkgdAt: int
  var args: seq[string]
  template fallbackToSh() =                 # How to fall-back to /bin/sh when 
    let ccmd = cstring(cmd)                 #..given syntax is too hard.
    binsh[2] = cast[cstring](ccmd[0].unsafeAddr)
    if execvp("/bin/sh", binsh) != 0:
      stderr.write &"execvp: \"/bin/sh\": {strerror(errno)}\n"
    return      # Do not binsh.deallocCStringArray Retain ready-to-go status.
  for (kind, param, ue) in tokens(cmd):
    i.inc
    case kind
    of assign:  # Weirdly c_putenv(ue) exports in gdb system() but not our exec
      if args.len == 0: putEnv(ue[0..<param[0]], ue[param[0]+1..^1])
      else: args.add ue
    of word: args.add ue
    of iRedir:
      if close(0) != 0:
        stderr.write &"close(0): {strerror(errno)}; Canceled Redirect\n"
        continue
      if open(ue.cstring, O_RDONLY) == -1:
        stderr.write &"open: \"{ue}\": {strerror(errno)}; Using /dev/null\n"
        if open("/dev/null", O_RDONLY) == -1:
          stderr.write &"open: \"{ue}\": {strerror(errno)}\n"
    of oRedir:
      let (fd, mode) = param
      let flags = if mode == 0: O_WRONLY or O_CREAT or O_TRUNC
                  else: O_WRONLY or O_CREAT or O_APPEND
      let fr = if fd == -1: 1.cint else: fd.cint
      if close(fr) != 0:
        stderr.write &"close({fd}): {strerror(errno)}; Canceled Redirect\n"
        continue
      let ofd = open(ue.cstring, flags, 0o666)
      if ofd == -1:
        stderr.write &"open(\"{ue}\"): {strerror(errno)}\n"
      elif ofd != fr and dup2(ofd, fr) == -1:
        stderr.write &"dup2({ofd}, {fr}): {strerror(errno)}\n"
    of fddup:
      if dup2(param[0].cint, param[1].cint) == -1:
        stderr.write &"dup2({param[0]}, {param[1]}): {strerror(errno)}\n"
    of bkgd:
      if not preFork:
        bkgdAt = i; preFork = true
    of tooHard: fallbackToSh
  if preFork and bkgdAt != i: fallbackToSh # token after 1st unesc/non-fddup'&'
  if args.len > 0 and args[0] == "exec":
    args.delete 0
  let prog = if args.len > 0: args[0] else: ""
  let argv = allocCStringArray(args)
  template execvpOrMsg() =
    if execvp(prog.cstring, argv) != 0:
      stderr.write &"execvp: \"{prog}\": {strerror(errno)}\n"
  if preFork:                           # background requested =>
    if vfork() == 0: execvpOrMsg        #   parent exits immediately
  else: execvpOrMsg
  argv.deallocCStringArray # execvp fail; Dealloc argv BUT likely about to die

when isMainModule:                      # This is for testing against syntax
  for token in tokens(paramStr(1)): echo token
## Overhead benchmarking is easy (replace 0->1,true->false for prog fail path):
## $ echo 'int main(int ac,char**av){return 0;}' > /tmp/true.c
## $ musl-gcc -static -Os /tmp/true.c -o /tmp/true && rm /tmp/true.c
## $ (for i in {1..32767}; do echo /tmp/true; done) > /tmp/in
## $ time stripe 1 < /tmp/in                    # This routine
## $ (for i in {1..32767}; do echo \"/tmp/true\"; done) > /tmp/inSh
## $ time stripe 1 < /tmp/inSh                  # /bin/sh (-> dash for me)
## $ time stripe -r/bin/bash 1 < /tmp/inSh      # bash instead
## On Linux, env.vars & argv slots both add around 150 ns / item to execvp time
## (on a 4.7GHz i6700k).  `env -i` can eliminate/measure some of that.
#[ 2.9.1 Simple Commands; NOTE: shell out to anything *with no resulting cmd*.
A "simple command" is a sequence of optional variable assignments and IO
redirects, in any order, optionally followed by words and redirections,
terminated by a control operator.  The following expansions, assignments, and
redirections are performed from the beginning of the command text to the end:
 1. The words that are recognized as variable assignments or redirections
    according to Shell Grammar Rules are saved for processing in steps 3 and 4.
 2. Words that are not variable assignments or redirections are expanded.
    If any fields remain following their expansion, the first field is the
    command name and remaining fields are the arguments for the command.
 3. Redirections shall be performed as described in Redirection.
 4. Each variable assignment is expanded for parameter expansion.
Variable assignments are exported for the execution environment of the command
but do not affect the current execution environment. If variable assignment
attempts to assign a value to a read-only variable, a variable assignment error
shall occur.  See Consequences of Shell Errors for the consequences of these
errors. ]#
