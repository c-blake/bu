Motivation
----------

This is mostly just a slightly faster to key stroke (& execute) version of
`awk '{print $X}'`.  It also exercises a few library APIs from
[`cligen/`](https://github.com/c-blake/cligen)/acts as demo/example
code for that and was a very early member of cligen/examples/.

A couple things it has over the `awk` invocation is the ability to delete
indicated columns (with --cut) almost as easily as retaining them and to
shift column-index origins.

Usage
-----
```
  cols [optional-params] [colNums: int...]

Write just some columns of input to output; Memory map input if possible.

  -i=, --input=  string "/dev/stdin"  path to mmap|read as input
  -d=, --delim=  string "white"       inp delim chars; Any repeats => fold
  -o=, --output= string "/dev/stdout" path to write output file
  -s=, --sepOut= string " "           output field separator
  -b, --blanksOk bool   false         allow blank output rows
  -c, --cut      bool   false         cut/censor specified columns, not keep
  --origin=      int    1             origin for colNums; 0=>signed indexing
```
