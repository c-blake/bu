import std/terminal, cligen, cligen/mfile, nio

proc widths(outKind='\0', distro=false, paths: seq[string]) =
  ## Emit width/line lengths in bytes of all lines in files `paths`.
  ##
  ## If `histo` emit an exact histogram of such widths.
  ##
  ## Emits text if `outKind==NUL`, else binary in that NIO format.

  if outKind != '\0' and stdout.isatty:
    raise newException(HelpError, "stdout is a terminal; Full ${HELP}")
  let kout = try: kindOf(outKind) except CatchableError: 0.IOKind
  var obuf: array[16, char]
  var cnts: seq[int]
  var mf: MFile
  for path in paths:
    for ms in mSlices(path, mf=mf):
      if distro:
        if ms.len + 1 > cnts.len: cnts.setLen ms.len + 1
        inc cnts[ms.len]
      elif outKind == '\0':
        echo ms.len
      else:             # Convert & then emit line len as `kout`
        var n = ms.len
        convert kout, lIk, obuf[0].addr, n.addr
        stdout.nurite kout, obuf[0].addr
    mf.close
  if distro:
    for i, c in cnts:
      if c != 0: echo i, " ", c

when isMainModule: dispatch widths, help={
  "distro" : "emit a histogram, not individual widths",
  "outKind": "emit binary stream with this NIO format"}
