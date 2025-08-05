# Motivation
Since time is often spent waiting on long-running jobs, sometimes one wants an
estimate of how much longer there is to wait / an estimated time of completion.
"Job-size" and "progress so far" vary quite a bit across circumstances, but the
actual calculations of rates & time remaining is pretty generic.  So, `etr`
tries to solve just that part of the problem.

# Usage
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

Some examples (assumes 1 matching pid found by pf, but see procs f -1):

  gzip -9 < in > o.gz & sleep 2; etr -p $! -d0 -o1 -m2 -r0
  etr -p "$(pf x)" -d3 -a'fage SOME-LOG'
  etr -p "$(pf ffmpeg)" -d3 -o4 -m1 -R.9 -e.01 -k=kill # Ratio v.Tot
  etr -p "$(pf stripe)" -t'ls -1 /DIR|wc -l' -d'grep 7mslot: LOG|wc -l'

Estimation assumes a constant work rate, equal to average rate so far.
If measure>0.0 seconds etr instead loops, sleeping that long between polls
monitoring progress, maybe killing & exiting on bad ratios.  If outp is given,
report includes expected total output byte/byte ratio.  Exit status is 2 if
output:input > RatMin after estMin progress.

Options:
  -p=, --pid=     int     0     pid of process in question
  -d=, --did=     string  ""    int fd->fd of pid; string-> cmd for did
  -t=, --total=   string  ""    int fd->size(fd); string-> cmd for all work
  -a=, --age=     string  ""    cmd for age (age of pid if not given)
  -A=, --ageScl=  float   1.0   re-scale output of age cmd as needed
  -m=, --measure= float   0.0   measure rate NOW across this given delay
  -o=, --outp=    string  ""    int->size(fd(pid)); str->cmd giving out used
  -r=, --relTo=   string  ""    expctdSz rel.To: { float / ""|<=0 => total }
                                               | str cmd giving such a float
  -R=, --RatMin=  float   1e+17 exit 1 (i.e. "fail") for ratios > this
  -e=, --estMin=  float   0.0   require > this much progress for RatMin
  -k=, --kill=    string  "NIL" run this cmd w/arg pid if ratio test fails
  -l=, --locus=   string  "6"   maker for moving rate location (for ETC)
  -s=, --scale=   string  "0"   maker for moving rate scale (for range)
  -c=, --colors=  strings {}    color aliases; Syntax: name = ATTR1 ATTR2..
  --color=        strings {}    text attrs for syntax elts; Like lc/etc.
```

# Examples Notes
The examples use `pf` (a symlink to [`procs`](https://github.com/c-blake/procs))
that does `procs find` to get a process ID.  There are both many ways in `pf` to
filter on users, ttys, etc. and also many other tools like `pgrep` for similar.
In a pinch, you may be able to use the shell built-in variable `$!` for the PID
of the last *background* process started as shown in the gzip example.

Also, as a more informal solution for many similar situations, `procs display`
aka `pd` 'basic' formats with "%< %>" show "IO progress" in terms of pure
aggregate data motion (not percentage done or actual time of completion terms).
The sample-to-sample differential mode (e.g. `pd -d1`) may also be of interest.

The ffmpeg example shows one good use of ratio testing in monitor/measure mode.
The scenario here is that you are recompressing a video file but want to abort
ASAP if the output is looking like it's going to larger than the input. (ASAP
here is *after* a warm up `--estMin`.)  Besides running `kill`, `etr` also exits
with status 2.  So, you can test that to do whatever else.  Exit 1 can still
happen for other failures like failed commands, /proc files going missing, etc.

Some near identical example for `xz` or `zstd` recompression of `gzip` files is
an exercise for the user. ;) Ratio testing can also avoid output:input explosion
if you need to keep it under 1000 or 10000 or some such.  Any "don't output too
much per input" situation should be easy to adapt.

# Configuration

Configuration is much like [dfr.md](dfr.md).  The format of `~/.config/etr` (or
wherever `ETR_CONFIG` points) is from `std/parsecfg` which is TOML/.ini-like.
A background polarity agnostic config might look like this:
```
color = "done0   italic"    # 0 = prefix/first  = On
color = "done1  -italic"    # 1 = suffix/second = Off
color = "rate0   bold"
color = "rate1  -bold"
color = "left0   inverse"
color = "left1  -inverse"
color = "etc0    bold italic"
color = "etc1   -bold -italic"
color = "ratio0  underline"
color = "ratio1 -underline"
```

# Naming Note
"Estimated time of arrival" (ETA) and "Estimated time of completion" (ETC) are
more common names for this, but "arrival" is kind of misleading since arbitrary
work is being measured and "etc" kinda collides with `"/etc"` & variants (e.g.
in a Zsh "autocd" kind of context, yes resolvable with trailing '/', but even
so).  So, I went with "etr".

# Portability
While `etr` will compile on almost any system, its use of `/proc` makes it
Linux-only right now.  It may not be hard to generalize this to FreeBSD/OSX.

# Related Work
https://github.com/Xfennec/progress is a similar "afterthought / external
progress" tool, but hard codes many things `etr` leaves abstract.  So, one can
recreate `progress`-like functionality from `etr` by massaging `ps` output to
generate `etr` commands, but the reverse is not true.  `progress` also has no
output:input ratio testing (or job aborts) and is 10X more lines of code & docs.
