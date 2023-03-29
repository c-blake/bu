import cligen/mslice, parseutils; export initSep
when not declared(File): import std/syncio

proc labFloats*(f: File, sep: Sep): (seq[string], seq[seq[float]]) =
  ## Read lines of a file separating into float|non-float and saving all floats
  ## but only the last textual context.
  var cols: seq[TextFrame]
  for line in lines(f):
    let ms = line.toMSlice
    let m = ms.frame(cols, sep)
    if (let dm = m - result[0].len; dm > 0):
      result[0].setLen m
      result[1].setLen m
    for j in 0..<m:
      result[0][j] = $cols[j].ms
      var f: float
      if (let n = parseFloat(result[0][j], f); n == result[0][j].len):
        result[1][j].add f

when isMainModule:
  let (labs, nums) = labFloats(stdin, initSep("white"))
  echo "labs: ", labs
  echo "nums: ", nums
