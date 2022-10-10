Motivation
----------

Many processes in a system can create duplicate files.  These (usually) waste
space, but at the very least one often wants to "map out" such duplication.

`lncs` lets you map out varying names for the same i-node.  This utility lets
you map out clusters of i-nodes with exactly duplicate data (under the name of
the first found hard link for a file).

This was the original `cligen/examples` utility program.  There are many open
source tools like this out on the internet.  One tool author even popped up
on a [cligen issue thread](https://github.com/c-blake/cligen/issues/99).
This one is pretty efficient.  I continue to benchmark it as ~2X faster than
jdupes in a fully RAM-cached test case, but for uncached use cases it is of
course very dominated by IO speed/organization.

A related case is *near* duplicate data, but that deserves [its own github
repo](https://github.com/c-blake/ndup).

Usage
-----

```
  dups [optional-params] [paths: string...]

Print sets of files with duplicate contents. Examined files are UNION of paths &
optional delim-delimited input file ( stdin if "-"|if ""& stdin not a tty ).

E.g.:
    find -type f -print0 | dups -d\\0.
Exits non-0 if a dup exists.

Trusting hashes can give false positives, but sorting can be slow w/many large
files of the same size|hash. slice can reduce IO, but can also give false pos.
{False negatives not possible. 0 exit => surely no dups.}.

Within-set sort is by st_blocks if summ is logged, then by requested file time
{v=max(m,c)} & finally by st_ino.

Options:
  -f=, --file=    string  ""    optional input ( "-" | !tty = stdin )
  -d=, --delim=   char    '\n'  input file delimiter; \0 -> NUL
  -r=, --recurse= int     1     recurse n-levels on dirs; 0: unlimited
  -F, --follow    bool    false follow symlinks to dirs in recursion
  -x, --xdev      bool    false block cross-device recursion
  -D, --Deref     bool    false dereference symlinks
  -m=, --minLen=  int     1     minimum file size to consider
  -s=, --slice=   string  ""    file slice (float|%:frac; <0:tailRel)
  -H=, --Hash=    Digest  wy    hash function [size|wy|nim|SHA1]
  -c, --cmp       bool    false compare; do not trust hash
  -j=, --jobs=    int     1     Use this much parallelism
  -l=, --log=     set(Lg) osErr >stderr{ osErr, summ }
  -b, --brief     bool    false do NOT print sets of dups
  -t=, --time=    string  ""    sort each set by file time: {-}[bamcv].*
  -o=, --outDlm=  string  "\t"  output internal delimiter
  -e=, --endOut=  string  "\n"  output record terminator
```
