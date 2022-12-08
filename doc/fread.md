Motivation
----------

Sometimes you want to ensure a hot-cache or measure only pure read behavior.

For example:
```sh
dd if=/dev/zero blocksize=16384 count=16384 | fread
fread *.dat & # get pre-loading of all that going.
```

Usage
-----
```
  fread [optional-params] paths: paths to read in

This is like cat, but just discards data.  Empty paths => just read from stdin.
That can be useful to ensure data is in an OS buffer cache, measure drive/pipe
throughput, etc.  Eg. in Zsh you can say: fread **.

Users may pass paths to FIFOs/named pipes or other block-on-open special files.
We want to skip those but also avoid check-then-use races.  So, open O_NONBLOCK,
but then immediately fstat to skip non-regular & reactivate blocking with fcntl
to be CPU-sharing-friendly.

  -b=, --bsz=   int 16384 buffer size for IO
```
