Motivation
----------

This is a faster to key stroke (& execute) version of `awk '{print $X}'`.  It
also acts as demo/example code for some library APIs from
[`cligen/`](https://github.com/c-blake/cligen) & was a very early member of
`cligen/examples/` itself.

Something it provides over the `awk` invocation is
 - the ability to delete indicated columns (with `-c, --cut`).

Things it provides over both `awk` & GNU coreutils `cut` are the ability to:
 - shift column-numbering origins (e.g. 0 | 1-origin)
 - do either inclusive (..) OR exclusive (:) ranges/slices
 - allows numbers < 0 to mean from-the-end (like Python) { use `--` or \\-escape
   (or quote) whitespace before `'-'` to avoid treatment as an option }.

Usage
-----
```
  cols [optional-params] colNums or A..B | X:Y (in|ex)clusive ranges thereof

Write just some columns of input to output; Memory map input if possible.

  -i=, --input=  string "/dev/stdin"  path to mmap|read as input
  -d=, --delim=  string "white"       inp delim chars; Any repeats => fold
  -o=, --output= string "/dev/stdout" path to write output file
  -s=, --sepOut= string " "           output field separator
  -b, --blanksOk bool   false         allow blank output rows
  -c, --cut      bool   false         cut/censor specified columns, not keep
  --origin=      int    1             origin for colNums; 0=>signed indexing
  -t=, --term=   char   '\n'          set record terminator (e.g. \0)
```
