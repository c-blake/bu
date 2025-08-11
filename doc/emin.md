# Motivation / Example / Usage

Sometimes a program spends a non-negligible time doing set up before some inner
phase which is what you want to time.  For this, [`tim`](tim.md) is
inappropriate since there is more "overhead" to subtract than shell overhead,
yet [`eve`](eve.md) seems more general than desirable, since you might still be
using [`tim`](tim.md) to drive the experiment.  So, for the case when you really
just have a list of numbers in "tim-compatible layout" (Re: `--warmup`, `--k`, `--n`,
`--m`), it's nice to say something like this:

```
tim="-k2 -o14 -n14 -m14"
tim $tim "$prog 2>>/tmp/dts"
emin $tim `</tmp/dts`
```
where $prog is some program that emits a single delta-time value. More formally,
since $prog decides what number it prints out which could be something other
than wall time, this can estimate the true minimum of anything you'd like to
estimate the minimum of which varies in a way you'd like to model as "random",
such as memory used.
