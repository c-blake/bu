when not declared(stderr): import std/syncio
import std/cmdline {.all.} # cmdCount, cmdLine
from std/strutils   import strip
from std/parseutils import parseInt
from std/sugar      import collect

# Wrap a command to emit last non-option arg
const use = "(n)on-(o)ption (a)rgument usage:\n\n" &
  "  noa {index} options-and-args\n\n" &
  "E.g.: noa -1 cp -a foo -f -- /exists/maybe/missing\n" &
  "emits \"/exists/maybe/missing\" no matter where \"--\" is.\n" &
  "Can be nice in scripts to e.g. ensure must-haves exist."

iterator nonOpts(): int =               # Any alternative to Unix -- convention?
  var optsDone = false
  for i in 2 ..< cmdCount:              # skip $0 = noa and $1 = idx .. BUT
    if optsDone: yield i                #..yield unadjusted `cmdLine` indices.
    else:
      let a = cmdLine[i]                #NOTE: All OSes terminate with \0
      if a[0] == '-':                   # Some kind of option | end of options
        if a[1] == '-' and a[2] == '\0':# "--": end of options
          optsDone = true
      else: yield i

if cmdCount < 3: quit use, 1            # Use cmdCount,Line not paramCount,Str..
let dlr1 = $cmdLine[1]                  #..to avoid string creation w/giant argv
if dlr1 in ["-h", "--help"]: echo use; quit 0

var ix: int
let bare = dlr1.strip
if bare.len == 0 or parseInt(bare, ix) != bare.len:
  quit "\"" & bare & "\"" & " is not an integer.\n\n" & use, 2

if ix < 0:
  let ixes = collect(for i in nonOpts(): i)
  let ix = ixes.len + ix
  if ix >= 0 and ix < ixes.len: echo cmdLine[ixes[ix]]
  else: quit "noa index " & bare & " out of bounds\n\n" & use, 3
else:
  var ixCt = ix
  for i in nonOpts():
    if ixCt == 0: echo cmdLine[i]; quit 0
    dec ixCt
  quit "noa index " & bare & " out of bounds\n\n" & use, 3
