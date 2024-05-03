Background
==========
Often one has some program/operation of interest that takes 1..500 milliseconds.
One may want to time it to use as a benchmark.  While computers are conceptually
deterministic, in practical settings on general purpose OSes[^1] asynchronously
interacting with physical devices, all you can really measure is:

(1) `observed_time = tDesired + tBackground(noise)`

Even with no time-sharing, peripheral interactions[^2] degrade determinism
motivating a random model for `tBackground` and the name "noise".  **`t0` is
often what you want** because background activity and precise synchronization of
load-based CPU dynamic frequency scale-up simply does not reproduce to other
milliseconds / minutes / days / environments.  Understanding begins with
reproduction.[^3]

This seems like a "statistics to the rescue" scenario, but caution is warranted.
In most deployments, `tBackground` from Eq.1 is both time varying
([non-stationary](https://en.wikipedia.org/wiki/Stationary_process)) and
[heavy-tailed](https://en.wikipedia.org/wiki/Heavy-tailed_distribution) due to
**imperfect control over competing load**.  Both properties make both value &
error estimates of **flat averages including ALL OF `noise` mislead**.  Central
measures like the mean (& median) are likely dragged way up.  Errors in the
means just explode.  Neither converge as you might think from [Limit
Theorems](https://en.wikipedia.org/wiki/Central_limit_theorem).  Non-stationary,
**non-independent** noise violates base assumptions of most applied statistics.
Even trimmed / outlier-removed averages risk confusing signal & noise (though
sometimes the noise *is* the signal[^3]).

Solutions
=========
A **0-tech** approach is to declare differences less than 2-10X "uninteresting".
While not invalid, **practical difficulty** remains.  You cannot always control
what other people find "interesting".  It's also not rare that "interesting"
deltas can be composed of improvement with many smaller stages which then still
need a solution.  Truly cold-cache times often have far bigger deltas relative
to hot than any proposed range.

The scale of `noise` compared to `t0` can vary considerably.  A popular approach
is to avoid sub-second times entirely, making benchmarks **many seconds long**
to suppress `noise`.  Sometimes people "scale up" naively[^4] to get hard to
interpret &| misleading results.  Since it is also rarely clear how much scaling
up is "enough" anyway or what the residual noise scale is, this can **compound**
waiting time for results via several samples of longer benchmarks.  Maybe we can
do better than 0-tech!

---

A low tech way to estimate reproducibly Eq.1's `t0`, in spite of hostile noise,
is a simple sample minimum.  This **filters out all but noise(minimum)** -
far better behaved than average noise.[^5]

However, this gives no uncertainty to the estimate for principled comparisons
among alternatives.  To get a population minimum without error, one needs an
**infinite** number of trials.  We instead want to economize on repetitions.

A low art way to estimate the error on the sample min `t0` estimate is to find
the mean,sdev for the best several times out of many runs to approximate the
error on the sample min.[^5] Differences between two smallest times or various
statistical formulae or nesting with sample stats on min(several) are surely
possible, but these all share a problem: the population-min is guaranteed to be
less than any sample min.

One can be a bit more sophisticated and use the Fraga Alves-Neves estimator[^6]
for the true endpoint to try to extrapolate.  This is always < sample min.
Repeated sampling of smaller windows to estimate its uncertainty is what `tim`
does presently.

Usage
=====
```
  tim [optional-params] 'cmd1' 'cmd2' ..

Time shell cmds. Finds best k/n m times.  Merge results for a final time & error
estimate.  doc/tim.md explains more.

Options:
  -w=, --warmup=  int     1     number of warm-up runs to discard
  -k=, --k=       int     2     number of best tail times to use/2
  -n=, --n=       int     7     number of inner trials; 1/m total
  -m=, --m=       int     3     number of outer trials
  -o=, --ohead=   int     7     number of "" overhead runs;  If > 0, value
                                (measured same way) is taken from each time
  -s=, --save=    string  ""    also save TIMES<TAB>CMD<NL>s to this file
  -r=, --read=    string  ""    read output of save instead of running
  -p=, --prepare= strings {}    cmds to run before corresponding cmd<i>s
  -c=, --cleanup= strings {}    cmds to run after corresponding cmd<i>s
  -v, --verbose   bool    false log parameters & some activity to stderr
```

Example / Does It Work?
=======================
Let's see by running it 3 times and comparing results!  (Here lb=/usr/local/bin
is an environment variable to avoid env -i PATH="$PATH", and `/n` is a symlink
to "/dev/null"):
```
$ chrt 99 taskset 0x8 env -i CLIGEN=/n $lb/tim "/bin/dash -c exit" "/bin/rc -lic exit" "/bin/bash -c exit" "/bin/dash -lic exit" "/bin/ksh -lic exit" "/bin/bash -lic exit 2>/n"
(2.0398 +- 0.0091)e-04  (AlreadySubtracted)Overhead
(1.820 +- 0.017)e-04    /bin/dash -c exit
(2.111 +- 0.015)e-04    /bin/rc -lic exit
(7.045 +- 0.049)e-04    /bin/bash -c exit
(1.2383 +- 0.0069)e-03  /bin/dash -lic exit
(1.800 +- 0.016)e-03    /bin/ksh -lic exit
(8.414 +- 0.023)e-03    /bin/bash -lic exit 2>/n
$ chrt 99 taskset 0x8 env -i CLIGEN=/n $lb/tim "/bin/dash -c exit" "/bin/rc -lic exit" "/bin/bash -c exit" "/bin/dash -lic exit" "/bin/ksh -lic exit" "/bin/bash -lic exit 2>/n"
(1.9455 +- 0.0072)e-04  (AlreadySubtracted)Overhead
(2.007 +- 0.011)e-04    /bin/dash -c exit
(2.251 +- 0.013)e-04    /bin/rc -lic exit
(7.121 +- 0.030)e-04    /bin/bash -c exit
(1.2239 +- 0.0059)e-03  /bin/dash -lic exit
(1.849 +- 0.017)e-03    /bin/ksh -lic exit
(8.386 +- 0.014)e-03    /bin/bash -lic exit 2>/n
$ chrt 99 taskset 0x8 env -i CLIGEN=/n $lb/tim "/bin/dash -c exit" "/bin/rc -lic exit" "/bin/bash -c exit" "/bin/dash -lic exit" "/bin/ksh -lic exit" "/bin/bash -lic exit 2>/n"
(2.0226 +- 0.0084)e-04  (AlreadySubtracted)Overhead
(1.976 +- 0.012)e-04    /bin/dash -c exit
(2.135 +- 0.011)e-04    /bin/rc -lic exit
(7.133 +- 0.044)e-04    /bin/bash -c exit
(1.2155 +- 0.0070)e-03  /bin/dash -lic exit
(1.7999 +- 0.0085)e-03  /bin/ksh -lic exit
(8.434 +- 0.038)e-03    /bin/bash -lic e
```

The overhead time itself has (2.0398 +- 0.0091) - (1.9455 +- 0.0072) = 0.094 +-
0.012[^7] or 94/12 =~ 7.8σ variation which is kind of big.[^8]  Actual timings
of programs reproduce reliably with "similar" error scale from trial to trial.
This can be made easier to more or less just read-off reproduction by just
sorting and adding some blanks:
```
(1.9455 +- 0.0072)e-04  (AlreadySubtracted)Overhead
(2.0226 +- 0.0084)e-04  (AlreadySubtracted)Overhead
(2.0398 +- 0.0091)e-04  (AlreadySubtracted)Overhead

(1.820 +- 0.017)e-04    /bin/dash -c exit
(1.976 +- 0.012)e-04    /bin/dash -c exit
(2.007 +- 0.011)e-04    /bin/dash -c exit

(2.111 +- 0.015)e-04    /bin/rc -lic exit
(2.135 +- 0.011)e-04    /bin/rc -lic exit
(2.251 +- 0.013)e-04    /bin/rc -lic exit

(7.045 +- 0.049)e-04    /bin/bash -c exit
(7.121 +- 0.030)e-04    /bin/bash -c exit
(7.133 +- 0.044)e-04    /bin/bash -c exit

(1.2155 +- 0.0070)e-03  /bin/dash -lic exit
(1.2239 +- 0.0059)e-03  /bin/dash -lic exit
(1.2383 +- 0.0069)e-03  /bin/dash -lic exit

(1.7999 +- 0.0085)e-03  /bin/ksh -lic exit
(1.800 +- 0.016)e-03    /bin/ksh -lic exit
(1.849 +- 0.017)e-03    /bin/ksh -lic exit

(8.386 +- 0.014)e-03    /bin/bash -lic exit 2>/n
(8.414 +- 0.023)e-03    /bin/bash -lic exit 2>/n
(8.434 +- 0.038)e-03    /bin/bash -lic exit 2>/n
```
A statically linked Plan 9 rc shell, `/bin/rc -lic exit`, for example, has time
measurement errors below 2 microseconds and deltas of 2.4±1.9μs = 1.26σ and
11.6±1.7μs = 6.8σ.  In general, errors are around 1..40μs, 0.1%..0.5%, 0..10σ.

The large sigma distances suggest errors are a bit underestimated.  More careful
study showed the situation is mostly very leptokurtotic.. (I saw excess kurtosis
over 12) meaning wild tail events are much more common than expectations from
light-tailed noise.  So, one cannot use sigma alone for t-tests.  This wild
distribution itself is likely irreproducible over time or across test machines.
Running that set of tests with fixed CPU frequency and very minimal background
activity would very likely make these distributions less hostile.

So, we can answer the question "Does it work?" with "kinda!".  10σ devs with no
underlying difference are far too common, yet errors are still small in absolute
terms letting you separate fairly subtle effects.  So, it seems useful as long
as you take any A/B pseudo-t-tests with a "cube of salt" a bit bigger than the
one common in particle physics.[^8]

Other issues
============
There is actually a natural pre-requisite to all of this which is to assess if
**if your benchmark gives stable times in the min-tail in the first place**.
One way to do this is checking min-tail quantile-means are consistent across
back-to-back trials.  **If so**, then you have some reason to think you have a
stable sampling process (at least near the min).[^9]  **If not**, you must
correct this before concluding much (even on an isolated test machine).

There are many such actions..1) Shutting down browsers 2) Going single-user 3)
`taskset`/`chrt`, 4) fixing CPU frequency dynamically in-OS 5) Rebooting into a
BIOS with fixed freq CPU(s) (or your OS's equiv. of these Linux interventions),
6) `isolcpus` to avoid timer interrupts entirely, 7) Cache Allocation Technology
extensions to reserve L3, and on & on. (`tim` hopes simpler ideas can prevent
much of that effort most of the time without corrupting benchmark design.)

