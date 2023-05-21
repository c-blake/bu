Motivation
----------

https://github.com/c-blake/ndup has a POSIX shell script, sh/ndup which keeps
a mirrored set of files related to some source files.  A natural course of file
management (especially with duplicate/near duplicate removal in play) is the
user creating new files or directories, renaming old ones, etc.  With any sort
of mirrored hierarchy of derived files, this induces a need to clean up stale
derivations.  This is what `notIn` helps do.

The salient line in the above mentioned script is:
```sh
notIn -f$w/f0 $w/digs $w/sets | xargs -0 rm -fv
```
This will remove any files under digs/ or sets/ that are *not* in the path list
file `f0` (hence the program name `notIn`).

I have not used it for this personally, but another example use case might be a
parallel hierarchy used for `lc -X,--extra` extra parameter values for
[lc](https://github.com/c-blake/lc) only just where a user has permission to
write.  In this case, due to the nature of `lc`, you probably only care about
stale directories.

In general, parallel file trees can be an interesting tool both conceptually
and practically and `notIn` can help to maintain them/query disparities/etc.

Usage
-----
```
  notIn [optional-params] [roots: string...]

Find files under roots NOT matching pattern applied to any file entry.  E.g.:
  (cd D1; find . -print0) | notIn D2 D3 | xargs -0 echo
echoes every entry under D2 or D3 not also under D1.

Input paths are normalized to nix empty parts (e.g. 1st&3rd in "./foo/./bar").

find -path A -o -path B .. can do this, but is hard for many paths.

  -f=, --file=    string ""     delimited input ( "" => stdin )
  -d=, --delim=   char   '\x00' input path delimiter
  -t=, --term=    char   '\x00' output path terminator
  -p=, --pattern= string "$1"   a $1-containing under roots pattern
  -v, --invert    bool   false  find files that do match a file entry
```
