Usage:
======
```
  etr [optional-params]

Estimate Time Remaining (ETR) using A) work already done given by did,
B) expected total work as given by the output of total, and C) the age of
processing (age of pid or that produced by the age command).  Commands should
emit a number parsable as a float and times are Unix epoch-origin.  To ease
common use cases:

  pid   given         => default age to age of PID
  did   parses as int => /proc/PID/fdinfo/FD (default total to FD.size)
  total parses as int => /proc/PID/fd/FD.size

Some examples (each assumes only 1 matching pid found by pf):

  etr -p "$(pf x)" -d3 -a'fage SOME-LOG'
  etr -p "$(pf ffmpeg)" -d3 -o4 -m2 -r0 -R.9 -e.01 -kint # Test ratio
  etr -p "$(pf stripe)" -t'ls -1 /DIR|wc -l' -d'grep 7mslot: LOG|wc -l'

Estimation assumes a constant work rate, equal to average rate so far.  If
measure>0.0 seconds etr instead sleeps that long & uses the rate across the
interval (unless did doesn't change across the sleep).  If outp is given,
report includes expected total output byte/byte ratio.  Exit status is 1 if
output:input > RatMin after estMin progress.

Options:
  -p=, --pid=      int    0     pid of process in question
  -d=, --did=      string ""    int fd->fd of pid; string-> cmd for did
  -t=, --total=    string ""    int fd->size(fd); string-> cmd for all work
  -a=, --age=      string ""    cmd for age (age of pid if not given)
  -s=, --scaleAge= float  1.0   re-scale output of age cmd as needed
  -m=, --measure=  float  0.0   measure rate NOW across this given delay
  -o=, --outp=     string ""    int->size(fd(pid)); str->cmd giving out used
  -r=, --relTo=    string ""    emit exp.size : {this float | <=0 to-total}
                                      | str cmd giving such a float
  -R=, --RatMin=   float  1e+17 exit 1 (i.e. "fail") for ratios > this
  -e=, --estMin=   float  0.0   require > this much progress for RatMin
  -k=, --kill=     string "NIL" send this sigNum/Name to pid if >ratio
```

Examples Notes
==============
The examples use `pf` (a symlink to [`procs`](https://github.com/c-blake/procs))
that does `procs find` to get a process ID.  There are both many ways in `pf` to
filter on users, ttys, etc. (& also many other tools like `pgrep` for similar).
Also, as a more informal solution for many similar situations, `procs display`
aka `pd` 'basic' formats with "%< %>" show "IO progress" in terms of pure
aggregate data motion (not percentage done or actual time of completion terms).
The sample-to-sample differential mode (e.g. `pd -d1`) may also be of interest.

The ffmpeg example shows one good use of ratio testing.  The scenario here is
that you are recompressing a video file but want to abort ASAP if the output is
not looking like it's going to be smaller than the input.  (ASAP here is just
`--estMin`.)  So, you can just kill the ffmpeg if `etr` ever exits 1 or use
`etr`'s own --killSig option which does the same thing with the given signal.
Some near identical example for `xz` or `zstd` recompression of `gzip` files is
an exercise for the user. ;) Ratio testing can also avoid output:input explosion
if you need to keep it under 1000 or 10000 or some such.

Naming Note
===========
"Estimated time of arrival" (ETA) and "Estimated time of completion" (ETC) are a
more common names for this, but "arrival" is kind of misleading since arbitrary
work is being measured and "etc" kinda collides with `"/etc"` & variants (e.g.
in a Zsh "autocd" kind of context, yes resolvable with trailing '/', but even
so).  So, I went with "etr".

Portability
===========
While `etr` will compile on almost any system, its use of `/proc` makes it
Linux-only right now.  It may not be hard to generalize this to FreeBSD/OSX.

Related Work
============
https://github.com/Xfennec/progress is a similar "afterthought / external
progress" tool, but hard codes many things `etr` leaves abstract.  So, one can
recreate `progress`-like functionality from `etr` by massaging `ps` output to
generate `etr` commands, but the reverse is not true.  `progress` also has no
output:input ratio testing (or job aborts) and is 10X more lines of code & docs.
