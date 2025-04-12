when not declared(stdin): import std/syncio
include cligen/unsafeAddr
import cligen/[sysUt, osUt], std/re, cligen # cligen is early for `HelpError`

proc unfold(sep="\t", n=0, before="", after="", ignore=false, extended=false) =
  ## Join blocks of stdin lines into one line sent to stdout.
  var eolBuf = "\n"; let eol = eolBuf[0].addr
  let nS = sep.len; let sep = sep[0].unsafeAddr
  var i = 0
  var need = false
  var str: string
  var flags = {reStudy}
  if ignore: flags.incl reIgnoreCase
  if extended: flags.incl reExtended
  template wrLine =
    if stdout.uriteBuffer(ln, nLn-1) != nLn-1: return
  template wrEOL =
    if stdout.uriteBuffer(eol, 1) != 1: return else: need = false
  template wrSep =
    if stdout.uriteBuffer(sep,nS) != nS: return else: need = true
  if n > 0 and before.len == 0 and after.len == 0:
    for (ln, nLn) in stdin.getDelims:   # :( My ancient rec_rdln is ~1.3x faster
      inc i
      wrLine()                          # Always output the input
      if i == n: wrEOL(); i = 0         # but EOL only after n cycles
      else     : wrSep()                # otherwise just sep
  elif after.len != 0 and n == 0 and before.len == 0:
    let rx = re(after, flags)
    for (ln, nLn) in stdin.getDelims:
      inc i
      wrLine()                          # Always output the input
      str.setLen nLn-1; copyMem str[0].addr, ln, nLn-1
      if rx in str: wrEOL()             # but EOL only only if line matches
      else        : wrSep()             # otherwise just sep
  elif before.len != 0 and n == 0 and after.len == 0:
    let rx = re(before, flags)          # A somewhat different state machine
    for (ln, nLn) in stdin.getDelims:
      inc i
      if i == 1:
        wrLine(); need = true           # Write 1st line unconditionally
      else:                             # Copy `ln` to `str` for pattern match
        str.setLen nLn-1; copyMem str[0].addr, ln, nLn-1
        if rx in str: wrEOL()           # Then terminate only if line matches
        else        : wrSep()           # otherwise just sep
        wrLine()                        # Then output the input
  else: Help !! "Set `n` | `before` | `after`; Full $HELP"
  if need: wrEOL()      # May need final \n (non-delimiting sep gives user clue)

include cligen/mergeCfgEnv; dispatch unfold, help={
  "n"       : "Join `|n|` lines into 1",
  "after"   : "join blocks ending with a matching line",
  "before"  : "join blocks beginning with a matching line",
  "sep"     : "separates the old lines within the new",
  "ignore"  : "regex are case-insensitive",
  "extended": "regexes are nim re 'extended' syntax",
}
