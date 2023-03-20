Motivation
==========
It can sometimes help to have an estimate of the number of unique/distinct items
from a large, possibly compressed-on-storage input stream. E.g., you may want to
spend 1-pass over the data to know if you could fit a hash table containing all
keys in available space (& even pre-size such a table to avoid growth costs).
If you cannot then you may need some other estimation approach.

KMV Sketch Method
=================
For a low price of just `k` max value entries[^1] you can get a pretty good
estimate with error ~ 1/sqrt(k).
[adix/uniqce.nim](https://github.com/c-blake/adix/blob/master/adix/uniqce.nim)
has more details.[^2]

Usage[^3]
=========
```
  uce [optional-params]

Emit Unique Count Estimate of input lines to stdout.  Algo is fast, low space
1-pass KMV over mmap | stream input. (For exact, see lfreq.)

  -i=, --input= "/dev/stdin"                input data path
  -k=, --k=     1024                        size of the sketch in float64 elts
  -r=, --re=    0..5                        range of 10expon defining 'near 1'
  -f=, --fmt1=  "$val0 +- $err0"            fmt for uncertain num near 1
  -e=, --expF=  "($valMan +- $errV)$valExp" fmt for uncertain num beyond `re`
```
Empty string for `fmt1` produces two columns of float at full precision.

Examples
========
```sh
$ (seq 1 50; seq 1 50) | uce
50.00 +- 0.10

$ (seq 1 5000000; seq 1 5000000) | uce
(5.09 +- 0.16)e+06
```

[^1]: A `k` fitting in an L1 data cache yields O(1%) estimates.

[^2]: This is by far the simplest sketch family along these lines -
conceptually, code, etc.

[^3]: BTW, in my head I pronounce "uce" like the tail of "Bruce". { And yes I am
aware that UCE also stands for Unsolicited Commercial Email aka "spam".  I hope
you like this tool better than that, at least. ;-) }
