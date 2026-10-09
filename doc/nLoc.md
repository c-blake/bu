# Motivation

People often bandy around "LoC" or "kLoC" kinds of lines of code metrics,
sometimes bigger being better often for me smaller seeming more manageable.
Either way, it seems unfair to me to count verbosity in both documentation and
strings for several reasons.  First, that source text is almost never "logic
itself" except in templated generation schemes and even then it is usually logic
in another PLang or no "P"-Lang at all (like HTML).  Second, both are usually
colorized by editors or even web sites like Github meaning human readers skip it
a lot (or attend it exclusively!) reinforcing its categorical distinctness.
Third, relatedly, it can be very out-of-date / stale with "the real code".
Fourth, because of the above, one could even imagine an editor configurable to
hide/reveal these things.  Fifth, while low code/low logic is usually "good",
the same cannot always be said for documentation.  So, they are not good/bad
together.  There are surely other reasons/arguments.

I am unsure "normalized code" is really a standard term in this space, but it
makes sense to me.  "Standardized" evokes `go fmt` or `nimpretty`-like ideas.
At least in the Nim world, normalized idents were a big thing for a long time.
Nothing in this space is perfect or captures all (subjective?) biases well,
but this at least seems better to me than "gzipped sizes" from [the shootout
game](https://en.wikipedia.org/wiki/The_Computer_Language_Benchmarks_Game).

Nim, like python, has an "if/when main" notion.  This leads to one final wrinkle
which is test/demo code at the end of library modules where it may be unfair to
count that as library code rather than as lib documentation.  This program only
handles lexical `when SYMBOL ...` right now, not `when x and SYMBOL` or `const
foo = SYMBOL and blah; when foo: ...` or other complex ideas/logics.

# Usage
```
  nLoc [optional-params] files to measure; Empty string arg => stdin

Count "normalized" Nim code lines: not blank, not any comment (#, ##, #[ ]#,
##[ ]#, nested), not interiors of multi-line string literals, and not when
isMainModule... statements (or their elif/else chains).  Since it uses Nim
compiler as a lib, string/char/raw/triple-quote/nested-comment lexing matches
the compiler exactly.

  -d=, --drop=  set(Drop) {}             `docComment`, `strLit`, `when`; {}=>ALL
  -w=, --when=  string    "isMainModule" root symbol for when branch drops
  -s, --showSrc bool      false          emit normalized source, not line count
```

No argument at all is the same as a first empty string argument.  Modules which
fail Nim's lexer also abort the entire run here (i.e. rest of `files`) (e.g.
hard-TAB or other issues).

# Example

On itself:
```sh
$ nLoc nLoc.nim
75      nLoc.nim
```

or maybe (output elided):

```sh
nLoc *.nim|sort -n
```

A more full example with this as `test.nim`:
```Nim
#[ block comment
   with nested #[ inner ]# still comment
]#
##[ doc block
   triple quote nested inside block doc-comment
]##
let a = 1 # trailing comment
# full line comment

let s = "has #[ inside a string"
let t = "still code ]# after"
let c = '#'
let r = r"raw # not comment"
let tq = """
# this is inside a triple-quoted string
#[ also string content
"""
proc p() = #[ inline block ]# echo 1
let x = 3 ##[ block start on its own line
   #[ nested
   """
   triple quote nested inside block non-doc comment
   """
   ]# still inside
]##
## doc comment line
echo `a` ## doc after code
let y = 5 #[ multi
  line trailing block
]#
const k = "a" & #[ mid ]# "b"

when isMainModule:
  echo "test code", [1,
2, 3, 4]
else:
  echo "non-test library code - almost never happens"
```

```sh
$ nLoc -s test.nim
```

prints just these 11 lines:

```Nim
let a = 1
let s = ""
let t = ""
let c = '#'
let r = r""
let tq = ""
proc p() = echo 1
let x = 3
echo `a`
let y = 5
const k = "" & ""
```

..while this does similar, but leaves string literal bodies alone:
```sh
$ nLoc -s -d,=,d,w test.nim
```

In a top-level bu/ checkout circa October 2026 one can see at a glance the best
& worst in terms of either essential complexity or perhaps lack of abstraction:
```sh
nLoc *.nim|sort -n|align -dw + -|flow
   6 tattr.nim          31 fsids.nim         47 topn.nim           93 tim.nim
   8 ww.nim             32 cfold.nim         49 rp.nim             97 nrel.nim
   9 wsz.nim            32 oft.nim           50 dirq.nim          105 zeh.nim
  15 fage.nim           33 fread.nim         53 unfold.nim        107 etr.nim
  15 keydowns.nim       34 cols.nim          54 ft.nim            118 mk1.nim
  15 uce.nim            34 fpr.nim           57 mova.nim          120 dfr.nim
  20 noc.nim            36 since.nim         59 k1st.nim          122 dups.nim
  20 tmpls.nim          37 adorn.nim         59 thermctl.nim      122 ru.nim
  21 notIn.nim          37 niom.nim          60 only.nim          142 align.nim
  21 rr.nim             37 noa.nim           65 tw.nim            143 stripe.nim
  21 sr.nim             39 lncs.nim          66 funnel.nim        150 edplot.nim
  22 pid2.nim           40 holes.nim         68 memlat.nim        175 tails.nim
  22 widths.nim         41 ndelta.nim        71 saft.nim          179 catz.nim
  23 flow.nim           43 okpaths.nim       74 ac.nim            198 wgt.nim
  24 newest.nim         44 crp.nim           74 cstats.nim        488 vip.nim
  26 tslice.nim         44 dirt.nim          75 nLoc.nim         4553 total
  29 jointr.nim         45 chom.nim          88 cbtm.nim         
  30 fkindc.nim         46 wits.nim          93 du.nim           
```
