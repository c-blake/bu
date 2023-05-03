when not declared(stderr): import std/syncio
import std/sugar, cligen, cligen/[strUt, mslice, mfile, osUt]

const nq = {'\t', '\n', ' ', '!', '"', '#', '$', '&' , '\'', '(', ')',
            '*', ';', '<', '=', '>', '?', '?', '[', '`' , '{', '|', '~'}

var hunks: seq[MSlice]
proc sQuote(f: File, s: MSlice) =       # If a starts or ends with ' this can..
  putchar '\''                          #..save an empty string ('') catenation
  discard s.msplit(hunks, '\'', 0)
  for i, hunk in hunks:
    f.urite hunk
    if i != 0: f.urite "'\\''"
  putchar '\''

proc escape(f: File, s: MSlice) =       # This just escapes every char
  for c in s:
    putchar '\\'; putchar c

proc interPrint(tmpl: string, prs: seq[MacroCall]; stub: MSlice) =
  for (id, arg, call) in prs:
    if id == 0..0: stdout.urite tmpl, arg
    elif tmpl[id.a] == 's': stdout.urite stub
    elif tmpl[id.a] == 'n':
      if nq in stub: stdout.sQuote stub else: stdout.urite stub
    elif tmpl[id.a] == 'q': stdout.sQuote stub
    elif tmpl[id.a] == 'e': stdout.escape stub
    else: stdout.urite tmpl, call

proc tmpls(file="/dev/stdin", nl='\n', term='\n', meta='%',
           templates: seq[string]): int =
  ## Interpolate { %s)tring | %n)eed quoted | always %q)uoted | %e)scaped } into
  ## as many templates as given, writing back-to-back template-filled-in batches
  ## to stdout, with each individual template terminated by `term`.  E.g.:
  ##   ``find . -name '\*.c' -print|sed 's/.c$//' | tmpls %s.c %s.o %n.c %e.o``
  if templates.len < 1:
    raise newException(HelpError, "Need some template; Full ${HELP}")
  let prs = collect(for t in templates: t.tmplParsed(meta))
  for ms in mSlices(file, sep=nl, eat='\0'):
    for i in 0 ..< templates.len:
      interPrint templates[i], prs[i], ms
      putchar term

when isMainModule:
  dispatch tmpls, help={"templates": "templates...",
    "file" : "input file of name stubs",
    "nl"   : "input string terminator",
    "term" : "output string terminator",
    "meta" : "self-quoting meta for %sub"}
