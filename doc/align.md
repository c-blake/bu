Motivation
----------
Programs will often dump out text with highly irregular formatting that would be
much easier to read with aligned text columns on terminal emulators.  ANSI SGR
color escape sequences and utf8 further complicate this (which this tool auto-
detects in the first several lines, but which can be forced via `--prLen`).

This tool has a few other creature comforts such as limiting the number of
columns or number-labeling them for you.  It can also render empty internal
cells differently from "far right side" padding cells (both needed to preserve
a visual table structure).  It also allows a `--sepOut="|"` or etc.

Usage:
```
  align [optional-params] [alignSpecs: string...]

This stdin-out filter aligns an ASCII table & optionally emits header rows with
widths/colNos.  Zero or more alignSpecs control output alignment:

  - left aligned (default)
  + right aligned
  0 centered

The final alignSpec is used for any higher, unspecified columns.  E.g.:

  align -d : - + + + - < /etc/passwd

left aligns all but 2nd,3rd,4th

  -d=, --delim=  string ","   inp delim chars; Any repeats => foldable
  -m=, --maxCol= int    0     max columns to form for aligning;0=unlimited
  -p, --prLen    bool   false force adjust for ANSI SGR escape sequences
  -s=, --sepOut= string " "   output separator (beyond just space padding)
  -0, --origin0  bool   false print a header of 0-origin column labels
  -1, --origin1  bool   false print a header of 1-origin column labels
  -n=, --null=   string ""    output string for cell introduced as padding
  -e=, --empty=  string ""    output string for empty internal cell/header
```

More Involved Example
---------------------
Note that ANSI SGR color escape codes embedded in "blank" space can appear to be
non-empty columns with repeated whitespace delimiting (such as `-dw`).  This can
often be worked around by incorporating
```
e=$(printf \\e)
sed "s/\(  *\)\($e\[[0-9a-f;]*m\)\(  *\)/\2\1\3/g"
```
(or `/\1\3\2/g`) into shell pipelines or saving the above in some `sgr-bunch`
script/shell function/alias.  With [lc](https://github.com/c-blake/lc)'s
provided config and the above definition, one can do:
```
lc -1sL | sgr-bunch | align -dw -m8 -s\| + + + + + + -
```
which will right- rather than left-align the first 7 columns (4th & 5th columns,
Usr & Grp, are left-aligned by `lc`).  It also left align the final column and
for kicks puts a bunch of `|` pipe symbols to make vertical bars in the output.

Related Work
------------
This tool is very similar to GNU/BSD `column`, but `align` has a "centering"
option which last I checked `column` does not (only left/right alignment).
`align` also tells the user column numbers rather than using them to specify.
It is also easier to right align all columns on jagged tables with unknown
numbers of columns. (GNU `column` surely has many features that `align` lacks,
of course.)
