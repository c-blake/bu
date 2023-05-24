Motivation
----------
This is (mostly) a convenience program for something I often want to know.

Usage
-----
```
  newest [optional-params] [paths: string...]

Echo ended by outEnd the <= n newest files in file time order {-}[bamcv] for
Birth, Access, Mod, Ctime, Version=max(MC); { - | CAPITAL means oldest }.

Examined files = UNION of paths + optional delim-delimited input file (stdin
if "-"|if "" & stdin is not a terminal), maybe recursed as roots.

E.g. to echo the 3 oldest regular files by m-time under the CWD:
  newest -t-m -n3 -r0 .

Options:
  -n=, --n=       int           1     number of 'newest' files
  -t=, --time=    string        "m"   timestamp to compare ({-}[bamcv]*)
  -r=, --recurse= int           1     recurse n-levels on dirs; 0:unlimited
  -c, --chase     bool          false chase symlinks to dirs in recursion
  -D, --Deref     bool          false dereference symlinks for file times
  -k=, --kinds=   set(FileKind) file  i-node type like find(1): [fdlbcps]
  -q, --quiet     bool          false suppress file access errors
  -x, --xdev      bool          false block recursion across device boundaries
  -o=, --outEnd=  string        "\n"  output record terminator
  -f=, --file=    string        ""    optional input ("-"|!tty=stdin)
  -d=, --delim=   char          '\n'  input file record delimiter
  -e, --eof0      bool          false set eof0
```

Related Work
------------
`find -printf` does not support the new-ish Linux b-time.  Even if it did one
would need to pipe its output to something like `topn 3` (which also does not
exist) that maintained a heap sorted by the desired time (in the desired order)
to be as memory efficient.  `sort` is highly wasteful for this use case.

This also uses my `cligen/dents` tree walker to be faster than `find` (much
faster with `-d:batch` & a custom kernel module) on Linux.  GNU `find` worries
about arbitrary FS depth while I've never seen a (non-artificial) depth > 30.
Common cases should not suffer from pathologies.  Default open fd limits that
hail from 1970s memory costs are are already pretty dumb.
