Motivation
==========
One often wants to extrapolate from a finite sample to the true max|min.  When
benchmarking, one might want to [filter out system noise](doc/tim.md) { which
has some unknown distribution, but is even worse non-stationary/not IID :-( }.
Another example is in density estimation such as the "clip" or "cut off" values
for a simple histogram or KDE.

Solving foundational problems like "What background activity competes on time
sharing systems, how stationary is it, etc.?", is hard.  However, it is not so
hard to estimate true max|min's (& errors of said estimates) better than sample
extremes of ginormous samples (if one views this as a performance optimization).
Also, one cannot always sample more data - sometimes that is crazy expensive &
limited by "dollars or years per sample" effects.

Approach
========
The paper initially inspiring this utility is openly available at
https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1433242 .  That block maxima
idea (& implementation) has been superceded by the *far* more reliable more
peaks-over-threshold (POT) school of Portuguese Extremists:
https://arxiv.org/abs/1412.3972

Standard errors for the estimate of the true population extreme are estimated by
a bootstrap which should make them ok, but full disclosure I am still working on
this aspect.

Usage
=====
```
  eve [optional-params] 1-D / univariate data ...

Extreme Value Estimate by FragaAlves&Neves2017 Estimator for Right Endpoint
method with bootstrapped standard error.  E.g.: eve -l $(repeat 99 tmIt).  This
only assumes IID samples (which can FAIL for sequential timings!) and checks
that spacings are not consistent with an infinite tail.
Options:
  -l, --low       bool      false flip input to estimate Left Endpoint
  -b=, --boot=    int       100   number of bootstrap replications
  -e=, --emit=    set(Emit) bound tail  - verbose long-tail test
                                  bound - bound when short-tailed
  -a=, --aFinite= float     0.05  tail index > 0 acceptance significance
  -k=, --kPow=    0.0..1.0  0.75  order statistic threshold k = n^kPow
```

Some Subtleties
===============
The idea here does not make sense if extreme data spacings suggest an infinite
rather than finite tail.  So, we are careful to rule this out at alpha level
`aFinite` in both the main estimator and the bootstrap re-sampling.

The bootstrap preserves the sample-max to aid clustering of new estimates around
that best known limit.  It also re-samples only the data that contributes to the
estimate - and also only from that portion of the tail.  This seems to me the
most coherent approach.

POT methods require that k/n->0 as n grows.  But we want a good estimate.  So,
we want k big.  However, for the estimator formula, k cannot be > n/2.  So,
internally, `eve` uses `k = min(n/2 - 1, n^kPow)`.  This should discard most
data above (below for `-l`) the median or much more if you use a lower `kPow`.
