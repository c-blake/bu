when not declared(stderr): import std/syncio
import posix, parseutils, strformat, os; include cligen/unsafeAddr
template er(s) =
  let e {.inject,used.} = errno.strerror;stderr.write "execStr: ", s, '\n'

type
  Kind = enum word, assign, iDir, oDir, tooHard
  Param = tuple[a,b: int]                   # var assign '=' off|fd,mode|fd1,fd2
  Token = tuple[kind: Kind, param: Param, ue: string] # ue: un-escaped CL-arg

iterator tokens(cmd: string): Token =
  var esc, gT, aw: bool   # Escape mode, just saw g)reaterT)han, a)mong words
  var t: Token
  template doYield(nextKind=word) =
    if t.ue.len > 0:
      if t.kind == word: aw = true
      yield t
    elif t.kind in {iDir, oDir}: er &"char{i}: no redirect path"
    t.param = (-1, 0); t.ue.setLen 0        # re-initialize token `t`
    t.kind = nextKind

  for i, c in cmd:
    case c
    of '\\':
      if esc: esc = false; t.ue.add c       # Add escaped '\\'
      else  : esc = true                    # Or activate escape mode
    of ' ', '\t':                           # Add escaped spcTAB|maybe end token
      if esc: esc = false; t.ue.add c
      elif t.ue.len > 0: doYield
    else:                                   # A non-backslash|white char
      if esc: esc = false; t.ue.add c       # Just add if in escape mode
      else:                                 # Unescaped char
        case c
        of '<': doYield iDir                # -> Input Redirect
        of '=':                             # Assignment if LHS is non-empty
          if not aw and t.ue.len>0 and t.kind != assign:
            t.kind = assign; t.param[0] = t.ue.len
          t.ue.add c                        # BUG: Can put esc '=' in a varNm
        of '>':                             # [N]>[>]data | N>&M,"".
          if gT: gT = false; t.param[1] = 1 # ">>"; Activate append mode
          else:                             # First UnEsc '>'
            gT = true
            if t.ue.len > 0:                # Convert optional N
              if parseInt(t.ue, t.param[0]) == t.ue.len:
                t.kind = oDir;t.ue.setLen 0 # Purely integral; "N>"
              else:                         # Not purely integral; end last tok
                t.param[0] = -1             #   Reject parse; "prior>"
                doYield oDir                #   Yield prior; next kind oDir
            else: t.kind = oDir             # Maybe empty before '>'
            continue                        # skip gT = false @EOLoop
        of '\'', '"', '`', '(', ')', '{', '}', ';', '\n', '~', '|', '^', '#',
           '*', '?', '[', ']', '$', '&':    # Could handle these one day
          t.kind = tooHard; yield t         # Too fancy for us! TODO $VAR expan
        else:                               # Unescaped char that needed
          t.ue.add c; gT = false            #..no escaping; just add.
        gT = false
    if i+1 == cmd.len: doYield              # EOString: yield any pending

var sh = allocCStringArray(["/bin/sh", "-c", " "]) # Reuse 3-slot in fallback

proc execStr*(cmd: string): cint =
  ## Nano-shell: named like execv(2) since it replaces calling process with new
  ## program (client code forks/waits as needed).  Supported syntax: A) pre-CMD
  ## assigns { A=a B=b [exec] CMD .. } B) IO redirect { <, [N]>[>] } C) \-escape
  ## D) simple $VAR expands.  Covers most non-pipeline/logic needs EXCEPT fancy
  ## ${var}expands, quoting, globbing.  Unsupported syntax causes fall back to
  ## /bin/sh -c cmd { 4..20X slower }.
  result = -1                                   # A failure if we ever return
  if cmd.len == 0: return
  var toks: seq[Token]
  for tok in tokens(cmd):
    if tok.kind == tooHard:                     # Fall-back when used..
      sh[2] = cast[cstring](cmd[0].unsafeAddr)  #..cmd is too complex.
      if execvp("/bin/sh", sh) != 0: er &"exec: \"/bin/sh\": {e}"
      return    # Do not sh.deallocCStringArray; Retain ready-to-go status.
    toks.add tok
  var args: seq[string]
  for (kind, param, ue) in toks:
    case kind
    of assign:  # Weirdly c_putenv(ue) exports in gdb system() but not our exec
      if args.len == 0: putEnv(ue[0..<param[0]], ue[param[0]+1..^1])
      else: args.add ue
    of word: args.add ue
    of iDir:
      if close(0) != 0: er &"close(0): {e}; Canceled Redirect"; continue
      if open(ue.cstring, O_RDONLY) == -1:
        er &"open: \"{ue}\": {e}; Using /dev/null"
        if open("/dev/null", O_RDONLY) == -1: er &"open: \"{ue}\": {e}"
    of oDir:
      let (fd, mode) = param
      let flags = O_WRONLY or O_CREAT or (if mode == 0: O_TRUNC else: O_APPEND)
      let fr = if fd == -1: 1.cint else: fd.cint
      if close(fr) != 0: er &"close({fd}): {e}"; continue
      let ofd = open(ue.cstring, flags, 0o666)
      if ofd == -1: er &"open(\"{ue}\"): {e}"
      elif ofd != fr and dup2(ofd, fr) == -1: er &"dup2({ofd}, {fr}): {e}"
    else: discard
  if args.len > 0 and args[0] == "exec":   # Q: support PATH "exec" via \exec?
    args.delete 0
  let prog = if args.len > 0: args[0] else: ""
  let argv = allocCStringArray(args)
  if execvp(prog.cstring, argv) != 0: er &"exec: \"{prog}\": {e}"
  argv.deallocCStringArray # execvp fail; Dealloc argv BUT likely about to die

when isMainModule:                      # This is for testing against syntax
  for token in tokens(paramStr(1)): echo token
#[ Some correctness tests for to give this file compiled as a program:
 'a=b=c x\=y=z cmd n m i=j\ k<in>out 2>err 3>>log< in2 > out2 2> err2 3>> log2'
Overhead benchmarking is easy (replace 0->1, true->false for prog fail path):
  echo 'int main(int ac,char**av){return 0;}' > /tmp/true.c
  musl-gcc -static -Os /tmp/true.c -o /tmp/true && rm /tmp/true.c
  (for i in {1..32767}; do echo /tmp/true; done) > /tmp/in
  time stripe 1 < /tmp/in                    # This routine
  (for i in {1..32767}; do echo \"/tmp/true\"; done) > /tmp/inSh
  time stripe 1 < /tmp/inSh                  # /bin/sh (-> dash for me)
  time stripe -r/bin/bash 1 < /tmp/inSh      # bash instead
On Linux-i6700k, env -i can show vars&argv slots each add 135-150ns to execvp.
Ref 2.9.1 Simple Commands; NOTE: shell out to anything *with no resulting cmd*.
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
