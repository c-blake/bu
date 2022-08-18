```
Usage:

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
  etr -p$(pf ffmpeg) -d3 -m5.0
  etr -p$(pf x) -d3 -a'fage -qfm -rm -RLOG-FILE /MISSING'
  etr -p$(pf stripe) -t'ls -1 /DIR|wc -l' -d'grep 7mslot: LOG|wc -l'

Estimation assumes a constant work rate, equal to the average so far and that
"units" of work are consistent between "total" and "did".

If you give a measure > 0.0 seconds that will instead use the *present* rate
over that measurement window (unless there is no change in did across the
measurement).

Options:
  -p=, --pid=      int    0   pid of process in question
  -d=, --did=      string ""  int fd->fd of pid; string-> cmd for did
  -t=, --total=    string ""  int fd->size(fd); string-> cmd for all work
  -a=, --age=      string ""  cmd for age (age of pid if not given)
  -s=, --scaleAge= float  1.0 re-scale output of age cmd as needed
  -m=, --measure=  float  0.0 measure rate NOW across this given delay
```

Naming Note
-----------

"Estimated time of completion" is a more common term for this, but "etc" kinda
collides with `"/etc"` & variants in a Zsh "autocd" kind of context, yes
resolvable with trailing '/', but even so).  So, I went with "etr".
