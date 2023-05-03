Motivation
==========
`tmpls` is largely similar to a sub-shell such as:
```sh
while read a; do printf "i/%s.c\no/%s.o\n" "$s" "$s"; done
```
but it is much faster.[^1]

Usage
=====
```
  tmpls [optional-params] templates...

Interpolate { %s)tring | %n)eed quoted | always %q)uoted | %e)scaped } into
as many templates as given, writing back-to-back template-filled-in batches to
stdout, with each individual template terminated by term.

E.g.:
  find . -name '*.c' -print|sed 's/.c$//' | tmpls %s.c %s.o %n.c %e.o

Options:
  -f=, --file= string "/dev/stdin" input file of name stubs
  -n=, --nl=   char   '\n'         input string terminator
  -t=, --term= char   '\n'         output string terminator
  -m=, --meta= char   '%'          self-quoting meta for %sub
```

[^1]: I get 25X-75X improvements.  As always, this depends on a lot, such as if
/bin/sh is dash, bash, zsh, etc. as well as what the CPU is.  /bin/sh variation
is large enough, and the implementation of `tmpls.nim` simple enough that real
benchmarking does not seem very pointful.


