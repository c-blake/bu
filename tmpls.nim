when not declared(stderr): import std/syncio
import std/sugar, cligen, cligen/[strUt, mslice, mfile, osUt], bu/esquo

proc interPrint(f: File; tmpl: string, prs: seq[MacroCall]; str: SomeString) =
  for (id, arg, call) in prs:
    if id == 0..0: f.urite tmpl, arg
    elif tmpl[id.a] == 's': f.urite str
    elif tmpl[id.a] == 'n': (if needQuo in str: f.sQuote str else: f.urite str)
    elif tmpl[id.a] == 'q': f.sQuote str
    elif tmpl[id.a] == 'e': f.escape str
    else: f.urite tmpl, call

proc tmpls(inp="/dev/stdin", nl='\n', outp="/dev/stdout", term='\n', meta='%',
           templates: seq[string]): int =
  ## Interpolate { %s)tring | %n)eed quoted | always %q)uoted | %e)scaped } into
  ## as many templates as given, writing back-to-back template-filled-in batches
  ## to stdout, with each individual template terminated by `term`.  E.g.:
  ##   ``find . -name '\*.c' -print|sed 's/.c$//' | tmpls %s.c %s.o %n.c %e.o``
  if templates.len < 1:
    raise newException(HelpError, "Need some template; Full ${HELP}")
  let prs = collect(for t in templates: t.tmplParsed(meta))
  let f = try: (if outp == "/dev/stdout": stdout else: open(outp, fmWrite))
          except: quit "could not open output: " & outp, 1
  for ms in mSlices(inp, sep=nl, eat='\0'):
    for i in 0 ..< templates.len:
      f.interPrint templates[i], prs[i], ms
      putchar term

when isMainModule:
  dispatch tmpls, help={"templates": "templates...",
    "inp"  : "input file of name 'stubs'",
    "nl"   : "input string terminator",
    "outp" : "output file of expansions",
    "term" : "output string terminator",
    "meta" : "self-quoting meta for %sub"}
