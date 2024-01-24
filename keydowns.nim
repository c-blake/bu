when not declared(stdin): import std/syncio
proc keydowns(shift="~!@#$%^&*()_+|}{:\"?><", v=false): int =
  ## Return min key downs needed to enter all lines on stdin, optimizing SHIFTs.
  proc initSetChar(s: string): set[char] =
    for c in {'A'..'Z'}: result.incl c
    for c in s: result.incl c
  let shift = shift.initSetChar
  for str in stdin.lines:
    var down = false    # BETWEEN strs, SHIFT goes key up
    let r0 = result
    for c in str:
      if c in shift:    # Need shift
        if not down: down = true; inc result # Cnt key down
      else: down = false
      inc result
    if v: stderr.write result - r0, " ", str, "\n"

when isMainModule:
  import cligen; include cligen/mergeCfgEnv; dispatch keydowns, echoResult=true,
    help={"shift": "in addition to 'A'..'Z'", "v": "err log counts & strings"}
