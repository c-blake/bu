Background
==========
Often one has some program/operation of interest that takes 1..500 milliseconds.
One may want to time it to use as a benchmark.  While computers are conceptually
deterministic, in practical settings on general purpose OSes[^1] asynchronously
interacting with physical devices, all you can really measure is:

(1) `observed_time = t0 + noise`

Even with no time-sharing, peripheral interactions[^2] degrade determinism
motivating a random model for `noise`.  **`t0` is often what you want** because
`noise` often does not reproduce to other minutes / days / environments &
understanding begins with reproduction.[^3]

This seems like a "statistics to the rescue" scenario, but caution is warranted.
In most deployments, `noise` from Eq.1 is both time varying
([non-stationary](https://en.wikipedia.org/wiki/Stationary_process)) and
[heavy-tailed](https://en.wikipedia.org/wiki/Heavy-tailed_distribution) due to
**imperfect control over competing load**.  Both properties make both value &
error estimates of **flat averages including ALL OF `noise` mislead**.  Central
measures like the mean (& median) are likely dragged way up.  Errors in the
means just explode.  Neither converge as you might think from [Limit
Theorems](https://en.wikipedia.org/wiki/Central_limit_theorem).  Non-stationary,
non-independent noise violates base assumptions of most applied statistics.
Even trimmed / outlier removed averages risk confusing signal & noise (though
sometimes the noise *is* the signal[^3]).

Solutions
=========
A **0-tech** approach is to declare differences less than 2-10X "uninteresting".
While not invalid, **practical difficulties** remain.  You cannot always control
what other people find "interesting".  It's also not rare that "interesting"
deltas can be composed of improvement with many smaller stages which then still
need a solution.  Truly cold-cache times often have far bigger deltas than some
proposed range, leading to multiple runs to compare hot-cache results anyway.

The scale of `noise` compared to `t0` can vary considerably.  A popular approach
is to avoid sub-second times entirely, making benchmarks **many seconds long**
to suppress `noise`.  Sometimes people "scale up" naively[^4] to get hard to
interpret &| misleading results.  Since it is also rarely clear how much scaling
up is "enough" anyway or what the residual noise scale is, this can **compound**
waiting time for results via several samples of longer benchmarks.  Maybe we can
do better.

---

A low tech way to estimate reproducibly Eq.1's `t0`, in spite of hostile noise,
is a simple sample minimum.  This **filters out all but noise(minimum)** -
better behaved than average noise.[^5]

However, this gives no estimate of estimator error to do principled comparisons
among alternatives in benchmarking.  To get a minimum without error, one needs
an **infinite** number of trials.  We instead want to economize on repetitions.

A low art way to estimate the error on the sample min `t0` estimate is to find
the mean,sdev for the **BEST SEVERAL TIMES OUT OF MANY RUNS** to approximate the
error on the sample min.[^5] Other ideas (like differences between two smallest
times or various statistical formulae) are surely possible, but sdev(best) seems
workable in practice.  [Empirical
Evaluation](#empirical-evaluation-of-error-estimates) shows it works
surprisingly well.  There is also a more statistically principled `eve` mode
that [yields similar answers](#convergence--consistency).

---

There is actually a natural pre-requisite to all of this which is to assess if
**if your benchmark gives stable times in the min-tail in the first place**.
One way to do this is checking min-tail quantile-means are consistent across
back-to-back trials.  **If so**, then you have some reason to think you have a
stable sampling process (at least near the min).[^6]  **If not**, you must
correct this before concluding much (even on an isolated test machine).

There are many such actions..1) Shutting down browsers 2) Going single-user 3)
`taskset`/`chrt`, 4) fixing CPU frequency dynamically in-OS 5) Rebooting into a
BIOS with fixed freq CPU(s) (or your OS's equiv. of these Linux interventions),
6) `isolcpus` to avoid timer interrupts entirely, 7) Cache Allocation Technology
extensions to reserve L3, and on & on. (`tim` hopes that simpler ideas can
prevent all that effort most of the time without corrupting benchmark design.)

`tim` wraps these ideas up into a simple library & command-line wrapper.  You
just pass some expression/command to be timed (probably not outputting anything
to terminals).  It prints out an informative error when times are too unstable.

