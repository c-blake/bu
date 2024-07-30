Motivation
----------
Sometimes you have a pipeline emitting various numbers and you want to get (in
one pass since input is a pipeline, but also for memory bandwidth efficiency)
reports of the top-N (N biggest) according to various columns of the input.
This is what `topn` is for.  Internally, it is a very thin wrapper around
[adix/topk](https://github.com/c-blake/adix/blob/master/adix/topk.nim).

Usage
-----
```
  topn [optional-params] [specs: string...]

Write spec'd cols of topN-rows-by-various-other-cols to outFile's.

A spec is <n>[,<sort-key-col>(0)[,outCol(same)[,outFile(stdout)]]].

ColNos are Py-like 0-origin,signed.

Algo is fast one-pass over (mmap|stream) input.

Simple Eg: find . -type f -printf '%C@ %p\n' | topn -m1 5.

Fancy Eg: topn 9,1,-1,x writes last col of top 9-by-col-1 rows to file x.

If n!=0 then <n> can end in % to instead mean 100*pct/n rows.

Options:
  -i=, --input= string    "/dev/stdin" input data path
  -d=, --delim= string    " "          delimiting (repeats=>any num; "white")
  -m=, --mxCol= int       0            max columns in input to parse
  -n=, --n=     int       0            scale for '%' amounts
  -o=, --order= TopKOrder Cheap        order: Cheap, Ascending, Descending
  -p=, --partn= Partn     last         partition: last, ran
```

Very Simple Example
-------------------
```sh
$ paste <(seq 1 100) <(seq 1 10 1000) | topn 5
96      951
97      961
98      971
99      981
100     991
```

Fancier Example
---------------
This will recurse in `.` emitting c-time, m-time, and path names to a pipeline.
`topn` then collects the top-3 of the first column (0-origin column 0) and the
top-4 of the 2nd column (0-origin column 1) in bounded-size heaps (for the
curious) and emits the pathnames (0-origin column 2) of each to stdout.
```sh
find . -printf '%Cs %Ts %P\n' | topn  3,0,2  4,1,2
```
(Yes, this *exact* example is handled by [`newest`](newest.md); It's just an
example).

If you want output to separate files (or FIFOs), you can just add `",top3c"` and
`",top4m"` to the ends of the two parameters, for example.

If you want a top fraction like 10% (instead of an absolute number like "3")
then you can also get that if you provide upfront the scale via `-n` and also
tell `topn` to use it via, e.g., `topn -n4321 10%,0,2`.  (Yes, this is mostly
just a convenience to multiply 0.1 by 4321 - if you do not know `n` ahead of
time, a one-pass, tiny memory algo is not possible.)
