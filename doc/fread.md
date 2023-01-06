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

Users may pass paths to FIFOs/named pipes or other block-on-open special files.
We want to skip those but also avoid check-then-use races.  So, open O_NONBLOCK,
but then immediately fstat to skip non-regular & reactivate blocking with fcntl
to be CPU-sharing-friendly.

Options:
  -b=, --bsz=    int     16384  buffer size for IO
  -l=, --limit=  uint64  0      max bytes to read; 0=>unlimited
```
