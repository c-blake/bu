Missing
-------

To people who say "Tool XYZ is missing", I say "PRs welcome|publish yourself".

Duplicative
-----------

To people who say "Tool XYZ is duplicative", I say "Not for me when I wrote it,
but yes, truly exhaustive related research is often harder than writing code.
Anyway, enjoy|not and I am happy to add refs to analogues to per-tool docs."

Layout
------

To people not liking the file tree layout, I agree, but this seemed the easiest
when some code like "bu/eve" is both Nim import-able lib and nimble-installable
binary.  I think nimble micro-manages these things to its detriment.

Over-bundling/Too Many/Mah Head Asplode
---------------------------------------

To people who say "this package is over-bundled", my rejoinder is:

 - Packages package; Pros & cons

 - I did not want to overly bias the nimbleverse toward even more packages
   needing [cligen](https://github.com/c-blake/cligen) (maybe only because I
   wrote both).

 - It's not such a nose-bleed percentile in the context of healthy Unix package
   ecosystems.  Using `qtl` from [fitl](https://github.com/c-blake/fitl), I get:
```sh
(for p in `q list -Iv`;do echo `q files $p|grep /bin/|wc -l` $p;done)|
awk '{if($1>0)print $1}'|qtl .08 .5 .92
```
gives on one of my Gentoo's:
```
1.0 2.008333333333333 14.72363636363637
```
(at the start, anyway, `bu` had 15 bins..so, about 92nd percentile).  Anyway,
util-linux has 73, coreutils has 127 and we will (probably) never get near 200.

[`cligen/examples`](https://github.com/c-blake/cligen/tree/master/examples) will
mostly move here in the near-term because >1 person has complained about that
having too much.  This will almost double the size of the collection.  I should
probably port a dozen or two more from C, but I still consider this all quite
restrained.  I have 1100 scripts & programs in `~/bin` | `/usr/local/bin`.  Most
are not in Nim.  I expect <200 are of "broad" interest or ongoing relevance..a
structural hazard of writing programs over several decades with an eye toward
generality.  Many of them replace|generalize earlier variants.  It is a bit of
work to even curate & better document this (small) collection for what might
interest others.
