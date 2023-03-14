Motivation
==========
Sometimes rather than converting to/from epoch seconds you prefer to embrace the
International Date Line. ;) E.g., often the fastest way to do "date subtraction"
is converting to [rata die](https://en.wikipedia.org/wiki/Rata_Die).  Or a media
player needs input in [[H:][M:]S and you prefer `$(tmath hms 2345)="39:05"` or
worse there are start time/end time/length calcs to toil through.

Since this may be useful as a lib not just as a CLI, the module is under bu/.
This is amongst the least novel code here likely with *many* copies of the core
ideas out in the world, but it's simple enough and I've used it enough over the
last few years that it seemed worth including.

Examples
========
```sh
$ echo $(($(tmath r 2017-06-06)-$(tmath r 2001-01-01)))
6000
$ tmath + 10:20:30 \ -4:5:6
6:15:24
```

Usage
=====
While `tmath h` will dump it all, these subcommands do not take real options,
just lists of what they say they take.  Y4-M-D refers to a date formatted like
2000-1-31 or 1996-07-04.
```
Various calendar & time-of-day math routines that operate directly on broken
down representations with a convenient CLI.

  tmath {SUBCMD}  [sub-command options & parameters]
where {SUBCMD} is one of:
  help      print comprehensive or per-cmd help
  julians   Julian Days for given Y4-M-D Gregorian dates
  dates     Get Gregorian date for a given Julian Day in 8 integer divides
  rataDies  Days since Gregorian 1/1/1 for given Y4-M-D dates (1div, 1cacheLn)
  gregorys  Gregorian dates given days since 1/1/1 (in 4 int divs).
  toHMS     Get all elements of seconds as H:M:S
  seconds   Get all elements of hmses as seconds
  addHMS    H:M:S sum of H:M:S args[0] and H:M:S args[1] (quote "space-")
  +         alias for addHMS
```
