Overview
--------

This is a collection of miscellaneous utilities I've written over the years.
Their motivation/scope spans from nearly trivial access checking of `okpaths` to
nascent attempts or atoms of Big Things like map-reduce in shell or extreme
value estimation for benchmark time cleaning.  All are tools I use in one way or
another with some regularity which I thought others might find useful.  There is
a general vibe similar to [util-linux](https://en.wikipedia.org/wiki/Util-linux)
or [moreutils](https://www.putorius.net/moreutils.html).  A great many are Unix
only tools, but some may be more cross-platform.

File Typology (What/Whether)
----------------------------

[ft - file typer {i-node type, not file(1)/libmagic(3) type}](doc/ft.md)

[only - file(1)/libmagic tool to emit files whose types match](doc/only.md)

[fkindc - file(1)/libmagic tool to histogram file types](doc/fkindc.md)

[notIn - Helper to manage semi-mirrored file trees](doc/notIn.md)

[catz - Generalize `zcat` to many encodings, not merely `gzip`](doc/catz.md)

Space Management (How Much/Where)
---------------------------------

[dfr - d)isk fr)ee; `df` with color coding & modern units](doc/dfr.md)

[lncs - analyze a file tree for hard link structure](doc/lncs.md)

[du - Slight improvement on GNU du](doc/du.md)

[rr - Mostly a short alias for rm -rf but also faster](doc/rr.md)

[dups - Fast finder of exact duplicate files](doc/dups.md)

[fpr - File Pages Resident reporting utility like fincore](doc/fpr.md)

File Time Related (When)
------------------------

[cbtm - Back up & restore new Linux b-time stamps (creation/birth)](doc/cbtm.md)

[dirt - Recursively set dir time stamp to oldest of members](doc/dirt.md)

[fage - file age according to various timestamps/rules](doc/fage.md)

[newest - b-time supporting \`find -printf|sort|tail\`](doc/newest.md)

[since - b-time supporting \`find -Xnewer\`](doc/since.md)

[saft - SAve&restore File Times across a command operating on them](doc/saft.md)

[tmath - Convert/do arithmetic directly upon date & time formats](doc/tmath.md)

[mk1 - Very fast `make` for many 1-to-1 input-output mappings](doc/mk1.md)

Benchmarking Related Utilities (How Long)
-----------------------------------------

[memlat - measure memory latency at various size scales](doc/memlat.md)

[fread - Like `cat` but just read data (no writes)](doc/fread.md)

[ru - Resource Usage measurement { high-res/nicer time(1) }](doc/ru.md)

[etr - e)stimate t)ime r)emaining using subcommands for %done](doc/etr.md)

[eve - Extreme Value Estimator (e.g. *true* max|min of an infinite sample)](doc/eve.md)

[tim - Uncertain time comparison via repeated sampling & `eve`](doc/tim.md)

[edplot - Generate EDF & its confidence bands files & plot scripts](doc/edplot.md)

[keydowns - Assess string complexity in terms of a human cost](doc/keydowns.md)

Row/Column/Text Table Things
----------------------------

[align - align text with better ergonomics than BSD `column`](doc/align.md)

[flow - flow text lines into as many columns as fit with aligned output](doc/flow.md)

[tails - Terminal-friendly & generalized head & tail](doc/tails.md)

[cols - extract just some columns from a text file/stream](doc/cols.md)

[rp - A row processor program-generator maybe replacement for AWK](doc/rp.md)

[crp - C row processor program-generator port of `rp`](doc/crp.md)

[colSort - Sort *within* the columns of rows](doc/colSort.md)

[cstats - preserve Context/Compute Column stats filter](doc/cstats.md)

Freeform Text Things
--------------------

[noc - stdin-out filter to strip ANSI CSI/OSC/SGR color escape seqs](doc/noc.md)

[tw - terminal-width clip/cropper with m-row bounding capability](doc/tw.md)

[cfold - Context folding (like csplit but to wrap lines)](doc/cfold.md)

[unfold - Oft neglected inverse-to-wrapping/folding process](doc/unfold.md)

[ww - Dynamic programming based word wrapper](doc/ww.md)

[widths - Compute & emit line widths/lengths | distro](doc/widths.md)

[jointr - join strace "unfinished ..." with conclusion](doc/jointr.md)

[ndelta - Numerical difference between two reports utility](doc/ndelta.md)

[tmpls - A fast string template interpolater](doc/tmpls.md)

Pipeline Calculation Tools
--------------------------

[topn - Fast streaming 1-pass top-N over M columns](doc/topn.md)

[oft - Approximately most often items via a low-memory algorithm](doc/oft.md)

[uce - Unique/distinct Count Estimate via a low-memory algorithm](doc/uce.md)

System Administration on Unix/POSIX/Linux
-----------------------------------------

[holes - count/map hole & data segments of files](doc/holes.md)

[fsids - file system user & group id histogram](doc/fsids.md)

[chom - Enforce group owner & segregated perms in file trees](doc/chom.md)

[thermctl - Thermal Control for before CPU makers thermally throttled](doc/thermctl.md)

[pid2 - Wrap Linux process PID table to first past target](doc/pid2.md)

[sr - System Request Key - rapidly act on Linux systems](doc/sr.md)

Tty Handling
------------

[tattr - Terminal attribute access (like cligen/humanUt)](doc/tattr.md)

[wsz - Report terminal size in cells, pixels, and cell size](doc/wsz.md)

Miscellaneous/Islands Unto Themselves
-------------------------------------

[noa - "--"-aware Python-like indexing of non-option arguments](doc/noa.md)

[okpaths - Validate/trim PATH-like vars by probing the system](doc/okpaths.md)

[nrel - Edit .nimble version, commit, tag, push & maybe release](doc/nrel.md)

[dirq - Kind of its own system-building atom thing](doc/dirq.md)

[funnel - A reliable, record boundary respecting "FIFO funnel"](doc/funnel.md)

[stripe - Run jobs in parallel w/slot key vars/seqNos/shell elision](doc/stripe.md)

[bu/rs- Reservoir Subset/Sampler Of Lines In A File/[T] library](doc/rs.md)

[wgt - Weighted random sampler with fancy weighting](doc/wgt.md)

[zipf - Random samples according to Zipf distribution](doc/zipf.md)

[niom - nio moments w/hard dep on adix efficient histogram/quantiles](doc/niom.md)

[ac - aped commands with aping rules stored in local file tree](doc/ac.md)

Meta-Commentary
---------------

Every tool has a help message hopefully useful enough to be mostly autonomous or
at least a good reminder of its own README in doc/TOOLNAME.md.  I should write
some man pages starting with help2man, but AFAICT, nimble, will not install them
anyway (there's no mention of the whole word "man" on any issue, PR, or anywhere
in the VC history of nimble, nor any default target one could add to `MANPATH` |
`/etc/man*.conf`).  Many doc/TOOLNAME.md's should grow more complete/better
examples.  I tried to keep the source code scrutable, but also to the point.
Doc PRs are always welcome.  Though we all try, there is no substitute for
initial confusion resolving at improving docs).  Some packaging meta-commentary
is [here](doc/METAPKG.md).
