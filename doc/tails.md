This generalizes `head` & `tail` into one program which can also do things which
would require (at least!) fancy FIFO tricks to otherwise accomplish (like both
the beginning & end of the same stream or its complement).  `tails` is intended
to be mnemonic for "tails of a probability distribution" (i.e. the low & high
sides of a 1-D range).

It also adds a config file as well as abstract input & output records and
user-customization of `repeat` for a new special case.  It also allows setting
`header` for, e.g. ANSI SGR highlighting codes to make file name headers "really
pop" out at you on color terminals.

```
Usage:

  tails [optional-params] [paths: string...; '' => stdin]

Emit|cut head|tail|both.  This combines & generalizes normal head/tail.
"/[n]" for head|tail infers a num.rows s.t. output for n files fits in
${LC_LINES:-${LINES:-ttyHeight}} rows. "/" alone infers that n=num.inputs.

  -h=, --head=   int|/[n] 0     number of rows at the start
  -t=, --tail=   int|/[n] 0     number of rows at the end
  -s=, --sep=    string   "--"  separator, for non-contiguous case
  -b, --body     bool     false body not early/late tail
  -r, --repeat   bool     false repeat rows when head + tail >= n
  -H=, --header= string   ""    header format; "" => n==> $1 <==n
  -q, --quiet    bool     false never print file name headers
  -v, --verbose  bool     false always print file name headers
  -i=, --ird=    char     '\n'  input record delimiter
  -e=, --eor=    char     '\n'  output end of row/record char
```

Examples
--------

```
seq 1 99|tails -h3 -t3|tr \\n ' '
```
emits
```
1 2 3 -- 97 98 99
```
while
```
seq 1 9|tails -b -h3 -t3|tr \\n ' '
```
produces
```
4 5 6
```

Related Work
------------
For pre-parsed data, there is
https://github.com/c-blake/nio/blob/main/nio.nim#L1014
