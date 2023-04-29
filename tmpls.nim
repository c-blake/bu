when not declared(stderr): import std/syncio
import std/sugar, cligen, cligen/[strUt, mslice, mfile, osUt]

proc interPrint(tmpl: string, prs: seq[MacroCall]; stub: MSlice) =
  for (id, arg, call) in prs:
    if id == 0..0: stdout.urite tmpl, arg
    elif tmpl[id.a] == 's': stdout.urite stub
    else: stdout.urite tmpl, call

proc tmpls(file="/dev/stdin", nl='\n', term='\n', meta='%',
           templates: seq[string]): int =
  ## This program interpolates %s into as many templates as given, writing
  ## back-to-back template-filled-in batches to stdout, with each individual
  ## template terminated by `term` and single-quoted.  E.g.:
  ##   ``find . -name '\*.c' -print | sed 's/.c$//' | tmpls %s.c %s.o``
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
