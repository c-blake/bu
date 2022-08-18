Motivation
----------
Programs will often dump out text with highly irregular formatting that would be
much easier to read with aligned text columns on terminal emulators.  Other
times, you may be parsing a CSV into fixed width buffers and it may help to
assess the width needed (which is the same problem alignment needs solving).

This tool has a few creature comforts such as numbering columns for you with
either 0-origin or 1-origin values, an ability to adjust terminal widths to
ANSI colorized text, to measure column widths and so on.  (It could/should
probably grow UTF8-rendered width adaptation as well.)

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

  -d=, --delim=     string ","   inp delim chars; Any repeats => foldable
  -s=, --sepOut=    string " "   output separator (beyond just space padding)
  -0, --origin0     bool   false print a header of 0-origin column labels
  -1, --origin1     bool   false print a header of 1-origin column labels
  -w, --widths      bool   false first output row is column widths in bytes
  -W, --Widths      bool   false printed widths DO NOT reflect header row(s)
  -H, --HeadersOnly bool   false only print column headers, widths, labels.
  -e=, --empty=     string ""    output string for empty internal cell/header
  -n=, --null=      string ""    output string for cell introduced as padding
  -p, --prLen       bool   false force adjust for ANSI SGR escape sequences
  -m=, --maxCol=    int    0     max columns to form for aligning;0=unlimited
```

Related Work
------------
This tool is very similar to GNU/BSD `column`, but `align` has a "centering"
option which last I checked `column` does not (only left/right alignment).
`column` does not measure widths either and the implicit measurement will not
segregate "header" data from "table body data" just structurally.  It is also
not easy to right align all columns after a given column since you need to
specify each column number in `column --table-right`.  But I'm also sure that
GNU `column` has many features that `align` lacks.
