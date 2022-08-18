`lncs` (pronounced links) is much like `cligen/examples/dups` but for clusters
of hard-links, not elsewise duplicate files.

`lncs` searches within paths of maybe-chasing, maybe-recursive closure of the
UNION of roots and optional dlm-delimited input file (stdin if "-"|if "" & stdin
not a tty).

Exit code is min(255, num.clusters >= thresh).

Eg.,
```
find -print0|lncs -d\0 -o\0 -e\0
```
makes a report reliably splittable on double-NUL then single-NUL for fully
general path names while `lncs -ls -n0 -r0 /` echoes a summary.

There are a few knobs to filter out some common cases like small files or
only include regular files, etc., but `find` can of course do all this and
much more as an input generator.

```
Usage:
  lncs [optional-params] filesystem roots

  -f=, --file=    string        ""    optional input ("-"|!tty=stdin)
  -d=, --dlm=     char          '\n'  input file delimiter (0->NUL)
  -r=, --recurse= int           1     recurse n-levels on dirs; 0:unlimited
  -c, --chase     bool          false follow symlinks to dirs in recursion
  -X, --xdev      bool          false block recursion across device boundaries
  -0, --eof0      bool          false read dirents until 0 eof
  -k=, --kinds=   set(FileKind) file  i-node type like find(1): [fdlbcps]
  -m=, --minSize= int           0     minimum file size
  -t=, --thresh=  int           2     smallest hard link cluster to count
  -q, --quiet     bool          false suppress file access errors
  -l=, --log=     set(LncsLog)  osErr >stderr{osErr, summary}
  -n=, --nEcho=   int           -1    num to print; 0: none; -1: unlimited
  -., --noDot     bool          false remove a leading . from names
  -o=, --outDlm=  string        "\t"  output internal delimiter
  -e=, --endOut=  string        "\n"  output record terminator
```
