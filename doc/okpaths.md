Basics
------
Usage:
```
okpaths ENVAR [DELIM(:) [ITYPE{bcdpfls}(d) [PERMS{rwx}(x) [DEDUP{FL*}(F)]]]]
```
The [] notation here indicates optionality and defaults are in ().

This program echos re-assembled value for `$ENVAR` delimited by ASCII character
`DELIM`.  Each retained element is i-node type `ITYPE` w/permissions `PERMS`.
E.g., PATH=`okpaths PATH` keeps only existing (d)irs executable(x) by the
invoking user.  If the final `DEPDUP` parameter starts with '[fF]', this means
keep only the first reference, while starting with '[lL]' keeps the last last &
any other character means no de-dup at all.

The i-node type abbreviation is the somewhat standard (ls -l):
  * b   (B)lock device
  * c   (C)haracter device
  * d   (D)irectory
  * p   named (P)ipe/FIFO
  * f   Regular (F)ile
  * l   Symbolic (L)ink
  * s   Unix domain (S)ocket

Motivation
----------
This is useful in shell start-up scripts (like `~/.profile` or the like) where
you might assemble a search path or man path or et cetera from a wide variety
of "possible locations", but then want to trim the value down to realizable
locations (at the run-time of `okpaths`, anyway).

This trimming makes `echo $ENVAR` less noisy and may prevent annoying extra,
unneeded work during start-up of dependent programs.  Sometimes this extra work
can be quite a lot, (e.g. with a slow NFS automounter), although just running
`okpaths` will have to do it at least once.
