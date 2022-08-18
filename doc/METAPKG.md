To people who say "Tool XYZ is missing", I say "PRs welcome|publish yourself".

To people who say "Tool XYZ is duplicative", I say "Not for me when I wrote it,
but yes, truly exhaustive related research is often harder than writing code.
Anyway, enjoy|not and I am happy to add refs to analogues to per-tool docs."

To people not liking the file tree layout, I agree, but this seemed the easiest
when some code like "bu/eve" is both Nim import-able lib and nimble-installable
binary.  I think nimble micro-manages these things to its detriment.

To people who say "this package is over-bundled", my rejoinder is:

 - Packages package; Pros & cons

 - [`cligen/examples`](https://github.com/c-blake/cligen/tree/master/examples)
   should probably mostly move here, almost doubling the collection as well as
   maybe a dozen or two more I should commit/port from C

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
