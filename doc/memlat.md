A little utility to measure latency at various levels of the memory hierarchy.
Only READ/load latency right now, though.

This was basically inspired by the discussion here (forum.nim-lang.org seems
to no longer render many historical posts - sorry - that is one reason why
I am re-posting this code here):

    https://forum.nim-lang.org/t/5734#35832

as well as some lame arguments about cache locality in the context of very hard
to measure cold-cache (& cold branch predictor) hash tables where vanilla linear
probing basically always wins (sometimes by a lot) in spite of the fact that hot
everything L1 micro-benchmarks can make it seem like "pseudorandom probing" can
have a (small, probably not CPU-portable) edge.

The `--kind=ranElt` and `=truRan` tests here basically emulate hash lookups
while the `--kind=shuff` emulates cold cache memory loads (but branch predictors
are still hot cache) or a load pattern more like hopping a long linked list or
a very deep tree.

This utility (in shuffle mode) is actually not so bad a way to measure memory
systems against each other at various data scales.  I see a great deal of
variation in main memory/DIMM latencies which are not (often) covered in
marketing speak like "DDR-N", but often very impactful on performance.

```
Usage:
  lat [optional-params] 
Time latency three ways. shuffle measures real latency.
  -k=, --kind=    Algo shuff   shuff: chase ran perm
                               ranElt: access ran elt
                               truRan: pre-read getrandom
  -s=, --sizeKiB= int  1048576 set sizeKiB
  -n=, --nAcc=    int  1000000 set nAcc
  -a=, --avgN=    int  4       set avgN
  -m=, --minN=    int  4       set minN
  --seed=         int  0       0=>random, else set
```
