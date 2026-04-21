# Motivation
This program is mostly an approximately 4X optimization over the easy `mawk`
1-liner:
```awk
{
  i = index($0, "\t")
  cmd = i ? substr($0, i+1) : ""
  if (!did[cmd]++) print
}
```
We generalize it a bit along the way to avoid the need for `tac -s "" |`
and to allow any strictly delimited columns.

The reason this mattered to me was the particular 4X was from 500 ms to 125 ms
in the context of my new "infinite Zsh history" `vip` viewing.  This timescale
for me was from very noticeable to barely noticeable.  It might not be noticed
by many people but for long-time experience with instant Ctrl-R.

# Usage
```
  k1st [optional-params] 

Write stdin rows in-order k)eeping only first keyI-unique rows.  Eg.:

  < $z/history tac -s "" | k1st -t\\0 -d\\1 -k1 | vip ...
  k1st -rt\\0 -d\\1 -k1 < $z/history | vip ...

  -s=, --size=  int       999   entry pre-size of table
  -b=, --bSize= int       9999  byte pre-size of unique data;Unseekable stdin
  -t=, --term=  char      '\n'  input row terminator byte
  -d=, --delim= char      '\t'  input column delimiter byte
  -k=, --keyI=  int       0     index of unique key column
  -T=, --TMLim= int       100   min distance between truncation msgs
  -r, --rev     bool      false go backwards from EOF; Seekable stdin
  -m=, --msgs=  set(Msgs) {}    emit to stderr: missing, summary, time
```

# Testing
```sh
$ (paste <(seq 4 -1 0) <(seq 0 4);paste <(seq 4 -1 0) <(seq 0 4))|k1st -k1
4       0
3       1
2       2
1       3
0       4
```

# Related Work
See also [zeh.md](zeh.md), [vip.md](vip.md).
