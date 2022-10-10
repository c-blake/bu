Motivation
----------
This is a very small program, mostly recapitulating functionality from GNU `du`
that began just as a simple cligen/examples program, but might conceivably have
broader use/popularity.

Some of the value add differences are adding some missing short form flags for
commonly desirable giga/tera/peta `--block-size=`s, de-conflating a few baggage
of history things like shell patterns vs. regexes & --bytes => apparent-size.

(Also, it does not try to do anything with file times.  That seems like weird
mission creep in the GNU `du`.)

Usage
-----
```
  du [optional-params] [roots: string...]

Mostly compatible replacement for GNU du using my 1.4-2x faster file tree walk
that totals st_blocks*512 with more/better short options.  Notable differences:
  drops weakly motivated options {time, [aDHt], max-depth, separate-dirs}
  outEnd replaces null|-0; patterns are all PCRE not shell and need ".*"
  bytes does not imply apparent-size
  dereference does not imply chase.

Options:
  -?, --help                          print this cligen-erated help
  -f=, --file=          string  ""    optional input ("-"|!tty=stdin)
  -d=, --delim=         char    '\n'  input file record delimiter
  -x, --one-file-system bool    false block recursion across devices
  --chase               bool    false chase symlinks in recursion
  -L, --dereference     bool    false dereference symlinks for size
  -a, --apparent-size   bool    false instead total st_bytes
  -i, --inodes          bool    false instead total inode count
  -l, --count-links     bool    false count hard links multiple times
  -X=, --exclude-from=  string  ""    exclude all pattern(s) in named file
  -e=, --exclude=       strings {}    exclude paths matching pattern(s)
  -b, --bytes           bool    false like --block-size=1
  -k, --kilo            bool    false like --block-size=1[Kk] (DEFAULT)
  -m, --mega            bool    false like --block-size=1[Mm]
  -g, --giga            bool    false like --block-size=1[Gg]
  -t, --tera            bool    false like --block-size=1[Tt]
  -p, --peta            bool    false like --block-size=1[Pp]
  -B=, --block-size=    string  ""    units; CAPITAL sfx=metric else binary
  -s, --summarize       bool    false echo only total for each argument
  --si                  bool    false -[kmgt] mean powers of 1000 not 1024
  -h, --human-readable  bool    false print sizes in human readable format
  -c, --total           bool    false display a grand total
  -o=, --outEnd=        string  "\n"  output record terminator
  -q, --quiet           bool    false suppress most OS error messages
```
