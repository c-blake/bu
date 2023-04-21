Motivation
==========
ANSI CSI/OSC/SGR color escape sequences are divisive.  Many enjoy the extra,
categorical emphasis colors can yield.  Others dislike their interference with
tools oriented around unembellished text.  One compromise is `$NOCOLOR`, as
advocated by https://nocolor.org/.  Another idea is an easy tool to wedge into a
pipeline to sanitize input for a next stage &| to test "uncolored readability"
(e.g. for the color blind).

In the latter case, a simple `sed 's/[[^m]*m//g'` filter "mostly" does the job,
*but* corner cases of [CSI/OSC syntax](en.wikipedia.org/wiki/ANSI_escape_code)
exist not handled by the above.  E.g., a stray newline embedded in an Esc-[..
can cause trouble.  So, a new, more careful filter utility is motivated.

Usage
=====
`noc` (short for "nocolor" or "noCSIOSC") is just a standard input-to-standard
output filter with no options or other command syntax.

If given a whole, memory mappable file, `noc` does a single pass.  Otherwise a
stdio buffered mode is used.

A Subtlety
==========
Broken &| hostile input can leave a CSI/OSC construct unterminated potentially
to EOF.  This can cause expansion of an IO buffer to all-input and more notably,
unless one propagates parser state across buffers, a parse re-start after each
read, repeating work & making total CPU time quadratic (to emit very little!).
So, while a naive take away reading the code might seem like "Much sound & fury
to optimize work non-repetition", it's actually there to work on bad input.

For example, one can create a 100 MB file of input:
```sh
$ printf '\e]%100000000sm' | tr ' ' '\n' > /dev/shm/hard
```
This input breaks a 3.5-ish second `sed` (producing 100 MLines of output, not 0
bytes).  It also blows up CPU time on a naive buffered implementation of `noc`
to many more seconds.  But `noc` itself dispatches the work in 38 millisec as a
whole file and about 135ms in a pipeline[^1], producing correct, empty output
both ways at about 750..2600 MB/s.[^2]

[^1]: While faster here, the memory mapped way was more done to verify the more
complex, pipeline-friendly buffered implementation.

[^2]: This is fast enough for my purposes here - hey 25-100X faster than a `sed`
that I never felt too slow. `cligen/textUt.noCSI_OSC` only works byte-at-a-time.
So, `memchr`-like SIMD optimization (possibly just using `memchr-\e`) can surely
speed it up, at the cost of substantial complexity; CFRO anyone?  ;-)
