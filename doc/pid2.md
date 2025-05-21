# Basics

Usage: (***NOT*** a cligen utility)
```
pid2 [integer(300)]
```
The [] notation here indicates optionality and default is in ().

This program just does `vfork()` as fast as possible to wrap a Linux process
table until the target Process ID integer is reached.

# Motivation

PID-wrapping was made famous more as a hacking tool for programs which foolishly
assume the next PID is neither predictable nor re-used (e.g. a shell /tmp/foo.$$
construct).

I am publishing it here mostly as an example of a big effect that OS scheduling
affinity for a particular CPU can make.  It can also sometimes be nice to
"position" within the process table if you often do PID-sorted process table
listings..(e.g. to group all your xterms or shells together).

# Speed-up

For even greater speed, you can do this in parallel with each pid2 pinned
to different CPUs, such as a wrapper script (called, say, `2pid`):

```sh
: "${j:=$(nproc)}"
for k in `seq 0 "$((j-1))"`
do pid2 "$@" "$k" & done
wait
```
Even with `2^22` pids (default lately), this can take under 8 sec on my laptop.
Most people I know are unfamiliar with how fast the PID counter can advance
under heavy fork load.

# Regrets, I have a few..

In 1979 when Berkeley introduced `vfork` on the VAX 11/780, they should have
made PIDs 32-bits.  At the time, it was about 3..8ms to `vfork` meaning 32768
wraparounds could take just a few minutes.[^1]  Meanwhile, 32-bit would have
been 6..18 months doing almost nothing but `vfork` -- likely easily noticed /
trapped activity right up until about the 64-bit moves in the late 90s.  PIDs
then could have been "unique ids" from the dawn of Unix & very likely moved to
64-bit ids by the late 90s which (in 2025) would still be fine unique IDs for
the foreseeable future.  Oh well!

As it is, today a `pid_max<default` on Linux of 10,000 allows lapping tables in
as little as 20 ms.  Even a default `pid_max` of 32768 yields ~17 laps/sec -
likely not even reliably trapped by logs with 1-second resolution timestamps.

Meanwhile, Linux, at least, grew hackish yet still racy workarounds like pidfd's
that are at best a WIP (eg. no scheduler interfaces by pidfd; *Only* a pidfd API
for `process_madvise`).  pidfdfs itself caused [two user-space regressions in
2024](https://lwn.net/Articles/976125/).  And on & on.  Those new APIs are also
unlikely to ever be portable.  And so, re-used small PID chaos continues.[^2]

[^1]: Arguably, the Bell Labs guys at around 20..50 ms/fork faced wrapping in
as little as 10 hours and were already lame for making PIDs signed 16 bit nums.
32-bit longs also date back to the dawn of Unix & C.  There is plenty of blame
to go around, I suppose.

[^2]: 32-bits in the 70s & 80s and 64-bits today might still remain vulnerable
to PID *predictability* problems, of course, for which the simplest compatible
solution is to just make PIDs both larger/un-reused *and* unpredictable.  Int64-
keyed hash tables and `/dev/random` are needed anyway.  It's conceivable some
non-statistical-*guarantee*-to-be-unused-in-the-past-"many IDs" might also be a
useful property, but as this program shows - at billions per hour, in order to
truly proxy for useful real-time gaps that "many IDs" could be surprisingly big!
