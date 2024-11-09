Motivation
----------
Since data sets can be large, random fair subsets/re-samplings can be useful.

https://en.wikipedia.org/wiki/Reservoir_sampling has more details.  Note that
the cost comparison there between Algorithm R & L neglects IO costs which are
around 50+% dominant for this little utility even on a RAM filesystem (just from
`memchr` for line splitting even on very short lines).  So, rather than the big
O(n/k)-ish asymptotic speed-up factor, Algorithm L is likely only <~ 2X faster,
at least with the `.add` API of `bu/rs.nim`.

The random sampling with replacement algorithm is quite slow and should be
replaced, but to detail its logic here, all slots in the reservoir table evolve
identically & independently, and the evolution of the first slot looks like:
```
data   1    2    3    4    5 ... N
slot0  1 -> 1 -> 1 -> 1 -> 1 ... N, p=1/2*2/3*3/4*4/5*...=1/N
slot0       2 -> 2 -> 2 -> 2 ... N, p=    1/3*3/4*4/5*...=1/N
slot0            3 -> 3 -> 3 ... N, p=        1/4*4/5*...=1/N
```
So, each slot has a similar 1/N independent chance of surviving until the end.

Some care was put into the command-line API here, in particular the ability to
`--flush` the outputs to give immediate reads to possible FIFO workers.  Also,
you can create as many random subsets/samples of whatever various sizes as you
like in various files rather easily by just listing them.

Usage
-----
```
  rs [optional-params] [pfx.][-]n.. output paths; pfx""=>stdout

Write ranSubsets|Samples of rows of input -> prefix.ns.  If n>0 do random
subsets else sample with replacement.  O(Σns) space.  Examples:

  seq 1 100 | rs 10 .-5 or (after maybe mkfifo f1 f2)
  wkOn f1 & wkOn f2 & seq 1 1000 | rs -f f1.10 f2.-20

Options:
  -i=, --input=   string "" "" => stdin
  -f, --flush     bool      write to outs immediately
  -r, --randomize bool      randomize() for non-deterministic filtering
```

Examples
--------
Input:
```sh
seq 1 1000 | rs foo1.9 foo2.9 foo3.9 foo4.9
for f in foo*; do cstats q.5 < $f; done
```
Output:
```
281.0
442.0
370.0
591.0
```
