Motivation
----------

Sometimes you want to ensure hot-cache or cold-cache or measure only pure read
behaviors.

For example:
```sh
dd if=/dev/zero blocksize=16384 count=16384 | fread
fread *.dat & # get pre-loading of all that going.
```

Usage
-----
```
  fread [optional-params] paths: paths to read in

This is like `cat`, but just discards data.  Empty `paths` => just read from
stdin.  That can be useful to ensure data is in an OS buffer cache or try to
evict other data (more portably than /proc/sys/vm/drop_caches) for cold-cache
runs, measure drive/pipe or device throughput, etc.  Eg. in Zsh you can say:
`fread \*\*` or `fread -l $((1<<30)) < /dev/urandom`.

Users may pass paths to FIFOs/named pipes/other block-on-open special files
which are skipped.  Anything named is only used if mmap-able & only 1 byte
(really 1 cache line) per 4096 is used by the process.  Can use multiple passes
to measure DIMM bandwidth through a CPU prefetching lens.

Options:
  -b=, --bsz=   int   65536 buffer size for stdin IO
  -l=, --lim=   int64 0     max bytes to read; 0=>unlimited
  -n=, --nPass= int   1     passes per file
  -o=, --off=   int   64    total [off0-origin-pass within pages]
  -v, --verb    bool  false print bytes read
```

Example:
--------
As just one example benchmark-y kind of sketch, we can easily create a 1 GiB
file from `/dev/urandom`[^1], and then (w/`taskset` & `chrt`[^2] to lessen
noise) loop over a series of numbers of passes and fit run times to a [linear
model](https://github.com/c-blake/fitl):

```sh
export j=/dev/shm/junk
dd if=/dev/random of=$j bs=32k count=32k
taskset -c 2 chrt 99 sh -c \
 'for n in `seq 1 64`;do printf "$n ";fread -vn$n $j;done'|
  fitl -b99 -c,=,n,b 6 0 1
```
That yields for me, on one rather old bare metal machine:
```
$6= 0.070379 + 1.32172e-03 *$1

bootstrap-stderr-corr matrix
 0.0001110    -0.8542
            3.245e-06
```
The very small errors on slope & intercept suggest a good fit & the fit suggests
initial pass time of 70.38 +- 0.11 ms & per pass times of 1.3217 +- 0.0032 ms.
Since each pass after the first only hits one 64B cache line per page this
translates to about 1./64/1.3217e-3 =~ 11.82 GiB/s throughput.

Of course, there is more going on than *only* memory transfer (not a lot more!),
but this is also just one example benchmark.  `perf stat` (on Linux, anyway) may
afford a more refined understanding of this kind of throughput.  Similarly, a
smaller 2MiB file on a HugeTLB FS might eliminate all TLB misses to study L3 CPU
cache bandwidth (or even L2 for some CPUs these days).[^3]  And so on.  Data
moves around in many ways and data motion is often a bottleneck and `fread` is
here usually just one piece of a bigger puzzle.

[^1]: Or maybe by `cp somebigfile $j; truncate -s $((1024*1024*1024))`, etc.

[^2]: On Linux anyway..

[^3]: Measuring IO *itself* is also only one application of `fread`.  The
original inspiration was eliminating IO time from *other* benchmarks.
