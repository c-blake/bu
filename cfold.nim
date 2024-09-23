import std/re, cligen
when not declared(lines): import std/syncio

iterator csplit(s: string, pat: Regex): tuple[body: string, sep: string] =
  ## Iterate over segments of a string split by a pattern, yielding (body,sep)
  ## tuples.  This correctly handles cases where the string does or does not end
  ## in a sep and where all bodies are empty strings.
  var a, b: int
  var beg = 0
  while true:
    (a, b) = findBounds(s, pat, start = beg)  #s[a..b] if found else (-1,0)
    if a == -1:
      break
    yield (s[beg .. a-1], s[a .. b])
    beg = b + 1
  if beg < s.len:
    yield (s[beg..^1], "")

proc cfold(suppress=false, ignore=false, extended=false, file="-",
           pattern: seq[string]) =
  ## `cfold` is to `fold` as `csplit`(1) is to `split`(1).  ``pattern`` is an rx
  ## at which to segment input lines in `file`.  This can also be done with GNU
  ## sed, but ergonomics of getting \\n into expressions are poor.
  var flags = {reStudy}
  if ignore: flags.incl reIgnoreCase
  if extended: flags.incl reExtended
  if pattern.len != 1:
    raise newException(HelpError, "Need exactly one pattern; Full ${HELP}")
  let pat = re(pattern[0], flags)
  for line in lines(if file != "-": open(file) else: stdin):
    for segment in csplit(line, pat):
      stdout.write(segment.body)
      if not suppress:
        stdout.write(segment.sep)
      stdout.write("\n")

dispatch cfold, help={"file"    : "input file (\"-\" == stdin)",
                      "ignore"  : "add ignore case to re flags",
                      "extended": "nim re 'extended' syntax",
                      "suppress": "exclude matched strings"}
