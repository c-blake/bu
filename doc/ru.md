I wrote this because /usr/bin/time is very low time resolution (10 ms) with a
very hard to read default format and for a very long time (early 90s?) various
OSes have provided better.  When faced with the question "What is CPU?", perhaps
the getrusage/wait4 answer of `ru` can be a first step.

```
Usage:

  ru [-whatiscpu] <prog> [prog args...]

No options => as if -hit; else selected subset.

Flags all in arg 1 & mean:
  w  w)rapped output without row labels (to get fields by row, e.g. grep)
  h  h)uman readable formats with (h)our:minute:seconds, MiB, etc. units
  a  a)ll of the below, in the same order
  t  t)ime,mem (wall, user, system time, CPU utilization, max Resident)
  i  i)o (inBlocks, outBlocks, swaps, majorFaults, minorFaults)
  s  s)witch/stack/sharing (volCtxSw, involSw, stack, txtResShr, datResShr)
  c  interprocess (c)ommunications (signals, IPC sent, IPC received)
  p  p)lain output (no ANSI SGR color escapes)
  u  u)nwrapped output with field labels (to get fields by column, e.g. awk)
```

`man getrusage` | `man time` give more details on the various stats this small
Nim program can print.

You can put options in the `RU` environment variable.  Compared to time(1), this
is higher precision with more modern and controlled units.
