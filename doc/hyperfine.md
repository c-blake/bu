# Why not hyperfine?

I only really include this because of the popularity of this tool and many
references I have seen to its results as "statistically significant
benchmarking".  I think its failings are many and its promoters may be literally
befuddled by the use of the utf8 ± sign which is really quite superficial.  I
wrote this up a couple of years ago, and it's possible the CL tool has evolved
since then, but at the time it had (at least!) these eight problems:[^1]

1. It simply measures the wrong thing.  You want the min, not the mean *unless*
   you are truly trying to assess things like "99% latencies/high quantiles" or
   the whole shape of the distribution in which case you generally need many
   more samples. This is not the goal toward which I have seen the tool applied.

2. It abuses +- / ± notation to NOT be mean ± Δmean, but mean & estimated sample
   standard deviation; Trimming outliers does NOT fix this.  Usual invocation of
   Central Limit Theorem is that means are Gaussian (only 2 param distro shape)
   even when data is not.  This is just to motivate the ± notation / its T-test
   origins.  If you don't like standard error or standard deviation of the mean
   estimate, the T-test equivalent is another argument.  { Real "dt" data tend
   to be heavy enough-tailed to need Levy Stable not Gaussian (or not even IID,
   but needing moving block bootstrap combined w/distributional homogeneity
   tests!) and the classical framework collapses. }

3. Terminal output actually adds noise to measurement.  Flashing isn't free.
   This is a bad default.

4. Outputs are terminal-friendly BUT hard-to-parse, inducing need for
   `--export-FOO`.  Just emitting easy to parse would be better.

5. Poorly advertised heuristic timeLim leading to 3sec of many 1000s of runs.

6. More generally, baked-in time-scale assumptions in both heuristics and
   number of decimals when for real users these things vary from at least
   10s of microseconds to 10s of seconds.

7. Suggests "5 ms" as a lower bound to measurement resolution is mostly an
   artifact of how few decimals he formats floats as (see 5).  I often get
   roughly single digit microsecond errors with `tim` (roughly 100..1000X
   better, in variance terms 10,000 to a million times better) on Linux.
   which is the relevant scale in terms of time to run the bench.  In some
   pretty real sense, the `tim` approach is roughly a million times faster
   for the same accuracy (mostly because it measures something easier to
   get at, but that is largely The Point).

8. Warns about outliers (making his statistical post-processing seem off point
   since "trimming" should remove them.  I've not looked, as Rust makes my eye
   balls bleed, but it's probably a symmetric trimmed mean, not just upper tail
   trimming).  Further, it gives advice to change environmental prep to remove
   fluctuations that I find ineliminable even with care (see 6).  Better advice,
   at least at the time scale of "several ms" is scheduler fiddling (chrt,
   taskset), taking down network interfaces or even better unplugging cables
   and going to single user mode or close to it in terms of background procs.

[^1]: By now it may have either grown more or added some non-default options for
ways to have less.  I make no pretense for up-to-date-ness.
