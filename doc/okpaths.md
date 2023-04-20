Basics
------
Usage:
```
okpaths ENVAR [DELIM(:) [ITYPE{bcdpfls}(d) [PERMS{rwx}(x) [DEDUP{FL*}(F)]]]]
```
The [] notation here indicates optionality and defaults are in ().

This program echos re-assembled value for `$ENVAR` delimited by ASCII character
`DELIM`.  Each retained element is i-node type `ITYPE` with permissions `PERMS`.

& optional de-duplication.

Eg., PATH=`okpaths PATH` keeps only existing (d)irs executable(x) by an invoking
user.  DEPDUP starting with 'F' means keep F)irst use, while 'L' keeps L)ast use
& other means no de-dup (this is case-insensitive).  So, eval `okpaths PATH` is
nice in rc/init scripts for Unix shells.

Blocks of the 5 params can repeat (since fork&exec add to shell init time).

The i-node type abbreviation is the somewhat standard (`ls -l` | `find`):
  * b   (B)lock device
  * c   (C)haracter device
  * d   (D)irectory
  * p   named (P)ipe/FIFO
  * f   Regular (F)ile
  * l   Symbolic (L)ink
  * s   Unix domain (S)ocket

Motivation
----------
`eval $(okpaths PATH : d rx u)` is useful in shell start-up scripts (like
`~/.profile`) where you might assemble a search path or man path or et cetera
from a variety of *possible* locations, but then want to trim the value down to
locations valid at shell init.

This trimming makes `echo $ENVAR` less noisy and may prevent annoying extra,
unneeded work during start-up of dependent programs.  Sometimes this extra work
can be quite a lot, (e.g. with a slow NFS automounter), although just running
`okpaths` will have to do it at least once.

Note that login shells can be very long-lived and FS availability dynamic.  So,
validity at `okpaths`/shell start-up-time is not a perfect solution.
