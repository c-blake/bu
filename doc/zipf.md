Motivation
==========
See [Wikipedia](https://en.wikipedia.org/wiki/Zipf's_law) for background on the
distribution this little program can sample from.

There many situations where simulating workloads that will not be immediately
challenged and Zipf go together.  One example is in estimating the accuracy of a
[Count-Min sketch](https://en.wikipedia.org/wiki/Count%E2%80%93min_sketch).
{ Some systems want to monitor with small memory trending/popular things over a
set of many possible things (videos, documents, pages, URIs, users, etc.).
Naive implementations of such sketches are more accurate for skewed
distributions dominated by a few items of outsized popularity. }

Inverse Transform Method
========================
Any distribution (specifically the [Cumulative Distribution
Function](https://en.wikipedia.org/wiki/Cumulative_distribution_function) ) is
really just a map from values to the fraction of a gigantic sample below said
values.[^1]  The concept be either descriptive (what happened) or predictive
(what you expect to happen).  A direct aspect of the defining idea is that if
you randomly pick "some fraction" uniformly on [0,1] and "reverse the map" you
get a value distributed according to the same mapping.  There is, naturally,
[math](https://en.wikipedia.org/wiki/Inverse_transform_sampling) to back this
up, but I view that math as mostly confirming the definition "makes sense".

If the distribution is represented as a bunch of numbers in order in an array,
"reversing the map" is just a search problem solvable with good old [binary
searches](https://en.wikipedia.org/wiki/Binary_search_algorithm) (start with the
whole range, find the middle & narrow to the side where the value might be).[^2]

`zipf` uses this method to sample a Zipf not because it is the most efficient,
but since it is efficient enough and can show interesting aspects of caching.

Usage
=====
```
  zipf [optional-params] [keys: string...]

Sample passed args according to a Zipf distribution for for n items.  The bigger
alpha the more skewed to dominant events.  Provides wr & rd since CDF calc is
slow for many possible items.  I recommend (https://github.com/c-blake/nio)
filenames ending in .Nd.

  -n=, --n=     int    10    sample size
  -a=, --alpha= float  1.5   Zipf-ian parameter; > 1
  -w=, --wr=    string ""    write (binary) data to this
  -r=, --rd=    string ""    read (binary) data from this
  -b, --bin     bool   false 8B binary ints->stdout
  -g=, --gen=   Slice  0..0  sample from ints in this range
```

An Example With Analysis
========================
What we do here is first write a 800 MB file with the CDF of a Zipf distribution
over 100e6 8B elements with alpha=1.5.  Then we run to sample a single element
to see a fixed start-up overhead.[^3]  Finally we time sampling 1e6 events
according to that distribution to get (copy-pastable; Zsh REPORTTIME and TIMEFMT
are helpful here...):
```
$ zipf -w /dev/shm/z1e8.Nd -n0 -g 1..100_000_000; \
  zipf -r /dev/shm/z1e8.Nd -n1 -g 1..100_000_000; \
  zipf -r /dev/shm/z1e8.Nd -n 1_000_000 -bg 1..100_000_000 >/dev/shm/i.Nl
 Time: 1.807 (u) + 1.014 (s)=2.833 (99%) mxRSS 2220 MiB
1
 Time: 0.416 (u) + 0.739 (s)=1.160 (99%) mxRSS 2215 MiB
 Time: 0.464 (u) + 0.750 (s)=1.219 (99%) mxRSS 2317 MiB
```
So, only `(1.219-1.160)/1e6` = a small 59 nanosec / per RNG sample on a CPU with
8MiB L3 cache where [memlat](memlat.md) gives 67 ns latency DIMMs.  The worst
case of the per random sample binary search to map a U(0,1) number back to the
array slot is something like `log_2 1e8` = 27 memory access.  So, a worst case
time of ~27\*67 = 1800 ns, over 30X longer.[^4]

What happened?  The CDF is only 1% cachable (8/800), but the worst case is very
rare.  Probability is concentrated to make most answers be at the start of the
array.[^5]  So, the binary search path need only load from slow memory once and
then almost always re-accesses those same exact paths showing great [temporal
locality of reference](https://en.wikipedia.org/wiki/Locality_of_reference).
If you doubt the theory, you can use [ru](ru.md) to measure major faults (majF)
after dropping caches.  In the above example, I got one run with only 71 4096B
pages loaded off a Winchester disk, merely 284 KiB or 0.036% of the data.

*Conversely*, speed could be *disrupted* by ~30X if, between samples, competing
work (in the same process/thread or elsewhere) evicts soon to be needed cache
entries.  Being routed to the same portion of the merely 32 KiB *L1* D-cache 99%
of the time makes *another* feature of modern CPUs - branch prediction - also
very effective -- log_2(32KiB/8B)=12.  So, the first 27-12 = 15 hops of binary
search are the same 99% of the time.  Branch misprediction can also hinder less
skewed binary searches.

Those fascinated by [self-reference](https://en.wikipedia.org/wiki/Ouroboros)
may be amused to see CPU designs working for very popular memory helping [to make
data sets to evaluate approximations for which items are popular](#motivation).

[^1]: People often plot the derivative (successive differences) which obscures this simplicity.

[^2]: [Interpolation search](https://en.wikipedia.org/wiki/Interpolation_search)
is also possible, but usually slower than binary search due to slow division.

[^3]: Large here, but maybe faster on a HugeTLBfs with fewer kernel page table
 manipulations.

[^4]: Neglecting time to 8 MB to a /dev/shm ram disk which is O(1 ms).

[^5]: In this particular example, the L2 CPU cache of 256 KiB covers over 99.6%
of samples as assessed by `nio pr /dev/shm/z1e8.Nd|head -n32768|tail -n1`.  The
rest of the path of the binary search easily fits in the L3 CPU cache.
