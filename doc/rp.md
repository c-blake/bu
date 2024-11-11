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
you want to easily just compute over some data in a file.  Applying insights of
the first paragraph, we get something like `rp` in ~ 100 non-blank non-comment
LoC (with an extra auto-from-CSV headers named field extension!).

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
  rp -vt=0 t+=nf -e'echo t'                   # Print total field count
  rp -vt=0 -w'0.i>0' t+=0.i -e'echo t'        # Total >0 field0 ints
  rp 'let x=0.f' 'echo (1+x)/x'               # cache field 0 parse
  rp -d, -fa,b,c 'echo s[a],b.f+c.i.float'    # named fields (CSV)
  rp -mfoo echo\ s[2]                         # column of row matches
  rp -pimport\ stats -vr:RunningStat r.push\ 0.f -eecho\ r # Moments

Add niceties (eg. import lenientops) to prelude in ~/.config/rp.

Options:
  -p=, --prelude= strings {}           Nim code for prelude/imports section
  -b=, --begin=   strings {}           Nim code for begin/pre-loop section
  -v=, --var=     strings {}           preface begin w/"var "+these shorthand
  -m=, --match=   string  ""           row must match this regex
  -w=, --where=   string  "true"       Nim code for row inclusion
  -e=, --epilog=  strings {}           Nim code for epilog/end loop section
  -f=, --fields=  string  ""           delim-sep field names (match row0)
  -g=, --genF=    string  "$1"         make field names from this fmt; eg c$1
  -n=, --nim=     string  "nim"        path to a nim compiler (>=v1.4)
  -r, --run       bool    true         Run at once using nim r ..
  -a=, --args=    string  ""           "": -d:danger; '+' prefix appends
  -c=, --cache=   string  ""           "": --nimcache:/tmp/rp (--incr:on?)
  -l=, --lgLevel= int     0            Nim compile verbosity level
  -o=, --outp=    string  "/tmp/rpXXX" output executable; .nim NOT REMOVED
  -s, --src       bool    false        show generated Nim source on stderr
  -i=, --input=   string  ""           path to mmap|read; ""=stdin
  -d=, --delim=   string  "white"      inp delim chars; Any repeats => fold
  -u, --uncheck   bool    false        do not check&skip header row vs fields
  -M=, --MaxCols= int     0            max split optimization; 0 => unbounded
  -W=, --Warn=    string  ""           "": --warning[CannotOpenFile]=off
```

Comparing Examples To `awk`
---------------------------
Corresponding to our first 6 examples are these `awk` commands:
```
                                             #  rp v. awk
seq 0 1000000 | awk 'length<2'               # (17 v. 15) short rows
awk '{print $2," ",$1}'                      # (25 v. 29) Swap fields
awk '{t+=NF}END{print t}'                    # (26 v. 29) total fields
awk '{if($1>0)t+=$1}END{print t}'            # (38 v. 35) Total >0 field0
awk '{x=0+$1;print(1+x)/x}'                  # (32 v. 33) cache parse
awk '/foo/{print $3}'                        # (19 v. 24) column of row matches
awk -F, 'BEGIN{a=1;b=2;c=3}{print $a,$b+$c}' # (41 v. 51) named CSV fields
```
The numbers in ()s are (`rp` v. `awk` key presses) *counting* SHIFTs totaling
197 for `rp` vs. 216 for `awk`.  That is with *minimal* SHIFT use (ie. ***one***
SHIFT down to enter "}END{") for US keyboard layouts.  `awk` needs much more
shifting and minimal ways may feel "unnatural" (most folks I know would not
stay shifted through that "}END{" sequence).  Press counts for the Nim eg.s can
also be further trimmed.[^1]  So, even biased towards `awk` a couple ways, `awk`
is *still* 10..30% more program entry work.

The point of key press analysis is A) to observe any CLI is already "part DSL" -
language boundaries can ease syntax requirements on both & B) just ballpark
interactive ergonomics in a "quickly write a pipeline stage in-line" mode.[^2]
Repeated constructs can & should surely be saved in files / abstracted.  Nim
shines *brighter* then (as would most prog.langs with abstraction & ecosystems
beyond `awk`).  Said shining manifests in the e.g. using `std/stats.RunningStat`
type to get stats which would require much more work in `awk`.

Future/User Work/Extensibility
------------------------------
There are easy ideas to round out functionality whose value depends upon your
use case.  It may be nice to automatically open files like `print 1 > "myPath"`
does in `awk`, for example, with some tiny `autorp.nim` module like this added
as an import in `~/.config/rp` as `prelude = "import autorp"`:
```Nim
import std/[re, tables], cligen/print; export re, print
# NOTE: more imports => slower compiles
template af(nm, openMode) =         # Auto-File tables
  var `nm Tab`: Table[string, File]
  proc nm*(fNm: string): File =
    try: `nm Tab`[fNm] except: (let f = open(fNm, openMode); `nm Tab`[fNm]=f; f)