Usage
=====
```
  tim [optional-params] [cmds: string...]

Run shell cmds (maybe w/escape|quoting) 2n times.  Finds mean,"err" of the
best twice and, if stable at level dist, merge results for a final time & error
estimate (-B>0 => EVT estimate).  doc/tim.md explains.

  -n=, --n=       int    10   number of outer trials; 1/2 total
  -b=, --best=    int    3    number of best times to average
  -d=, --dist=    float  9.0  max distance to decide stable samples
  -w=, --write=   string ""   also write times to this file
  -r=, --read=    string ""   use output of write instead of running
  -B=, --Boot=    int    0    bootstrap replications for final err estim
                              <1 => simpler sample min estimate & error
  -l=, --limit=   int    5    re-try limit to get finite tail replication
  -a=, --aFinite= float  0.05 alpha/signif level to test tail finiteness
  -s=, --shift=   float  4.0  shift by this many sigma (finite bias)
  -k=, --k=       float  -0.5 2k=num of order statistics; <0 => = n^|k|
  -K=, --KMax=    int    50   biggest k; FA,N2017 suggests ~50..100
  -o=, --ohead=   int    0    number of "" overhead runs;  If > 0, value
                              (measured same way) is offset from each item
```

Example: Measuring Dispatch Overhead
====================================
Internally, `tim` uses system(3) which passes each `cmd` as a string to a shell.
POSIX shells have a built-in command `:` which only expands its arguments.  So,
at least on Unix-like, one can do this:
```sh
$ tim : :          # OR, e.g., tim 'this way' 'that way'
(3.53 +- 0.15)e-04      :   #NOTE: seconds - so 0.353 ms
(3.70 +- 0.10)e-04      :
```
to time "null" commands twice.[^7]  In this case, we expect times in seconds to
be "the same" and they are.[^8]

Empirical Evaluation of "error" estimates
=========================================
The above example can be generalized to **measure** how coherent the estimate &
errors are with your interpretations.  You can re-purpose `--dist` to get `tim`
to emit a little report which includes distances.  That can just be extracted
with simple text manipulation.  To get 1000 samples of the distribution of dist
under noise variation, for example, you can just:
```sh
c=$(printf '%1000s\n' | sed 's/ /: /g')
eval tim -d0 $c|grep apart|awk '{print $2}'|sort -g>/tmp/a
# plot '/tmp/a' u 1:0 w step  # gnuplot datum idx vs. val
```
produces for me (normal = under `taskset 0xE chrt 99` on an otherwise "idle"
i7-6700k CPU running Linux 6.1.1 with X11, a no-tabs browser, a few terminals,
the network stack and so on running, but zero load)[^9]:
![tim EDF plot](tim.png)
For reference, abs(N(0,1)) and a rebooted BIOS-fixed frequency single-user also
taskset/chrt'd plot are also included.  As a "unit", `dist` is close (in
complementary probability) to Gaussian at <1.5, but the divergence gets bad past
2 Gauss sigmas (with 2X or 3X errors depending on special boot mode or not).  By
3 sigma rare events happen **over 50X** more often than Gaussian.[^10]  Even with
best 3/10, **tails are very heavy**.  Even selecting `--dist` to decide
"reproducible" can be.. challenging.  This **challenge spills over** into any
better-worse comparisons since deltas big enough to be significant may need to
be many "sigma" apart.[^11]

A plot of your own test environments can perhaps show how bad this may be for
you, but it is, again, non-stationary/competing work dependent.  Whatever level
of stationarity occurs, shape & scale of the distribution likely also vary with
time scale of the measured program.  So, trying to measure/memorize it is hard.
**Playing with `--best` & `--run` to rein in the tail** at various scales seems
more likely to be productive of better measurements.[^12]  `tim` does support
`~/.config/tim` for setting defaults if you find some you like.

In light of all this, this best n of m idea twice is only a "something is better
than nothing" thing.

Convergence / Consistency
=========================
The idea of `tim` is fundamentally a sort of "optimization of benchmarking".
Specifically, we want to **repeat as few times as possible** while getting a
vaguely credible measurement error estimate.  A natural next question is "How
many iterations is 'enough'".  Answer to any "enough" question depends (at
least!) upon what users want (eg. 10%, 0.1% error, etc.).

However, to validate the methodology itself we can do something as simple as
the overhead calibration measurement (as root):
```sh
for n in 10 30 100 300 1000; do env -i PATH=$PATH CLIGEN=/dev/null chrt 99 taskset 0x3 tim -n$n '' '' '' '' '' '' '' '' ''; done
```
Using this, we can examine two features - internal consistency with estimated
errors at a given `n` and convergence as `n` increases.  (The empty string
corresponds to `sh -c ''` which for me is a statically linked `/bin/dash -c
''`.)  We can go a bit further by switching to `tim -B100` to use [Extreme Value
Theory](https://en.wikipedia.org/wiki/Extreme_value_theory) (this is the
max-operation version of the Central Limit Theorem for summations) as currently
encoded in [eve](eve.md) (which uses a Fraga Alves method with more heuristic
threshold selection).  What we get is summarized by: ![tim
consistency-convergence plot](consisCvg.png)

