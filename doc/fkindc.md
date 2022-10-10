Motivation
----------

People often want to know what kind of files are within some file tree.  This
produces a nice little histogram of file(1)/libmagic(3) file types.  See the
[only doc](only.md) for more background.

Usage
-----
```
  fkindc [optional-params] 

Use gen and dlr1 to generate paths and histogram by file(1) type.

  -g=, --gen=   string    "find $1 -print0" generator cmd with dlr1 -> $1
  -d=, --dlr1=  string    "."               $1 for gen fmt; Eg. ". -type f"
  -x=, --excl=  set(Excl) {}                tests to exclude like file(1)
  -j=, --jobs=  int       0                 use this many kids (0=auto)
```

Related Work
------------
This could probably have just been a new flag to `only`, but the code to do
just this is quite a bit simpler.  New option or new program is often a tough
judgement call.
