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
  rp 'let x=0.f' 'echo (1+x)/x'               # cache field 0 parse
  rp -d, -fa,b,c 'echo s[a],b.f+c.i.float'    # named fields (CSV)
  rp -pimport\ stats -bvar\ r:RunningStat r.push\ 0.f -eecho\ r

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

Comparing Examples To `awk`
---------------------------
Corresponding to our first 6 examples are these `awk` commands:
```
seq 0 1000000 | awk 'length<2'               # (17 v. 15) short rows
awk '{print $2," ",$1}'                      # (25 v. 29) Swap fields
awk '{t+=NF}END{print t}'                    # (32 v. 29) total fields
awk '{if($1>0)t+=$1}END{print t}'            # (44 v. 35) Total >0 field0
awk '{x=0+$1;print(1+x)/x}'                  # (32 v. 33) cache parse
awk -F, 'BEGIN{a=1;b=2;c=3}{print $a,$b+$c}' # (41 v. 51) named CSV fields
```
The numbers in ()s are (`rp` v. `awk` key presses) *counting* SHIFTs totaling
191 for `rp` vs. 192 for `awk`.  That is with *minimal* SHIFT use (ie. ***one***
SHIFT down to enter "}END{") for US keyboard layouts.  `awk` needs much more
shifting and minimal ways may feel "unnatural" (most folks I know would not
stay shifted through that "}END{" sequence).  Press counts for the Nim eg.s can
also be better trimmed with `\` instead of `'`.[^1]  So, even biased towards
`awk` a couple ways, `awk` is *still* more program entry work (barely).

The point of key press analysis is only to roughly estimate interactive
ergonomics in a "write something quickly" mode.[^2]  Repeated constructs can &
should surely be saved in files / abstracted.  Nim shines *brighter* then (as
should most prog.langs with abstraction beyond `awk` & *any* ecosystem).  Said
shining manifests in the e.g. using Nim's `std/stats.RunningStat` type to get
skewness & kurtosis stats which would require much more work in `awk`.

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
can cover any `awk` use case with a fully strongly type-checked, compilable
prog.lang with terse but general syntax.  You can also use this as a prototyping
environment, copying generated code away from `/tmp/rp\*.nim` to be the basis
for new, standalone programs (yes, with `cligen/[mfile,mslice]`-dependency as
currently written).[^3]

Related Discussion
------------------

Some more discussion [is here](https://news.ycombinator.com/item?id=30190436)
which inspired Ben to write [Prig](https://github.com/benhoyt/prig/) and [an
article about it](https://benhoyt.com/writings/prig/) discussed (at least)
[here](https://news.ycombinator.com/item?id=30498735).

Few prog.langs have both easy to enter/terse expressions & fast compiles.  For a
comparison point, see `crp.md`/`crp.nim` in this repo which uses C for the
base-code language or Ben's Go examples.

[^1]: Down to 16+25+30+41+30+41=183 for `rp` and similar backslash optimizing
for `awk` saves only 1 stroke at 192 for *5% less pressing work* than `awk`.
But sure, there may be shells not needing braces protected, single quotes need
less inline thought than backslash, etc.

[^2]: Ben's `prig` article (linked later) uses chars not key presses.  Visual
length is easier to measure and a more appropriate metric for code reading vs.
key presses for code entry.  Which matters more all depends.  Entry seems more
common when selling 1-liners in my experience.  Once one considers shell history
/ command edit analysis, finger reach/strain/etc., comparison gets complex fast.
E.g., Caps-Lock can be a thing.  Better methodology might start with X event
logging over long, realistic sessions and use real-time metrics, but things then
become rather user-idiosyncratic and you need pools of users.

[^3]: For me that is maybe just `mv $(newest -n2 /t/|g nim) x.nim`.
