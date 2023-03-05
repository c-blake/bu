Motivation
----------
Device IO can be either very cheap (e.g. NVMe esp gen5) or very costly (e.g.
a network filesystem maybe capped 125 MiB/s {gigE}).  Either before or after
costly operations it can be interesting to know how well the OS has buffered
the data to prevent future reads.

Usage
-----
```
  fpr [optional-params] [paths: string...]

File Pages Resident. Examine UNION of paths & optional delim-delimited input
file (stdin if "-"|"" & stdin not a tty). Eg., find -print0 | fpr -d\0.  Like
util-linux fincore, but more Unix-portable & summarizing.

  -f=, --file=  string    ""      optional input ("-"|!tty=stdin)
  -d=, --delim= char      '\n'    input file delimiter (0->NUL)
  -e=, --emit=  set(Emit) summary Stuff to emit: summary detail
```

Related Work
------------
util-linux has `fincore`, but often I just want summary information and this is
easy to compute in-program than as a wrapper program.  Also, this program should
work fine on OS X or many BSDs where util-linux is probably not installed.
