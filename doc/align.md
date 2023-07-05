Motivation
----------
Programs often dump out text with irregular formatting that is easier to read
with terminal-aligned text columns.  ANSI SGR color escape sequences and utf8
further complicate this (which this tool auto-detects in the first several
lines, but which can be forced via `--prLen`).

This tool has other creature comforts such as limiting the number of columns or
number-labeling them.  It can also render empty internal cells differently from
"far right side" padding cells (both needed to preserve a visual table structure
with jagged input).  It also allows `--sepOut="|"`, etc.

Usage
-----
```
  align [optional-params] [alignSpecs: string...]

stdInOut filter to align an ASCII table & optionally emit colNo header row.
Zero or more alignSpecs control output alignment:

  -[(emptyCode|aByte|classCode)][<R(1)>] Left Align (default) R columns
  +[(emptyCode|aByte|classCode)][<R(1)>] Right Align  R columns
  0[(emptyCode|aByte|classCode)][<R(1)>] Center R columns

where

  emptyCode Names the empty string for a column; absent => 'e'
  aByte     Specifies '.'|','-like alignment byte; cannot be 'e'
  classCode Names digit-like set w/an implied trailing align byte (only
              if byte missing).  Cannot collide with char code emptyCode.

The final alignSpec is used for any higher, unspecified columns.  E.g.:

  align -d=: -enN/A - + +. +.nd - < /etc/passwd | less -S

left aligns all 7 but 2nd,3rd,4th w/3&4th '.'-align w/fallback to right & 4th
w/"N/A" empties & implicit '.' (all others have a default "" empty).

  -i=, --input=   string  "-"   path to mmap|read as input; "-" => stdin
  -d=, --delim=   string  ","   inp delim chars; Any repeats => foldable
  -m=, --maxCol=  int     0     max columns to form for aligning;0=unlimited
  -p, --prLen     bool    false force adjust for ANSI SGR escape sequences
  -a=, --aclass=  strings d0-9  byteCharacterClass bindings; "-" => a range
  -s=, --sepOut=  string  " "   output separator (beyond just space padding)
  -0, --origin0   bool    false print a header of 0-origin column labels
  -1, --origin1   bool    false print a header of 1-origin column labels
  -n=, --null=    string  ""    output string for cell introduced as padding
  -e=, --empties= strings e     byteString binds for missing internal cells
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
lc -1sL | sgr-bunch | align -dw -m8 -s\| +7 -
```
which will right- rather than left-align the first 7 columns (4th & 5th columns,
Usr & Grp, are left-aligned by `lc`).  It also left align the final column and
for kicks puts a bunch of `|` pipe symbols to make vertical bars in the output.

Very Involved Numeric Example[^1]
---------------------------------
This `align` can align on decimals (or other characters):
```sh
printf "aa,b,c\n1,.22,\n,3.,4,5\n6,7,8.\n" |
  align -e=nNA -n=: +n +. +.d 02 -
```
prints:
```
aa    b  c : : :
 1  .22    : : :
NA 3.   4  5 : :
 6    7 8. : : :
```
Explanation of this dense specification of fancy features:
  - `-e=nNA`: code 'n' means spell missing internal fields "NA" (not e=blank)
  - `-n=:`: padding fields due to short rows are spelled ":" (any extra columns)
  - `+n`: first column is right aligned w/missing field code 'n' (not blank)
  - `+.`: the `'.'` in `.22` aligns with that of `5.`; No '.' => + (as with `7`)
  - `+.d`: like above, but last char in class `d` gets implicit '.' (default
          `aclass ["d0-9"]` provides a decimal digit class)
  - `02`: centered alignment ('0') repeated twice, making 2 empty X cols
  - `-`: left aligned for however many columns input has (none here)

Note that the blank 2nd row of the 'c' column from the ",\n" substring is not a
mistake, but rather the default unless overridden by a columns alignSpec.  You
can override that default with `-e=eNA` (or similar) if desired.

If you deal with inputs from Western Europe where `,` not `.` is used as decimal
radix, you can say `+,d` (though you likely have a different than default `-d,`
delimiter).

You can add new character classes with `align -ah0-9a-hA-H` to make `+.h` align
hexadecimal digits even without a '.' (e.g. for mixed hex & hex float).  You can
save such fancy definitions in your `~/.config/align` if you like.

Note that to avoid remembering order / delimiters or id tags all chars after
the alignment character are on an equal footing except the repetition integer
which must be last (and goes to the end of the argument slot).  This mostly
just means that codes like 'e' and 'd' cannot collide with each other or with
radix point characters (which seems unlikely in practice).

Related Work
------------
This tool is very similar to GNU/BSD `column`, but `align` has a "centering"
option which last I checked `column` does not (only left/right alignment).
`align` also tells the user column numbers rather than using them to specify.
It is also easier to right align all columns on jagged tables with unknown
numbers of columns. (GNU `column` surely has many features that `align` lacks,
of course.)  While there is probably some Perl tool to do the decimal alignment
bits, this Nim tool works ~6X faster than `less` and so is more "for free".

[^1] This feature does not yet work well with utf8/SGR inside numeric columns,
but that is hopefully a rare use case.
