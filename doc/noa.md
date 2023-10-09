Motivation
==========
Long ago Unix (in `getopt`) and later POSIX standardized upon a `"--"` token as
a separator between command options and ordinary arguments.  However, many
commands on Unix (and elsewhere!) have behavior sensitive only to the location
of ordinary arguments.  E.g., the final argument of `cp` & `mv` behave very
differently from all the others.  Together these two features complicate writing
reliable scripts that wrap such commands to, say, create a target directory only
if it does not already exist.

This is where this simple program called `noa` comes in to simplify life.[^1]
`noa` extracts command parameters by index over only the non-option arguments.
Here indices are signed like Python with <0 indicating "backwards from the end".
Some programs (to be more `xargs` friendly, say) may take similar dependencies
like `cp` & `mv` but at index 0.  But `noa` is a general non-option indexer.

Usage
=====
```
(n)on-(o)ption (a)rgument usage:

  noa {index} options-and-args

E.g.: noa -1 cp -a foo -f -- /exists/maybe/missing
emits "/exists/maybe/missing" no matter where "--" is.
Can be nice in scripts to e.g. ensure must-haves exist.
```
Note that `noa -1 ...` even works with a trailing non-argument `"--"` separator.

Example Script
==============
One example application of this non-option argument indexing idea is a simple
but somewhat general meta-wrapper script below named `ea`.  This makes it easy
to issue
```
ea mv -v -n -- foo /exists/maybe/missing
```
and have it work even if `/exists/maybe/missing` does not exist yet with just a
few extra keystrokes.  Here is a somewhat careful/complete `ea` in POSIX shell
in terms of `noa`:

```sh
#!/bin/sh
set -e
: "${idx:=-1}"              # final non-option parameter targets are frequent
: "${make:=mkdir -p --}"    # mkdir -p is often an ok idea for missing targets
if [ $# -lt 1 ]; then
    cat <<EOF
E)nsure A)rgument Usage:
  [idx=-1] [make="mkdir -p --"] [v=] ea {cmd needing an argument to exist}
where
  \$idx  is a Python like 0-origin or length-relative negative index
  \$make is a prefix to a command to create the argument if missing
  \$v    set to anything means echo \$make before running it
E.g.:
  ea cp -a foo -f -- /exists/maybe/missing
  v= ea mv -v -n -- foo /exists/maybe/missing
EOF
    exit 1
fi
if ! type noa >/dev/null 2>&1; then
    echo 1>&2 'Need to install `noa` from https://github.com/c-blake/bu'
    exit 2
fi
noa "$idx" "$@" | (         # Carefully d=`noa $idx $*`; [ -e $d ] || $make $d
    n='
'                           # read -rd works in Bash|Zsh, but not POSIX.  So,
    while IFS= read -r line #..loop which works for all text but input with no
    do d="$d${line}$n"      #..final newline where we add one "erroneously".
    done; d=${d%?}          # Chop extra newline
    [ -e "$d" ] || {        # not -d since some cmds have -f to replace files
        [ -n "${v+ANY}" ] && printf '%s\n' "$make $d"
        $make "$d"          # Make needed argument $d
    } )
exec "$@"                   # Then just run passed command
```

[^1]: It could likely be written reliably in pure shell (have at it!), but `noa`
is also very simple in lower level languages (even as low as ANSI C).