The plot artificially staggers the `n` ordinate on the x-axis to make error bars
visible (in a points not overlaying sense, but data is at discrete, round `n`).

What we ideally want is an estimator that converges to a distribution roughly
symmetric and near Gaussian-around-its mode (which should match 60,000 =
approximate infinite run limit).  Though `tim` seems far less off track than
more common practices, it does not quite realize the dream (yet).

First, the estimator seems to be converge (what stats folk call "consistent"),
but from above  as `n` grows, not symmetrically.  I.e., the error on t0hat is
"only '-' not '+/-'".  (This could partly be a very long-term warming-up effect
of the sampling process, not entirely about the estimator, although experiments
with `fitl/dists` suggest otherwise.)

Second, the "error of the error" is large.  I.e., at both small & large `n`,
estimated errors are easily 2-3X too small, *but also* sometimes too large by
similar factors.  So, estimating errors here is a real challenge (as is, by
extension, "iterating until an estimate reaches an accuracy target).  Pseudo
T-tests also remain suspect out to very non-Gaussian distances.

Third, though max likelihood estimator GPD fits might improve the EVT method,
playing with kPow makes it unlikely to me that it will become much better than
the very low art in finite samples which is a little disappointing.  Heuristic
fudge factors on the sdev to try to center the estimate will converge (since
sdev seems to), but may generalize poorly to other measurement time scales which
are more costly to "cross-check" with 10s of thousands of runs.

[^1]: Find a link to circa 2019 blog about writing own "Measurement OS" to study
how [Spectre](https://en.wikipedia.org/wiki/Spectre_(security_vulnerability))-
like security vulnerabilities play out.

[^2]: Spinning platter disks & handling even ambient broadcast network packets
or other competing action can evict your cache entries on unrelated work.  This
is true even on "mostly idle" machines, though much worse on heavily loaded
machines/networks/etc.  Basically, there is not really such a thing as an "truly
idle" general purpose system..merely "approximately idle".

[^3]: Of course, understanding does not ***end*** with reproduction.  Sometimes
the whole distribution is of interest, not the "luckiest".  Sometimes cold-cache
(for some value of "cold" and "cache" are more interesting).  `tim` does let you
write all the times to a file.  Most debate over such things (eg. hbench vs.
lmbench) is really about how to compress many numbers into one for purposes of
comparison.  Not compressing at all (or even nixing time series structure) is
the more informative comparison.  Since humans are bad at reading such reports,
views on the debate mostly come down to priors on misinterpretation probability
(usually with strong subjective experience components).  In any event, if one
*does* care about the whole distribution, not merely `t0`, to be scientific one
should check that ***the whole distro reproduces*** via a K-S test or similar
(unlikely but not impossible for most noise of my personal experience).  This
may be Future Work for `tim`.

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
quantile of the times.  For n=20 this is ~1/million.  That sounds small, but is
quite variable on most systems!

[^6]: `tim` may soon grow some kind of [2-sample or K-sample Anderson Darling](
https://en.wikipedia.org/wiki/Anderson%E2%80%93Darling_test) testing to check
this more formally, but perhaps trimmed or strongly min-tail-weighted.

[^7]: My /bin/sh -> dash, not bash.  Statically linked dash is 3..4X faster than
bash for this.  Automatically measuring & subtracting shell overhead/optionally
minimizing it with `bu/execstr.nim` are possible future work.

[^8]: The values are (3.7 - 3.53)/(.15^2 + .1^2)^.5 = 0.94 "err"s apart by basic
[error propagation](https://en.wikipedia.org/wiki/Propagation_of_uncertainty)
which uses "smallness" of errors and Taylor series.  The Nim package
[Measuremancer](https://github.com/SciNim/Measuremancer) or the Python package
[uncertainties](https://pypi.org/project/uncertainties/) can make such
calculations more automatic, especially if you are, say, subtracting uncertain
dispatch overhead or want 3.21x faster "ratios".

[^9]: |N(0,1)| came from just taking absolute values of 1000 unit normals.

[^10]: For that graph, at 4 the special mode is also 1.1% vs 2.4% for normal.
So, special boots *can* help (by 2.2X even), but the tail remains quite heavy.
The max distance is 8.0 for the special boot mode and 14.5 for the normal mode.

[^11]: I use "sigma" here loosely as a general scale parameter, not the scale of
a Gaussian/Normal distribution.  Particle physics has "5 sigma" rules of thumb
to declare new science in a similar vein.  5 seems too small for this context.

[^12]: Playing with `err = avg(abs(t - tMin))` definitions also seems a path to
more reproducible error estimates.
