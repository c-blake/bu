This generalizes `head` & `tail` into one program which can also do things which
would require (at least) fancy FIFO tricks to otherwise accomplish (like both
the beginning and end of the same stream or its complement).

`tails` is intended to be mnemonic like "tails of a probability distribution"
(i.e. the low & high sides of a 1-D range).

```
Usage:

  tails [optional-params] [paths: string...]

Generalized tail(1); Can do both head & tail of streams w/o tee FIFO.

  -h=, --head=   int     0      number of rows at the start
  -t=, --tail=   int     0      number of rows at the end
  -s=, --sep=    string  "--"   separator, for non-contiguous case
  -c, --compl    bool    false  complement of selected rows (body)
  -r, --repeat   bool    false  repeat rows when head+tail>=n
  -e=, --eor=    char    '\n'   end of row/record char
  -q, --quiet    bool    false  never print headers giving file names
  -v, --verbose  bool    false  always print headers giving file names
```

Examples
--------

```
seq 1 100|tails -h3 -t3
```
produces
```
1
2
3
--
98
99
100
```
while
```
seq 1 10|tails -c -h3 -t3
```
produces
```
4
5
6
7
```

Related Work
------------
For pre-parsed data, there is
https://github.com/c-blake/nio/blob/main/nio.nim#L1014