[^1]: Find a link to circa 2019 blog about writing own "Measurement OS" to study
how [Spectre](https://en.wikipedia.org/wiki/Spectre_(security_vulnerability))-
like security vulnerabilities play out.

[^2]: Spinning platter disks & handling even ambient broadcast network packets
or other competing action can evict your cache entries on unrelated work.  This
is true even on "mostly idle" machines, though much worse on heavily loaded
machines/networks/etc.  Basically, there is not really such a thing as an "truly
idle" general purpose system..merely "approximately idle".

[^3]: Of course, understanding does not ***end*** with reproduction.  Sometimes
the whole distribution is of interest, not the best or "luckiest".  Cold-cache
(for some values of "cold" & "cache") can be more interesting.  `tim` can write
all times to a file, including "warm-ups".  Most debate over such things (eg.
hbench vs. lmbench) is more about how to compress many numbers into one for
purposes of comparison.  Not compressing at all (& not flattening time series
structure) is the more informative comparison.  Since humans are bad at reading
such reports, views on the debate mostly come down to disagreeing estimates of
P(misinterpretation|strong subjective experience components).  In any event, if
one *does* care about the whole distribution, not merely `t0`, to be scientific
one should check that ***the whole distro reproduces*** via K-S tests or similar
(unlikely but not impossible for most noise of my personal experience).  This
may be Future Work for `tim` and inherently requires a *lot* of data/samples as
well as environmental controls.

[^4]: For example, [Ben Hoyt's King James Bible ***concatenated ten
times***](https://benhoyt.com/writings/count-words/) means that branch
prediction and so possibly memory prefetching begins to work perfectly after
just 10% of his benchmark.  Beyond this, hash table sizes become non-reflective
of natural language vocabulary scaling.  How much this degrades his prog.lang
comparisons is hard to say, but it's better to avoid it than guess at it.

[^5]: For *independent* samples, which is of course *NOT* really true here, the
distribution of the sample minimum (noise) itself is the N-th power of the base
hostile distribution.  This makes, e.g., median(min(nTimes)) the
[0.5^n](https://en.wikipedia.org/wiki/Extreme_value_theory#Univariate_theory)
quantile of the underlying times distribution.  For n=20 this is ~1/million.
That sounds small, but is quite variable on most systems!

[^6]: https://arxiv.org/abs/1412.3972

[^7]: Basic [error
propagation](https://en.wikipedia.org/wiki/Propagation_of_uncertainty) uses
"smallness" of errors and Taylor series.  The Nim package
[Measuremancer](https://github.com/SciNim/Measuremancer) or the Python package
[uncertainties](https://pypi.org/project/uncertainties/) can make such
calculations more automatic, especially if you are, say, subtracting uncertain
dispatch overhead or want 3.21x faster "ratios".

[^8]: Particle physics has "5 sigma" rules of thumb to declare new science in a
similar vein.  5 seems too small for this hostile noise context.  10..15 is
more about right, but leptokurtosis makes sigma alone an inadequate scale.

[^9]: `tim` may soon grow some kind of [2-sample or K-sample Anderson Darling](
https://en.wikipedia.org/wiki/Anderson%E2%80%93Darling_test) testing to check
this more formally, but perhaps trimmed or strongly min-tail-weighted.  Tests
like these do require independent samples which may also be tested, though the
results of such tests are likely to be "Nope, not independent - by design".
