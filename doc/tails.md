Motivation/Overview
-------------------
This generalizes `head` & `tail` into one program which can also do things which
would require (at least!) fancy FIFO tricks to otherwise accomplish (like both
the beginning & end of the same stream).  `tails` is intended to be mnemonic for
"tails of a probability distribution" (i.e. low & high sides of a 1-D range).
It also adds abstract input & output records, a config file, and user-customized
cycling headers.

Good application of the config file & cycling headers is to put 3..9 (whatever
you can easily remember) instances of `header` in the config file.  Most
graphical plotting facilities have this feature for line styles.  I use varying
color, but if you hate color you can also use different textual embellishment
such as many stars, slashes, ampersands, etc.  And like plotting line styles,
there is nothing stopping you from using *both* the equivalent of color and
solid, dots & dashes.  This eases distinguishing file names from each other
& from surrounding text.  It eases so much that you can usually avoid the
blank line preceding headers common in other head/tail impls (particularly for
background dominant "inverse modes").  This distinguishing is always helpful,
but particularly so for output from multiple files as `tails -f A B C..` might
produce.

For compatibility, when invoked with an argv[0]/$0 of `head` or `tail`,
arguments are massaged to match GNU coreutils `head` / `tail` (including `-c` &
negative `-n` args, but not *all* features).

Usage
-----
```
    tails [optional-params] [paths: string...; '' => stdin]

Unify & enhance normal head/tail to emit|cut head|tail|both.  "/[n]"
for head|tail infers a num.rows s.t. output for n files fits in
${LC_LINES:-${LINES:-ttyHeight}} rows. "/" alone infers that n=num.inputs.

  -?, --help                    print this cligen-erated help
  -h=, --head=   int|/[n] 0     >0 emit | <0 cut this many @start
  -t=, --tail=   int|/[n] 0     >0 emit | <0 cut this many @end;
                                Leading "+" => head = 1 - THIS.
  -f, --follow   bool     false output added data as files get it
  -c, --bytes    bool     false head & tail units are bytes not rows
  -d=, --divide= string   "--"  separator, for non-contiguous case
  -H=, --header= strings  {}    header formats (used cyclically);
                                "" => n==> $1 <==n
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
seq 1 9|tails -h-3 -t-3|tr \\n ' '
```
produces
```
4 5 6
```

A more complete test/example:
```sh
check() {       # Test `tails` modes
  r="$(seq 1 9|tails -d- $1 | tr \\n ' ')"
  [ "$r" = "$2" ] || {
    printf "seq 1 9|tails -s- $1 = \"$r\" != \"$2\": "
    shift 2; echo "$@"; }; }
check "-h3"       "1 2 3 "             h+
check "-t3"       "7 8 9 "             t+
check "-h-3"      "4 5 6 7 8 9 "       h-
check "-t-3"      "1 2 3 4 5 6 "       t-
check "-h3 -t3"   "1 2 3 - 7 8 9 "     h+  t+  discont
check "-h-3 -t3"  "7 8 9 "             h-  t+
check "-h3 -t-3"  "1 2 3 4 5 6 "       h+  t-
check "-h-3 -t-3" "4 5 6 "             h-  t-
check "-h5 -t4"   "1 2 3 4 5 6 7 8 9 " h++ t++ justOvLap
check "-h9 -t9"   "1 2 3 4 5 6 7 8 9 " h++ t++ majorOvLap
check "-h20 -t20" "1 2 3 4 5 6 7 8 9 " h++ t++ majorOvLap
check "-h-5 -t-4" ""                   h-- t-- dropAll
check "-t+4"      "4 5 6 7 8 9 "       tP
```

A terminal example { with terminal no wrap wrapper script sending escape codes
mentioned over in [tw](tw.md) }:
```
nw tails -ft/ log.1 log.2 log.3
```
should show with colorized file name headers (if so configured) as much of the
ends of the logs as fits on one screen, and then follow each one.  You could
cycle background color of text through red, green, blue, etc.

Related Work
------------
For pre-parsed data, there is
https://github.com/c-blake/nio/blob/main/nio.nim#L1014
