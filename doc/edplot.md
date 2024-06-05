Motivation
==========
[`tim`](tim.md) gives an example way to collect durations and uses
[`eve`](eve.md) to estimate the minimum values, but, as mentioned in the [tim
doc](tim.md), one is sometimes interested in the whole distribution, perhaps
summarized more graphically than analytic-numerically { say via
[approximate](https://c-blake.github.io/adix/adix/mvstat.html) or [exact
interpolated quantiles](https://github.com/c-blake/fitl/blob/main/fitl/qtl.nim)
used either directly or [by
re-sampling](https://github.com/c-blake/fitl/blob/main/fitl/cds.nim) }.  This is
a common way of comparing two or more data samples, often but by no means
exclusively of run-times, for similarities, differences, and features.  This is
what `edplot` is for (short for "Empirical Distribution Plot").

Background (A)
==============
The first question is why to use/show [an EDF](
https://en.wikipedia.org/wiki/Empirical_distribution_function) instead of a
[histogram](https://en.wikipedia.org/wiki/Histogram) or some other [density
estimate](https://en.wikipedia.org/wiki/Density_estimation).  The answer is
simple: no free parameters (beyond "confidence interval size"-like ones).[^1]
Free parameters slow science (construed most broadly), inviting methodological
debate.  KDEs improve on histograms by averaging over bin alignment[^2].  EDFs
nix both alignment *and* bandwidth / bin width and are a solid best estimate of
the true population distribution with multiple well known error bands.

I also prefer density / derivative / PDF Speak, ***BUT*** the disagreement on
bandwidth selection techniques is staggering.  There are (easily!) ten thousand
papers in academic statistics on bandwidth selection since the late, great
Emanuel Parzen got people interested in KDEs in 1962 (or maybe Rosenblatt in
1956).  I even have my own ideas along those lines, but even so, without broad
acceptance, one gets stuck debating methods not analyzing data.  So, as a
practical/social matter, ***IF you can*** answer & inspire your questions with
EDFs, you probably should.  The most common reason people do not is not having
spent time to learn to read/use them; They're popular in social sciences.

Key EDF Properties (B)
======================
Order statistics (the sorted data) form a set of [complete, sufficient
statistics](https://en.wikipedia.org/wiki/Sufficient_statistic).  The theory of
such statistics implies that the EDF is both an ***UNBIASED*** and ***MINIMUM
VARIANCE*** estimator of the true distribution function F(x).  This is another
reason why using EDFs removes doubt - there is no real competitor.  Re-sampling
from EDFs is also the basis of various methods going by the informal name of
["The bootstrap"](https://en.wikipedia.org/wiki/Bootstrapping_(statistics))
which is another way to get results with weaker assumptions (what you want!).

Confidence Bands (C)
====================
The next background point is that an EDF is based upon *just one sample* of what
is usually viewed in statistics as a potentially *unbounded sampling process*
whose traits we seek to understand.  As such, it is not usually the end of the
story.  There is uncertainty about what it implies about the population
distribution.  There are various ways to analyze and exhibit such uncertainty.
One easy one in this context is a non-parametric [confidence band](
https://en.wikipedia.org/wiki/CDF-based_nonparametric_confidence_interval).
These come in both point-wise (the binomial proportion < x)[^3] and simultaneous
varieties.

As explained in the Wikipedia page, the point-wise band is a lower bound while
the simultaneous band is an upper bound of the uncertainty.  Other than this,
neither rely upon the shape of the distribution nor asymptotic sample sizes.
So, together they constitute, for a given CI level, a tube with a thick wall
robustly & CI-approximately circumscribing the distribution function of the true
population.

Boundaries (D)
==============
One thing ordinarily just "clipped conveniently" in a classical EDF estimate is
chances of being below the sample min or above the sample max.  For true
distributions which are discrete, it may be literally impossible to see such
values.  So, pinning to the sample min/max or even a plot of "impulses" is best.
However, for true distributions of a *continuous* random variable, no finite
sample can *ever* see a true population minimum.  Estimating such is the project
of [`eve`](eve.md), and we simply use those estimates here.[^4]  They are used
to decide how "wide" lines along P=0 & P=1 are.  Many distributions like time
durations are continuous to good approximations.

Usage
=====
```
  edplot [optional-params] input paths or "" for stdin

Generate files & gnuplot script to render CDF as confidence band blur|tube.
If .len < inputs.len the final value of wvls, vals, or alphas is re-used for
subsequent inputs, otherwise they match pair-wise.

  -b=, --band=   ConfBand pointWise  bands: pointWise simultaneous tube
  -c=, --ci=     float    0.02       band CI level(0.95)|dP spacing(0.02)
  -k=, --k=      int      4          amount of tails to use for EVE; 0 => no
                                     data range estimation
  -t=, --tailA=  float    0.05       tail finiteness alpha (smaller: less prone
                                     to decided +-inf)
  -f=, --fp=     string   "/tmp/ed/" tmp File Path prefix for emitted data
  -g=, --gplot=  string   ""         gnuplot script or "" for stdout
  -x=, --xlabel= string   "Samp Val" x-axis label; y is always probability
  -w=, --wvls=   floats   {}         cligen/colorScl HSV-based wvlens; 0.6
  -v=, --vals=   floats   {}         values (V) of HSV fame; 0.8
  -a=, --alphas= floats   {}         alpha channel transparencies; 0.5
  -o=, --opt=    TubeOpt  both       tube opts: pointWise simultaneous both
```

Examples
========
To be easy to reproduce & also ease visually plot debugs, a running example here
will be two 20 point data sets: `triang` - a distribution with a roughly
triangular PDF from: `(seq 1 10;seq 3 7;seq 4 6;seq 5 5;seq 5 5)>triang` and
`perturb` - an invented perturbation from `triang` that can be made from
`(seq 4 9;seq 5 9;seq 6 8;seq 7 8;seq 7 8;seq 7 7;seq 7 7)>perturb`.[^5]
The difference is ***just*** big enough to fail a [2-sample KS
test](https://en.wikipedia.org/wiki/Kolmogorov%E2%80%93Smirnov_test#Two-sample_Kolmogorov%E2%80%93Smirnov_test)
for same parent population at the 5% level.[^6]  The perturbation is just a bit
narrower and a bit up-shifted.  These data are just to have concrete things to
plot, not a full course on interpreting distributions and their differences as
that seems out of scope.

So, here are 4 basic examples.  Something to keep in mind as you read the plots
is "which one best communicates 'only marginally different' to me?".

First, a "smear" plot where many CIs are drawn at fixed steps apart (2% here)
from the `--ci` option from `edplot -w.87 -w.13 -bp triang perturb`[^7]:
![blur1](blur1.png).  (Simultaneous bands in such a plot are all "spaced the
same" vertically and so are less visually engaging.)

Next, `edplot -w.87 -w.13 -bt -ob triang perturb` renders only partly solid
shaded regions of the pointwise bands from Wilson scores: ![pwise](pwise.png).

Third, `edplot -w.87 -w.13 -bt -os triang perturb` shows a similar visualization
with the wider Massart inequality simultaneous bands: ![simul](simul.png).

Finally, `edplot -w.87 -w.13 -bt -op triang perturb`: ![tubes](tubes.png) shows
the lower & upper bounds of each bands as a darker, more solid region with the
"definitely at least this uncertain at this CI" bands in the middle.

Personally, I find the 2nd or 3rd variants the easiest to read, but I do like
how the final variant most boldly emphasizes what one most surely knows about
the true distribution functions, and I also have some affection for the first
as a more classic shade most darkly closest to the center of an estimate.  Hence
all remain represented with different CL options.

Conclusion
==========
`edplot` emits files to plot to try to support principled visual reasoning about
data sets based on EDFs and related uncertainties in distribution not density
space.  Its defaults are set up for a prior assumption of a continuous true
distribution.  Once you learn to read them, the plots it can makes are very
"full information" containing ways to answer many questions about data sets.

[^1]: Technically, the `k` used to assess the data range, is a non-probability
free parameter, but A) this is also needed (though admittedly usually neglected)
for density estimation and B) Fraga Alves & Neves 2017 has a story for setting
`k` we might be able to use.  So, at the least the current state is one less
free parameter - the same improvement a KDE has over a histogram.

[^2]: Averaging over such [nuisance
parameters](https://en.wikipedia.org/wiki/Nuisance_parameter) is a standard
Bayesian tactic.

[^3]: Estimating the `p` in a binomial random variable is itself [a large
topic](https://en.wikipedia.org/wiki/Binomial_proportion_confidence_interval)
only partially covered by the
[`spfun/binom.nim`](https://github.com/c-blake/spfun/blob/main/spfun/binom.nim)
module.

[^4]: We do so with no visual indication of *their* uncertainty at the moment.
One idea is "(..." on the 0-axis and "......)" on the 1-axis or perhaps an even
fainter line extending beyond the data range.

[^5]: If it's easier to copy-paste number lists than run `seq` these expand to
1 2 3 3 4 4 4 5 5 5 5 5 6 6 6 7 7 8 9 10 and
4 5 5 6 6 6 7 7 7 7 7 7 7 8 8 8 8 8 9 9.

[^6]: `max |F_a(x)-F_b(x)|` is @5,6,7=9/20=0.45; Wiki table gives `1.358 *
sqrt(40/400)` which is 0.43.

[^7]: Personally, I usually just run `edplot ...|gnuplot` which dumps sixels to
my `st` terminal via a `$GNUTERM` setting, but these plots were instead made by
`edplot ...>foo.gpi`, hand editing the `.gpi` file to uncomment `# set terminal
png` & change the output filename.  Another tweak (&| wrapper script) might be
`(echo set term x11; edplot ...; echo pause -1)|gnuplot` for an interactive X
window.