af aw, fmReadWrite; af aa, fmAppend; af ar, fmRead      # `ar` least useful here

var cpTab: Table[string, Regex]     # Cached Pattern: compiled expression
proc cp*(pat: string): Regex =      # strHash lookups ~faster than rx compiles
  try: cpTab[pat] except: (let f = pat.re; cpTab[pat] = f; f) # re"foo"->cp"foo"

template p*(a: varargs[untyped]) = print a              # Auto-blank seps
template ec*(a: varargs[untyped]) = echo a              # No auto-blank seps
template wr*(f: File, a: varargs[untyped]) = write f, a # Ease "foo".aw.wr bar
```
you can then just say with 54 [keydowns](keydowns.md) (including "rp ")[^3]:
```sh
printf "%s\n" "brown bread mat hair 42" \
              "blue cake mug shirt -7"  \
              "yellow banana window shoes 3.14" |
  rp -w'row=~cp"w"' '"myPath".aw.write 4.f,"\n"'
```
where only table lookups occur on a per-row basis.  More run-time efficient is,
of course, to use 72 key downs to elide those lookups with instead:
```sh
rp -b'let p=cp"w";let o=aw"myPath"' -wrow=\~p 'o.write 4.f,"\n"'
```
About all that is lost via this approach vs. a new PL is fast interpreter
start-up time and *automatic* lifting of `Table` lookups into variables.

As another example, the `begin` section which has the split columns `s` in scope
can also be used with `~/.config/rp` to extend the generated template language
with new (probably terse) column-index-keyed procs, such as `D1` to parse some
"DateTime" in "common format #1".  Since `--begin` is a `Strings` sequence,
`~/.config/rp` code is injected first & in-order.  Since `rp` uses `mergeCfgEnv`
you can do `RP_CONFIG=x rp ..` to try new configs, have other "dialects", etc.

Populating global namespaces with such features has trade-offs, in compile-time
duration if nothing else.  So, it is deferred to `~/.config/rp` authors.

Some nim.cfg `--path` tweaks and `~/.config/rp` hacking, and you can cover any
`awk` use case with a fully strongly type-checked, compilable prog.lang with
terse but general syntax.  You can also use this as a prototyping environment,
copying generated code away from `/tmp/rp\*.nim` to be the basis for new,
standalone programs (yes, with `cligen/[mfile,mslice]`-dependency as currently
written), probably instead compiled slowly with full optimizations.[^4]

Related Discussion
------------------
Some more discussion [is here](https://news.ycombinator.com/item?id=30190436)
which inspired Ben to write [Prig](https://github.com/benhoyt/prig/) and [an
article about it](https://benhoyt.com/writings/prig/) discussed (at least)
[here](https://news.ycombinator.com/item?id=30498735).

Few prog.langs have both easy to enter/terse expressions & fast compiles.  For a
comparison point, see `crp.md`/`crp.nim` in this repo which uses C for the
base-code language or Ben's Go examples.

[^1]: Down to 15+25+24+34+28+39+18=183 for `rp`. Similar \\-optimizing for `awk`
saves only 1 stroke at 215 for ***1.18x less key press work*** than `awk`.  This
can be improved using a `p` for `echo` from some `~/.config/rp` user import,
saving 3\*6=18 more for 165 v.215 or ***1.30x*** fewer key presses.  But sure,
some shells may not need {} protected, "'" need less "inline thought" than '\',
7 presses come just from from the length of `"rp"` v.  `"awk"`, and not counting
ENTER keystrokes maybe mis-normalizes.  Even so, the main point of this key down
comparison is that it is hard to argue that `awk`'s syntax optimization saves
much, yet easy to argue that it restricts libs & perf.

[^2]: Ben's `prig` article (linked later) uses chars not key presses.  Visual
length is easier to measure and a more appropriate metric for code reading vs.
key presses for code entry.  Which matters more all depends.  Entry seems more
common when selling 1-liners in my experience.  Once one considers shell history
/ command edit analysis, finger reach/strain/etc., comparison gets complex fast.
E.g., Caps-Lock can be a thing.  Better methodology might start with X event
logging over long, realistic sessions and real-time metrics use, but things then
become rather user-idiosyncratic and you need pools of users.

[^3]: Equivalent awk might be `awk '/w/{print$5>"myPath"}'` - only 33 keydowns,
winning by quite a bit in this fancier case, at the cost of its auto-inits.

[^4]: [`newest`](newest.md) can ease that `mv $(newest -n2 /t/|g nim) x.nim`.
