Description
-----------

`stripe` is parallelization/rudimentary job distribution utility and its library
optimization nano-shell module `bu/execstr`.  It only runs 1 command at a time.

When commands fit into the restricted nano-shell language, this is about as low
overhead as any new ELF/executable process creating tool can be (which, yes,
remains about 50-100X worse than just fork|`cligen/procpool`).

```
Usage:

  stripe [optional-params] [posArgs: string...]

where posArgs is either a number <N> or <sub1 sub2..subM>, reads job lines from
stdin and keeps up to N | M running at once.

In sub mode, each job has $STRIPE_SUB set, in turn, to subJ.  Eg.:

  find . -printf "ssh $STRIPE_SUB FileJob '%P'\n" | stripe X Y

runs FileJobs first on host X then on host Y then on whichever finishes first.
Repeat X or Y to keep more jobs running on each host.

$STRIPE_SLOT (arg slot index) & optionally $STRIPE_SEQ (job seqNum) are also
provided to jobs.  In N-mode SIGUSR[12] (in|de)creases N.  If before uses $tot,
job lines are read upfront to provide that count.

  -r=, --run=    string "/bin/sh" run job lines via this interpreter
  -n, --nums     bool   false     provide STRIPE_SEQ to job procs
  -s=, --secs=   float  0.0       sleep SECS before running each job
  -l=, --load=   int    -1        0/1/2: 1/5/15-minute load average < N
  -b=, --before= string ""        "D": $tm \e[1mslot: $nm $cmd\e[m
                                  alsoAvail: $seq $tot
  -a=, --after=  string ""        "D": $tm \e[7mslot: $nm usr: $u sys: $s\e[m
                                  alsoAvail: wall $w MiBRSS $m $ct $pcpu $cmd
  -i=, --irupt=  string ""        "D": $tm interrupted $nm after $w: $cmd
                                  alsoAvail: substitution $sub
```

There is no need for `STRIP_SUB` to be ssh targets.  Any regular pool of work
labels will do.  For example, you could do a 2-way or 4-way tile of images with
some dispatcher savvy about screen-halves/quadrants/etc.

Related Work
------------

There are almost too many to even begin mentioning.  The closest is probably
`xargs -n1 -P9 --process-slot-var=STRIPE_SUB`, but that doesn't provide sequence
numbers.  (You may be able to work around that e.g. with e.g. `EPOCHREALTIME` or
other unique Ids.)  Mostly I like my job log format, `execstr` shell-avoidance
optimization, and the C version of this dates back to the very early 00s, long
before `xargs` even had `-P` never mind 2012's `--process-slot-var`.  I also
like not having to worry about shell array portability to convert from a numeric
process-slot-var to string keys.  This is all trivial enough that it's probably
been done many times by many folks to suit their idiosyncratic tastes.

Anyway, "chunks" of work need to be >30-100 microsec for this to make sense[^1].
If per-job code is shell-ish, you may be able to do a lower overhead (fork scale
rather than exec scale) system with `wait -n` added to Bash in 2014, IIRC.

[^1]: or even larger if a real shell launch per command is involved..
