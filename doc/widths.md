Motivation
==========
Measuring text width (in proportional as well as mono-spaced fonts, but this
program is only about the latter) can be interesting for various reasons.  Here
are a few:

 1. Accessibility compliance; With aspect ratios from portrait mode smart phones
    to widescreen projectors, text width limits can matter more than ever.

 2. Code &| Text complexity metrics; Many will say all lines filling all text
    columns is hard to read, sometimes informally called "density".  Automated
    readability metrics might start with a width distribution.

 3. Automated paragraph end detection; Sometimes the only cue for paragraph
    boundaries in poorly formatted text is significantly shorter line than the
    "mode" of the width distribution, perhaps combined with punctuation.

Usage
=====
```
  widths [optional-params] [paths: string...]

Emit width/line lengths in bytes of all lines in files paths.

If histo emit an exact histogram of such widths.

Emits text if outKind==NUL, else binary in that NIO format.

Options:
  -o=, --outKind= char '\x00' emit binary stream with this NIO format
  -d, --distro    bool false  emit a histogram, not individual widths
```

Example
=======
```sh
$ widths doc/*.md | awk '$1>80'
168
168
106
106
106
106
106
106
106
```
You can `grep "^$(for i in {1..81}; printf .).*" doc/*.md` to list offenders and
decide if they should be wrapped. { Sometimes tabulation and URI non-splitting
trumps blind obedience to text width limits; "Accessibility" is not 1-D. }

```sh
$ widths doc/*.md | cstats
43.08 +- 0.60
```

Or an exact distribution:
```gnuplot
gnuplot> plot '<widths -d *.nim bu/*.nim' with impulses
```

Besides moments or exact distributions, you can use more float-oriented
[niom](niom.md).  E.g.:
```sh
$ widths -oi *.nim | niom -s,=,n,a,sd .Ni
.Ni:0 n: 3524. min: 0.000 max: 80.00 avg: 47.32 sdev: 24.96
```

shows summary stats on line widths for this source code repository at the time
of writing this document. (Note the `'i'` in `-oi` and `.Ni` must match.)

All `niom` information can be derived from the exact histogram, but if there
were many input lines and, say, you cared about "time series" properties for a
custom analysis the (tiny 19 lines of real logic) source code of `widths.nim`
shows how to use [nio](https://github.com/c-blake/nio) to "stay in binary".

Avoiding oft recommended but expensive binary -> ASCII -> binary conversion
cycles can sometimes mean orders of magnitude speed-ups.  E.g., running `widths
**.c >/dev/null` on Linux-6.2.8 source unpacked in /dev/shm (about 658 MB and
22.75e6 lines in ~32e3 files) took 17.5 seconds.  Simply adding in `-oi` took
the time down to 0.755s - over 23X faster.  Adding `|cstats` or `|niom` changes
these times to 26.33 & 1.00 because of parsing costs, a worse ratio.[^1] { Just
mapping files & framing lines with memchr via `widths -d **.c >/dev/null` takes
0.57sec or ~25ns/line. }

Related
=======
[ww](ww.md) has ways to re-word-wrap text that take a width as an input.  This
program is one way to maybe decide what length to give it.

[^1]: On a personal note, not trusting number parsing but especially formatting
to be "essentially free" was among my first lessons learning systems programming
decades ago.  The way "Unix philosophy" is often presented makes this a lesson
learnt anew generation after generation.  That is more a failure in teaching &|
affection for strings than a failure of using pipes/modular programs.  For more
details, see [nio](https://github.com/c-blake/nio).
