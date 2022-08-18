Motivation
----------
One often wants to extrapolate from a finite sample to the true min|max.  In a
benchmarking context one might want to filter out system noise { which has some
unknown distributional shape, but is even worse non-stationary/not IID :-( }.
While nothing can really solve foundational problems like non-IID noise, it does
seem possible to estimate true min|max's better than simply taking mins of
larger and larger samples.  One ideally would also like some kind of estimate of
the error of such an extrapolation.

While it is not necessarily frozen in time, the paper initially inspiring this
utility is openly available at

    https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1433242

It is definitely more of a work-in-progress even just statistically than some
of the other utilities, but it does seem to work ok.

Usage
-----
```
Usage:

  eve [optional-params] values

Extreme Value Estimator a la Einmahl2010.  Einmahl notes that for low k variance
is high but bias is low & this swaps as k grows.  Rather than trying to minimize
asymptotic MSE averaging gamma over k, we instead average EV estimates for <=m
values of k with the least var estimates.  Averaging only low bias estimates
should lower estimator var w/o raising bias, but simulation study is warranted.
Eg: eve -ng $(repeat 720 tmIt).

  -b=, --batch= int   30    block size for min/max passes
  -n, --n       bool  false estimate minimum, not maximum
  -q=, --qmax=  float 0.5   max quantile used for average over k
  -a=, --amax=  int   20    absolute max k
  -m=, --m=     int   5     max number of k to average
  -s=, --sig=   float 0.05  fractional sigma(sigma)
  -l=, --low=   float 2.0   positive transformed lower bound
  -g, --geom    bool  false geometric (v. location) [low,inf) cast; >0!
  -v, --verbose bool  false operate verbosely
```
