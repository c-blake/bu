Overview
--------

This is a collection of miscellaneous utilities I've written over the years.
Their motivation/scope spans from nearly trivial access checking of `okpaths` to
nascent attempts or atoms of Big Things like map-reduce in shell or extreme
value estimation for benchmark time cleaning.  All are tools I use in one way or
another with some regularity which I thought others might find useful.  There is
a general vibe similar to [util-linux](https://en.wikipedia.org/wiki/Util-linux)
or [moreutils](https://www.putorius.net/moreutils.html).

System Administration on Unix/POSIX/Linux
-----------------------------------------

[dfr - colorful `df`](doc/dfr.md)

[fsids - histogram uid/gids in use](doc/fsids.md)

[cbtm - ctime/btime save/restore utility](doc/cbtm.md)

[thermctl - try to prevent thermal CPU shutdown](doc/thermctl.md)

[lncs - analyze a file tree for hard link structure](doc/lncs.md)

[pid2 - Wrap Linux process PID table to first past target](doc/pid2.md)

[sr - System Request Key - rapidly act on Linux systems](doc/sr.md)

Miscellaneous Shell Utilities
-----------------------------

[okpaths - trim inaccessible filesystem paths](doc/okpaths.md)

[align - like BSD/GNU columns but sometimes more convenient](doc/align.md)

[tails - nice for *both* head & tail (or "middle")](doc/tails.md)

[jointr - join strace output to make it easier to read](doc/jointr.md)

[stripe - run jobs in parallel with slot key variables/sequence
numbers](doc/stripe.md)

[tattr - terminal attribute access (like cligen/humanUt)](doc/tattr.md)

[notIn - Helper to manage semi-mirrored file trees](doc/notIn.md)

[ft - file typer {i-node type, not file(1)/libmagic(3) type}](doc/ft.md)

[fage - file age according to various timestamps/rules](doc/fage.md)

[chom - Enforce group owner & segregated perms in file trees](doc/chom.md)

[du - Slight improvement on GNU du](doc/du.md)

[rr - Mostly a short alias for rm -rf but also faster](doc/rr.md)

[dups - Fast finder of exact duplicate files](doc/dups.md)

[only - file(1)/libmagic tool to emit files whose types match](doc/only.md)

[fkindc - file(1)/libmagic tool to histogram file types](doc/fkindc.md)

[dirq - Kind of its own system-building atom thing](doc/dirq.md)

[dirt - Recursively set dir time stamp to oldest of members](doc/dirt.md)

[newest - b-time supporting \`find -printf|sort|tail\`](doc/newest.md)

[since - b-time supporting \`find -Xnewer\`](doc/since.md)

[cols - extract just some columns from a text file/stream](doc/cols.md)

[rp - A row processor program-generator maybe replacement for AWK](doc/rp.md)

[crp - C row processor program-generator port of `rp`](doc/crp.md)

[ww - Dynamic programming based word wrapper](doc/ww.md)

[cfold - Context folding (like csplit but wrap lines)](doc/cfold.md)

[unfold - an oft neglected inverse-to-wrapping process](doc/unfold.md)

[funnel - A reliable, record boundary respecting "FIFO funnel](doc/funnel.md)

[wsz - Report terminal size in cells, pixels, and cell size](doc/wsz.md)

[saft - SAve&Restore File Times across a command operating on them](doc/saft.md)

Benchmarking Related Utilities
------------------------------

[memlat - measure memory latency at various size scales](doc/memlat.md)

[fread - Like `cat` but just read data (no writes)](doc/fread.md)

[ru - resource usage of a monitored program](doc/ru.md)

[etr - estimated time remaining/to completion](doc/etr.md)

[eve - extreme value estimator (e.g. *true* min time of an infinite
sample)](doc/eve.md)

Meta-Commentary
---------------

Every tool has a help message hopefully useful enough to be mostly autonomous or
at least a good reminder of its own README in doc/TOOLNAME.md.  I should write
some man pages starting with help2man, but AFAICT, nimble, will not install them
anyway (there's no mention of the whole word "man" on any issue, PR, or anywhere
in the VC history of nimble, nor any default target one could add to `MANPATH` |
`/etc/man*.conf`).  Many doc/TOOLNAME.md's should grow more complete/better
example usages.  I tried to keep the source code scrutable, but also to the
point and doc PRs are always very welcome.  Though we all try, there is no real
substitute for initial confusion.  Some packaging meta-commentary is
[here](doc/METAPKG.md).
