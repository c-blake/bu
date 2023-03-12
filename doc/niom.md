Motivation
==========
This little 50-liner mostly only exists & lives here since I try to keep some
core library packages like `cligen`, `adix, and `nio` hard-dependency-free.[^1]

Usage
=====
```
  niom [optional-params] [paths: 1|more paths to NIO files]
Print selected statistics over all columns of all paths.

  -f=, --fmt=   string       ".4g"   Nim floating point output format
  -s=, --stats= set(MomKind) min,max n min max sum avg sdev skew kurt histo
  -q=, --qs=    floats       {}      desired quantiles
  -a=, --a=     float        1e-16   min absolute value histo-bin edge
  -b=, --b=     float        1e+20   max absolute value histo-bin edge
  -n=, --n=     int          8300    number of lg-spaced histo bins
```

An Example
==========

```sh
$ zipf -n10_000_000 -fbg 1..3 | niom -s,= -sh .Nl
.Nl:0 n: 8300   a: 1e-16        b: 1e+20
aLn: -36.841361487904734        h: 0.00998831947798357  hInv: 100.11694181430796
bins,cnts:
  [ -1e-16 , 1e-16 ): 6467866
  [ 0.9955705858181852 , 1.0055644909629682 ): 2287419
  [ 1.9832854562249305 , 2.003194407942553 ): 1244715
totalCount: 10000000 nonZeroBins: 3
```
Note that (2287419/6467866)**-(2./3) = 1.999601833743278, thus also a spot check
of [zipf](zipf.md) with a default alpha=3/2.

[^1]: If someone is living life with a few git clone's per year they are still
cool to try out my packages even if `nimble` fails them.
