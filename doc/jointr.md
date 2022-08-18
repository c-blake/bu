Motivation
----------

This is utility to make it easier to read `strace -f` output.  If you do
something like
```sh
strace --decode-fds -fvs8192 -oFoo multi-process-program
```
and there is significant clone/fork spawning then you are likely to see
a great many system calls which are reported twice - once at initiation,
are then suspended and then again at resumption.

The problem with this is that there can be a lot of other intervening text
between these two points and the parameters of the initial call are not repeated
by `strace` upon resumption.

So, what `jointr` does is act as a filter to either stitch the two halves
together or at least repeat the call parameters at the continuation to help
make sense of things.

Never resumed calls are just printed in hash order at the bottom.

Usage
-----

```
Usage:
  jointr [optional-params] strace log path (or none for stdin)

  -c=, --cont=  string " <unfinished ...>" line suffix saying it continues
  -b=, --boc=   string "<... "             beg of contin. indication to eat
  -e=, --eoc=   string " resumed>"         end of contin. indication to eat
  -a, --all     bool   false               retain "unfinished ..." in-place
```
