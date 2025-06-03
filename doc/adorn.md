# Motivation

A useful semi-frequent transformation of a text table is something like:

```sh
awk '{$col = prefix $col suffix; print $0}'
```
BUT this normalizes whitespace between columns, messing up terminal alignment
if any was present.  `adorn` seeks to be less disruptive.

There are, of course, Perl/Python solutions, but the body of the Nim code is
only 28 lines and it runs much faster (>7X in informal timings).

# Usage
```
  adorn [optional-params] origin-origin column numbers

input-output filter to adorn columns by adding prefix &| suffix to specified
delim-delimited cols, preserving all delimiting.  Columns, prefix, suffix share
indexing (so you may need to pad with "").  E.g.:

  paste <(seq 1 3) <(seq 4 6)  <(seq 7 9) | adorn -pA -sB 1 -pC 3

Options:
  --origin=      int     1     origin for cols; 0=>signed indexing
  -O, --O0       bool    false shorthand for --origin=0
  -p=, --prefix= strings {}    strings to prepend to listed columns
  -s=, --suffix= strings {}    strings to append to listed columns
  -i=, --input=  string  ""    path to mmap|read as input; "" => stdin
  -r=, --rowDlm= char    '\n'  input row delimiter character
  -d=, --delim=  string  "w"   input field dlm chars; len>0=>fold;w=white
  -o=, --output= string  ""    path to write output file; "" => stdout
```

# Examples

Add an explicit field label somewhere (possibly for additional post-processing):
```sh
seq 1 9 | adorn -p 'label: ' 1
```

Make `$argv[0]` inverse { using [`tattr`](tattr.md) } in a cb0 `--style=basic`
[`procs display`](https://github.com/c-blake/procs) listing:
```sh
pd -sb | adorn -p$(tattr inverse) -s$(tattr -- -inverse) 8
```
