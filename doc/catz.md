Motivation
==========
There are many "quality of life" decoders - `zcat`, `bzcat`, `xzcat`, `lz4cat`,
`zstdcat`, the list goes on.  For each one (aping a pattern established by
`gzip`) there are "sometimes" variously some subset of `zgrep`, `zdiff`, `zcmp`,
etc. analogues.  Specialization duplication sucks.  One general decoder tool and
one per-use-case tool is better.[^1]  That's `catz`.

Briefly, `catz` generalizes `zcat` to many encodings, not merely `gzip`.  Tools
like `zgrep` are diverse - more or less by definition - and not yet distributed
here.  `s/zcat/catz/` is not a bad way to start, though.

Usage
=====
```
catz [ -l ] [ -d ] [ -v STDIN_NAME_VAR ] [ FILES [ - ] [ < FILE ] ]
```

`catz` prioritizes classifying by magic numbers of encoded files, but can also
use pathnames if available.  `catz -l` lists how `catz` classifies & exits.[^2]

It is easy to say `catz<input.xz` to force extension ignoring.  Conversely, `-v`
indicates the path for stdin is `$STDIN_NAME_VAR`.  Other paths are available
from the `catz` argument list.  Paths are only needed if chosen decoder programs
need them or if magic number recognition fails.

Just as with `cat(1)`, a lone minus sign ("-") path indicates how stdin should
be ordered within the emitted catenation. { Due to limitations in utilities to
deal with the format, .zip files given as paths will have all members catenated,
while only first members are extracted from unseekable zip inputs. }

A leading "-d" option is ignored for compatibility with GNU `tar -I`.

A Few Examples
==============
```sh
catz a.gz b.bz2 c.xz d.zs > /dev/null
catz < foo.tar.anyz | tar xpf -
export LESSOPEN="|-catz %s"
rg -l --pre=catz pattern /usr/share/man/man?
etc., etc.
```

Implementation Notes
====================
A one-file, seekable-input case allows simple replacement of the `catz` process
with a decoder process simply using the early bytes to decide dispatch to an
appropriate decoder exec(2) inheriting the needed file descriptors.  This avoids
any unnecessary context switching or copying.  Of course, relative to a library
solution, `exec` overhead still exists.[^3]

The N-file, named-argument case requires a 2-process setup in order to produce
an ordered, integrated output stream.  `catz` essentially does a `popen`-like
setup for each such named argument.

If no path name is available (e.g., stdin) or if the pathname does not have a
standard filename extension for compressed files, then an early byte magic is
the only way to identify decoders.  A decoder itself will (usually) also insist
on this magic number being present.  "Un-reading" data from a pipe buffer while
maybe theoretically possible (especially before the other side has written) is
not generally available.  So, unseekable inputs require an IO copy loop to
replace the magic number bytes.  `catz` forks a new process to do this on a new
pipe buffer and in this case cannot replace itself with a decoder.

Related Work
============
Simple dispatch via file extension such as what
[`anycat`](https://github.com/eruffaldi/anycat/blob/master/anycat.sh) does is
likely a learning exercise in many university courses. So, a file/libmagic-based
work probably exists, but libmagic is also kinda slow.  I'm unaware of another
tool that works in `...|catz` settings.[^4]

[^1]: Of course, zero decoders and the original utilities are even better *and*
this can be done with compressed/encoded block devices, file systems, and FUSE
auto-decoder filesystem wrappers.  Sadly these ideas post-date what most folks
think of as minimum viable OS services.  Often one wants more portable tools for
reasons.

[^2]: Yes, it would be better to have a `~/.config/catz` direct this but then
you need a syntax.  As it is, personally I have only had to change the compiled
in table a handful of times in almost 25 years.  (Short) PRs welcome.  The impl
already assumes zero bytes cannot occur in magic numbers.  Add TAB & Newline &
document that and the listing format itself could serve.

[^3]: That can be minimized by static linking of catz, decoders, or both.  A way
to specify `.so:open/decode/close` transformers could make for 1-exec not 2. The
ideal 0-exec would need an in-end-requesting-process `zopen` meta-library (but
that entails either dynamic linking & `LD_PRELOAD` tricks or a PL-specific API).

[^4]:  Happy to put in citations if you tell me.
