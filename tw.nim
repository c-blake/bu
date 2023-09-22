when not declared(stdin): import std/syncio
from std/terminal import terminalWidth, isatty
from std/cmdline  import paramCount, paramStr
from std/strutils import parseInt
from cligen/osUt  import getDelims, putchar # ~1.65x fasterThan std.lines for me
template put(c) = putchar(c)

proc contin(b: char; uc: var int32): int = # Continuation bytes after `b`
  if   b.uint <= 127          : result = 0; uc = (b).int32
  elif b.uint shr 5 == 0b110  : result = 1; uc = (b.int32 and 0b11111)
  elif b.uint shr 4 == 0b1110 : result = 2; uc = (b.int32 and 0b1111)
  elif b.uint shr 3 == 0b11110: result = 3; uc = (b.int32 and 0b111)
  else: result = 0; uc = 0

proc isCombining(uc: int32): bool = uc >= 0x0300 and (uc <= 0x036f or
  (uc >= 0x1ab0 and uc <= 0x1aff) or (uc >= 0x1dc0 and uc <= 0x1dff) or
  (uc >= 0x20d0 and uc <= 0x20ff) or (uc >= 0xfe20 and uc <= 0xfe2f))

type ParseState = enum start, rune, esc, csi, osc  # Loop-to-loop Parse State
const ST = '\\'
proc putClipped(line: cstring; n, w: int) =
  var ps: ParseState; var r,con,ix: int # ParseState,Rendered width,rune(Con&Ix)
  var did=false; var uc=0i32            # Flag & unicode character
  var bs: array[4, char]
  for i in 0 ..< n:                     # Input byte Index
    if did: did = false                 # String Terminator Esc-\ needs a peek
    else:
      let b = line[i] # NOTE: State machines fitting on one screen read easier.
      case ps         # Idea is to just stop cursor advances after w char cells.
      of start:                         # Special ASCII, then utf8, then emit
        if   b == '\e' : ps = esc;put b # Enter Esc-Seq mode
        elif b == '\b' : dec r; put b   # backspace rewinds 1
        elif b == '\r' : r = 0; put b   # carriage-return rewinds all
        elif b == '\t' : r = ((r + 8) div 8)*8; (if r < w: put b) # ${3:-8}?
        elif ord(b)<32 : put b          # For me \v only lineFeeds, not moving r
        elif ord(b)>127: ps = rune; con = contin(b, uc); ix = 0; bs[0] = b
        elif r < w: inc r; put b
        else: inc r                     # Advancing blocks combiners post r==w
      of rune:                          # Does not handle Double-Wide Unicode,
        inc ix                          #..or grapheme extensions or similar.
        if ix <= con:                   # Accumulate rune / unicode character
          bs[ix] = b; uc = (uc shl 6) or (b.int32 and 0b111111)
        if ix == con:
          ps = start                    # Unicode char assembled: maybe emit
          if r < w or (r == w and uc.isCombining):
            if   con==1: put bs[0]; put bs[1]
            elif con==2: put bs[0]; put bs[1]; put bs[2]
            elif con==3: put bs[0]; put bs[1]; put bs[2]; put bs[3]
          if not uc.isCombining: inc r
      of esc:                           # Assume no other escSeq & 0 advance.
        if   b == '[': ps = csi; put b  #..This is inexact since several vtXXX
        elif b == ']': ps = osc; put b  #..codes can reset/move cursors, BUT we
        else: ps = start; put b         #..cannot be a full TEmulator *though*
      of csi:                           #..TEms COULD have a "no wrap" mode.
        if ord(b) in 0x40..0x7E: ps = start
        put b
      of osc:
        if   b == '\a': ps = start
        elif b == '\e' and i<n-1 and line[i+1]==ST: ps = start; put ST; did=true
        put b

proc main =
  if stdin.isatty:
    quit """Print input data lines clipped to ${1:-"1"} rows of Terminal Width.
Optional $2 overrides $COLUMNS | OS-perceived terminal width. Eg.: pd -w|tw 2"""
  let m = if paramCount() >= 1: parseInt(paramStr(1)) else: 1
  let w = m*(if paramCount() >= 2: parseInt(paramStr(2)) else: terminalWidth())
  for (line, n) in stdin.getDelims:
    putClipped line, n - 1, w; put '\n'
main()
