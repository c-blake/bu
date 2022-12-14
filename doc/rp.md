Motivation
----------

Many people hate boilerplate.  Sometimes they create whole new DSLs/prog.langs
to avoid it.  While not invalid, generating from a template and automatically
compiling or otherwise processing the expansion is also valid and about 100X
easier { in units of highly objective effort-ons ;-) }.  It may also need less
language learning for users & allow easier access to 3rd party libs.

Part of the culture of Nim is to be sufficiently general purpose/nice enough to
use the language everywhere - as its own macro language, for compiler config via
NimScript .nims files, etc.  But command prompts are still a thing.  Sometimes
you want to easily just run some calculation on some data in a file.  Applying
the insight of the first paragraph, we get something like `rp` in < 100 LoC,
with an extra named field extension even.

The `rp --help` usage message (slightly reformatted) covers the basics.

Usage
-----
```
  rp [optional-params] Nim stmts to run (guarded by `where`); none => echo row

Gen & Run prelude,fields,begin,where,stmts,epilog row processor against input.

Defined within where & every stmt are:
  s[fieldIdx] & row give MSlice ($ to get a Nim string)
  fieldIdx.i gives a Nim int, fieldIdx.f a Nim float.
  nf & nr (like AWK);  NOTE: fieldIdx is 0-origin.

A generated program is left at outp.nim, easily copied for "utilitizing".  If
you know AWK & Nim, you can learn rp FAST.

Examples (most need data):

  seq 0 1000000 | rp -w'row.len<2'            # Print short rows
  rp 'echo s[1]," ",s[0]'                     # Swap field order
  rp -b'var t=0' t+=nf -e'echo t'             # Print total field count
  rp -b'var t=0' -w'0.i>0' t+=0.i -e'echo t'  # Total >0 field0 ints
  rp -p'import stats' -b'var r: RunningStat' 'r.push 0.f' -e'echo r'
  rp 'let x=0.f' 'echo (1+x)/x'               # cache field 0 parse
  rp -d, -fa,b,c 'echo s[a],b.f+c.i.float'    # named fields (CSV)

Add niceties (eg. import lenientops) to prelude in ~/.config/rp.

Options:
  -p=, --prelude=  string ""           Nim code for prelude/imports section
  -b=, --begin=    string ""           Nim code for begin/pre-loop section
  -w=, --where=    string "true"       Nim code for row inclusion
  -e=, --epilog=   string ""           Nim code for epilog/end loop section
  -f=, --fields=   string ""           delim-sep field names (match row0)
  -g=, --genF=     string "$1"         make field names from this fmt; eg c$1
  -n=, --nim=      string "nim"        path to a nim compiler (>=v1.4)
  -r, --run        bool   true         Run at once using nim r .. < input
  -a=, --args=     string ""           "": -d:danger; '+' prefix appends
  -c=, --cache=    string ""           "": --nimcache:/tmp/rp (--incr:on?)
  -v=, --verbose=  int    0            Nim compile verbosity level
  -o=, --outp=     string "/tmp/rpXXX" output executable; .nim NOT REMOVED
  -s, --src        bool   false        show generated Nim source on stderr
  -i=, --input=    string "/dev/stdin" path to mmap|read as input
  -d=, --delim=    string "white"      inp delim chars; Any repeats => fold
  -u, --uncheck    bool   false        do not check&skip header row vs fields
  -m=, --maxSplit= int    0            max split; 0 => unbounded
  -W=, --Warn=     string ""           "": --warning[CannotOpenFile]=off
```

Future/User Work
----------------

There are easy ideas to round out functionality whose value depends upon your
use case.  It may be nice to automatically open files like `print 1 > "myPath"`
does in `awk`, for example, with:
```Nim
var awTab: Table[string, File]  # Auto-Write-file table
proc aw(fnm: string): File =
  try: awTab[fnm] except: (let f = open(fnm, fmReadWrite); awTab[fnm] = f; f)
```
Then you can just say `"myPath".aw.write "1\n"` in per input row action clauses.
This is barely any more key-stroking (.aw is only 2 more chars than '>').  You
can write a tiny library of such things - say, `ar` for `fmRead`, `aa` for
`fmAppend`, a similar `rx` automatic reg.expr compile-once but match-many, etc.
About all that is lost via this approach is fast interpreter start-up time and
*automatic* lifting of `Table` lookups into variables.  You can always put such
bindings in `--begin` code manually if per input row `Table` lookup actually
hurts performance.

Some `--path` tweaks, a `-p"import such"` maybe in your `~/.config/rp`, and you
can cover almost any awk use case with a fully strongly type-checked, compilable
prog.lang with terse but general syntax.  You can also use this as a prototyping
environment, copying generated code away from `/tmp/rp\*.nim` to be the basis
for new, standalone programs (yes, with `cligen/[mfile,mslice]`-dependency as
currently written).

Related Discussion
------------------

Some more discussion is here:

    https://news.ycombinator.com/item?id=30190436

which inspired Ben to write an article here

    https://benhoyt.com/writings/prig/

discussed (at least) here

    https://news.ycombinator.com/item?id=30498735

Not all prog.langs have both easy to enter/terse expressions and fast compiles.
For a comparison point, see `crp.md`/`crp.nim` in this repo which uses C for the
base-code language.
