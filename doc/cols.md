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

Over just `cut` it provides:
 - default to keep; more terse CL syntax than "--complement"
 - ability to split 1 column on repeated bytes (like `awk`)

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
  -t=, --term=   char   '\n'          set row terminator (e.g. \0)
```

Examples
--------
After:
```
(echo 1 2 3 4; echo; echo 4 5 6 7) > /tmp/d
```
you get:
```
cols 2 4 < /tmp/d
```
producing
```
2 4
5 7
```
With `cols -c0 -- -4..-3` you get:
```
3 4
6 7
```
since you are cutting 0-origin 4th from end & 3rd from end.
Meanwhile with `cols -0 1:3` you get:
```
2 3
5 6
```
since you are keeping the exclusive slice indicating 0-origin 1 & 2.

With all of them if you add `-b` the blank row propagates, or you can make the
output separated TAB or terminator NUL, etc.

That's it, really.  This intends to be a very simple utility.
