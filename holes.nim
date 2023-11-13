import std/[posix, strutils]
when not declared(File): import std/syncio

iterator holes*(fd: cint): (bool, int) =
  const SEEK_DATA = cint(3)
  const SEEK_HOLE = cint(4)
  const what = [SEEK_HOLE, SEEK_DATA]
  let eof  = lseek(fd, 0, SEEK_END)
  var pos  = lseek(fd, 0, SEEK_HOLE)
  var hole = pos == 0
  if pos > 0:
    yield (hole, pos)
  errno = 0.cint        # Clear any earlier ENXIO's
  while pos < eof and errno != ENXIO:
    if (let new = lseek(fd, pos, what[hole.int]); new != -1):
      if new - pos > 0:
        yield (hole, new - pos)
      pos  = new
      hole = not hole
  if eof - pos > 0:
    yield (hole, eof - pos)

proc sholes(format="", files: seq[string]) =
  ## Show hole & data segments for `files`
  const name = ["data", "hole"]
  let format = if format.len != 0: format else: "$count $path\n$map"
  let needMap  = "$map"  in format or "${map}"  in format
  let userTerm = "$zero" in format or "${zero}" in format
  var m: string
  for file in files:
    if (let fd = open(file.cstring, O_RDONLY); fd >= 0):
      m.setLen 0
      var n = 0
      for (hole, size) in fd.holes:
        inc n
        if needMap:
          m.add '\t'; m.add name[hole.int]
          m.add '\t'; m.add $size
          m.add '\n'
      discard fd.close  # Can fail on netFSes; No recovery really possible
      stdout.write format % ["count",$n, "path",file, "map",m, "nul","\0"]
      if not userTerm and not needMap:
        stdout.write '\n'

when isMainModule: import cligen; dispatch sholes, cmdName="holes", help={
  "format": """emit format interpolating:
  $count : number of data|hole segments
  $path  : path name of REGULAR FILE from $\*
  $map   : map of all data&hole segments
  $nul   : a NUL byte
\"\" => \"$count\\t$path\\n$holes\\n\""""}
