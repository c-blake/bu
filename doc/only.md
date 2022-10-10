Motivation
----------
People often want to know what kind of file something is.  For a long time,
Apple had some whole resource fork in its FS for this metadata.  Maybe it still
does.  On Unix the tradition is a magic number and something like `file(1)` or
`libmagic(3)` that instead opens & partially parses files.  This procedure is,
however, very slow and often CPU bound (depending upon what the OS has cached).

Cost is relative, of course.  For one file it does not take long in human terms,
but you can have a *lot* of files.  Modern CPUs have many cores to deploy work
to along these lines, but at least the Linux libmagic is very MT-UNSAFE.  So,
forked kids are the best way to go multi-core and cligen/procpool is an easy
way to do that.  This program was basically the original motivation for procpool
in Nim and its original demo program.

One example usage might be `rm $(only ELF)` as a kind of ghetto "make clean",
assuming you have a way to rebuild any ELF object files that is.

Usage
-----
```
  only [optional-params] [patterns: string...]

Use gen and dlr1 to generate paths, maybe skip trim and then emit any path
(followed by eor) whose file(1) type matches any listed pattern.

all & no can combine to mean not all patterns match.

  -g=, --gen=   string    "find $1 -print0" generator cmd with dlr1 -> $1
  -d=, --dlr1=  string    "."               $1 for gen fmt; Eg. ". -type f"
  -t=, --trim=  string    "./"              output pfx to trim (when present)
  -e=, --eor=   char      '\n'              end of record delim; Eg.'\0'
  -a, --all     bool      false             all patterns match (vs. any)
  -n, --no      bool      false             no patterns match (vs. any)
  -i, --insens  bool      false             regexes are case-insensitive
  -x=, --excl=  set(Excl) {}                tests to exclude like file(1)
  -j=, --jobs=  int       0                 use this many kids (0=auto)
```

Related Work
------------
`find|xargs -PN stdout -oL file -F:Xx:|grep ":Xx: .$@"|sed -e 's/:Xx: .$//'` is
slower & needs some ":Xx:" delimiter guaranteed to be neither in paths nor types
and does not have all the boolean combiner gadgets.  There is probably a way to
make it work with some xargs helper program, though it is debatable if that is
simpler than the Nim code.
