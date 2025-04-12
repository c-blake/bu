when not declared(stderr): import std/syncio
import std/strutils, cligen/[sysUt, strUt, mslice, osUt]

type EsQuo* = enum eqNeed, eqAlways, eqEscape ## Quoting mode enum

proc esQuoParse*(q: string): EsQuo =
  ## Parse a quoting mode string into its enum or raise `ValueError`.
  case (if q.len > 0: q[0].toLowerAscii else: 'X')
  of 'n': result = eqNeed
  of 'q': result = eqAlways
  of 'e': result = eqEscape
  else: Value !! "Unknown quote mode: \"" & q & "\"."

const needQuo* = {'\t', '\n', ' ', '!', '"', '#', '$', '&' , '\'', '(', ')',
                  '*', ';', '<', '=', '>', '?', '?', '[', '`' , '{', '|', '~'}

# Can save empty string ('') catenation if you can *know* starts|ends with '
var quoHunks: seq[MSlice]
proc sQuote*(f: File, s: SomeString; hunks: var seq[MSlice] = quoHunks) =
  ## Shell Single-Quoter.  `hunks` is just for MT-safety if you need that.
  f.urite '\''
  discard s.msplit(hunks, '\'', 0)
  for i, hunk in hunks:
    f.urite hunk
    if i != 0: f.urite "'\\''"
  f.urite '\''

proc escape*(f: File, s: SomeString, esc='\\', need={'\0'..'\x7F'}) =
  ## Escape every byte with `esc`.  Not very unicode-friendly.
  for c in s:
    if c in need: f.urite esc
    f.urite c

proc emit*(f: File, s: SomeString, qmode=eqNeed, esc='\\') =
  ## Emit `s` to `f`, quoting or escaping as specified.
  case qmode
  of eqNeed: (if needQuo in s: stdout.sQuote s else: stdout.urite s)
  of eqAlways: stdout.sQuote s
  of eqEscape: stdout.escape s
