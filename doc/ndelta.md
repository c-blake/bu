Motivation
----------
Often one runs a program twice - one way and the other way - to see how some
parameter/input/mode/.. changes things.  One then wants to compare the output of
something reported - maybe resource consumption like time/space or success
amounts or other accuracy parameters or other numeric outputs.  So, the output
is "largely" identical (or can be made so with sorting) except for "numbers" in
different areas of the report.  This situation is what `ndelta` is for.

Usage
-----
```
  ndelta [optional-params] [paths: string...]

Replace numbers in token-compatible spots of paths[0] & paths[1] with (absolute
| ratio | relative | perCent) deltas.  To trap out-of-order data, differences in
context are highlighted unless sloppy is true.

  -k=, --kind=   DKind  ratio   DiffKind: absolute, ratio, relative, perCent
  -d=, --delims= string "white" repeatable delim chars
  -n=, --n=      int    3       FP digits to keep
  -s, --sloppy   bool   false   allow non-numerical context to vary silently
```
A relative difference here is the `ratio - 1.0` while `perCent` is that
multiplied by 100.

Presently, `ndelta` has some sanity checks (total token count equality) to
help the report be meaningful in the way intended and a sloppy mode to let
context/delimiters vary but be reported in the output.

Related Work
------------
There is, of course, the ever-present `diff` possibly combined with my `hldiff`
to highlight sections, but this only presents textual differences while one
often wants numeric (one of the 4 kinds currently supported by `ndelta`).
`ndelta` is a very simple program.  Variants of it have surely been done many
times.  If me not mentioning one here bugs you, bug me and I'll mention it. :)
