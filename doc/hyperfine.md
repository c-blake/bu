# Why not hyperfine?

I only really include this because of the popularity of this tool and many
references I have seen to its results as "statistically significant
benchmarking".  I think its failings are many and its promoters may be literally
befuddled by the use of the utf8 ± sign which is really quite superficial.  I
wrote this up a couple of years ago (hyperfine-1.11), and it's possible the tool
has evolved since then, but at the time it had (at least!) these problems:[^1]

1. It simply measures the wrong thing.  You want the min, not the mean *unless*
   you are truly trying to assess things like "99% latencies/high quantiles" or
   the whole shape of the distribution in which case you generally need many
   more samples. This is not the goal toward which I have seen the tool applied.

2. Terminal output actually adds noise to measurement.  Flashing isn't free.
   This is a bad default.

3. Outputs are terminal-friendly BUT hard-to-parse, inducing need for
   `--export-FOO`.  Just emitting easy to parse would be better.

4. Poorly advertised heuristic timeLim leading to 3sec of many 1000s of runs.

5. More generally, baked-in time-scale assumptions in both heuristics and
   number of decimals when for real users these things vary from at least
   10s of microseconds to 10s of seconds.

6. Suggests "5 ms" as a lower bound to measurement resolution is mostly an
   artifact of how few decimals he formats floats as (see 5).  I often get
   roughly single digit microsecond errors with `tim` (roughly 100..1000X
   better, in variance terms 10,000 to a million times better) on Linux.
   which is the relevant scale in terms of time to run the bench.  In some
   pretty real sense, the `tim` approach is roughly a million times faster
   for the same accuracy (mostly because it measures something easier to
   get at, but that is largely The Point).

7. Warns about outliers (making his statistical post-processing seem off point
   since "trimming" should remove them.  I've not looked, as Rust makes my eye
   balls bleed, but it's probably a symmetric trimmed mean, not just upper tail
   trimming).  Further, it gives advice to change environmental prep to remove
   fluctuations that I find ineliminable even with care (see 6).  Better advice,
   at least at the time scale of "several ms" is scheduler fiddling (chrt,
   taskset), taking down network interfaces or even better unplugging cables
   and going to single user mode or close to it in terms of background procs.

For those who might thing "blah, blah..So, what?" here is a vignette showing
how at least hyperfine-1.11 (which has a time stamp of like 2023 for me) is
***6000 times*** less efficient than `tim` and how single digit microsecond
errors are completely do-able: [^2]
```
L2:/dev/shm# hyperfine-1.11 ls
Benchmark #1: ls
  Time (mean ± σ):       0.4 ms ±   0.1 ms    [User: 0.3 ms, System: 0.2 ms]
  Range (min … max):     0.3 ms …   1.9 ms    3868 runs
  Warning: Command took less than 5 ms to complete. Results might be inaccurate.
  Warning: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
*hyperfine-1.11 ls
 Time: 2.188020 (u) + 0.910812 (s)=3.175838 (97%) mxRSS 8 MiB
L2:/dev/shm# $rei tim $tim "/bin/ls>/n"               
184.0 +- 1.4 μs (AlreadySubtracted)Overhead
403.0 +- 5.4 μs /bin/ls>/n
L2:/dev/shm# a (100./5)**2
400.0
L2:/dev/shm# a 3868./256
15.109375
L2:/dev/shm# a 400*15
6000
L2:/dev/shm# echo $rei
chrt 99 taskset -c 2-3 env -i HOME=$HOME PATH=$PATH
L2:/dev/shm# echo $tim
-k2 -o14 -n14 -m14
```

[^1]: By now it may have either grown more or added some non-default options for
ways to have less.  I make no pretense for up-to-date-ness of this critique.
Who knows?  Maybe the author will fix it all and has enough integrity to even
credit `tim`, but I *suspect* it'll always at least default to glitzy animated
terminal junk adding noise to its own measurement as tool marketing propaganda.

[^2]: For those who did not track this estimate, basically it does 15x more runs
for an accuracy 20x worse and accuracy scales with the square of the number of
"independent" runs.  So, 400\*15 = 6000.  The bulk of this improvement is just
from measuring the right thing - namely the minimum duration which is how point
1 earned its first mention spot. ;)
