Motivation
----------
This is (mostly) a convenience program for something I often want to know or
do in scripts.

Usage
-----
```
  since [NEED,optional-params] [paths: string...]

Print files whose time is since|before refTime of refPath.

Files examined = UNION of paths + optional delim-delimited input file (stdin if
"-"|if "" & stdin is not a terminal), maybe recursed as roots.

To print regular files m-older than LAST under CWD:
    since -t-m -pLAST -r0 .

Options:
  -p=, --refPath= string        NEED  path to ref file
  -T=, --refTime= string        ""    stamp of ref file to use (if different)
  -t=, --time=    string        "m"   stamp to compare ({-}[bamcv]*)
  -r=, --recurse= int           1     recurse n-levels on dirs; 0:unlimited
  -c, --chase     bool          false chase symlinks to dirs in recursion
  -D, --Deref     bool          false dereference symlinks for file times
  -k=, --kinds=   set(FileKind) file  i-node type like find(1): [fdlbcps]
  -q, --quiet     bool          false suppress file access errors
  -x, --xdev      bool          false block recursion across device boundaries
  -f=, --file=    string        ""    optional input ("-"|!tty=stdin)
  -d=, --delim=   char          '\n'  input file record delimiter
  -e, --eof0      bool          false read dirents until 0 eof
  -n, --noDot     bool          false remove a leading . from names
  -u, --unique    bool          false only print a string once
```
Related Work
------------
GNU `find -*newer` does not support the new-ish Linux b-time and is also slow.
