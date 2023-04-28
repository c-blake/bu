Motivation
==========
I keep hearing praise of ninja, but was skeptical.  So, I rolled my own output
freshener in ~60 lines of Nim originally.[^1]  Your own motivation might be an
*even simpler* syntax than ninja or arguably shell.  In the simplified problem
setting of 1-to-1 rules with related naming, all you need is 3 variables - stub,
input, and output, here `%s, %i, %o`.

I was a bit surprised to learn how few GNU make command options remain relevant
for this simpler problem.  I think I got all but -L/min(fileAge, linkAge) which
smelled non-portable to Windows/etc.

Anyway, over 40,000 lines of C for GNU make[^2] or 27,000 of C++ for Ninja
seemed silly for some of my use cases.  Mostly, though I was have long done
shell update scripts yet wondered what overhead that might be incurring.
Not much, as it turns out.

Usage
=====
```
  mk1 [optional-params] ip op cmd

A fast build tool for a special but common case when, for many pairs, just
1 input makes just 1 output by just 1 rule.  file has only "stubs", %s which are
interpolated into [io]p - the [io]paths used to test need and %[io] are then
interpolated into cmd (with POSIX sh single quotes).  This only prints commands.
Pipe to /bin/sh, xargs -n1 -P$(nproc).. to run. Egs.:

  touch a.x b.x; printf 'a\nb\n' | mk1 %s.x %s.y 'touch %o'
  find -name '*.c' | sed 's/.c$//' | mk1 %s.c %s.o 'cc -c %i -o %o'

Best yet, save file somewhere & update only if needed based on other context,
such as dir mtimes.  Options are gmake-compatible (where portable & sensible in
this much more limited role).

  -f=, --file=      string  "/dev/stdin" input file of name stubs
  -n=, --nl=        char    '\n'         input string terminator
  -m=, --meta=      char    '%'          self-quoting meta for %sub
  -x, --explain     bool    false        add #(absent|stale) at EOL
  -k, --keep        bool    false        keep going if cannot age %i
  -B, --always-make bool    false        always emit build commands
  -q, --question    bool    false        question if work is empty
  -o=, --old-file=  strings {}           keep %o if exists & is stale
  -W=, --what-if=   strings {}           pretend these %i are fresh
```

Motivating Example
==================
It is often easy to weave freshness checking into tools, such as my
[framed.nim](https://github.com/c-blake/ndup/blob/main/framed.nim).  Sometimes,
though, interfaces are beyond your control &| stdin/stdout just seem nice. E.g.:
```sh
find . -type f -print |
  mk1 -m@ @s /tmp/SHAs/@s 'sha256sum < @i > @o' | sh -x
```
is one way to create a "shadow" or "mirror" file tree where every file `foo/bar`
under "." gets a sha256 file under `/tmp/SHAs/foo/bar` (or wherever).

There are even more expensive hashes which would take weeks, not merely hours,
for example, perceptual hashes on video frames.

Evaluation
==========
A relatively easily reproduced benchmark usually helps to assess performance
which is what we do here, using a RAM filesystem to be fast & [ru](ru.md) since
times are short, but still doing 40,000 files:
```sh
#!/bin/sh
set -e  # This is an up-to-dateness benchmark for 40 KFiles
cd /dev/shm
rm -rf t-mk1
mkdir  t-mk1
cd     t-mk1
mkdir i o

echo "initial build"; ru bash -c '
for i in {0..9}; do
    mkdir i/abcd$i o/abcd$i
    for j in {0..9}; do
        mkdir i/abcd$i/efgh$j o/abcd$i/efgh$j
        for k in {0..9}; do
            mkdir i/abcd$i/efgh$j/ijkl$k o/abcd$i/efgh$j/ijkl$k
            touch i/abcd$i/efgh$j/ijkl$k/mnopq{0..39}.c \
                  o/abcd$i/efgh$j/ijkl$k/mnopq{0..39}.o
        done
    done
done'
find i -type f -name '*.c' -printf '%P\n' | sed 's/\.c$//' > inp

cat >build.ninja <<EOF
something = touch
rule makeIt
  command = \$something \$out
EOF
sed -e's/\([ :$]\)/$\1/g' \
    -e's@^\(.*\)$@build o/\1.o: makeIt i/\1.c@' < inp \
    >>build.ninja
echo "ninja ON UP-TO-DATE dirs"; ru ninja --quiet
echo "ninja second time"       ; ru ninja --quiet
echo "Now rm .ninja_log"       ; rm .ninja_log
echo "special, hacked ninja-nv, -t restat, freshness"
ru sh -c 'ninja-nv -nv >/dev/null; ninja -t restat; ninja --quiet'

echo "GNU make fresh check"
cat >Makefile <<EOF
.PHONY: all
all: \$(addprefix o/, \$(addsuffix .o,\$(shell cat inp)))
o/%.o: i/%.c; touch "\$@" # $< unused
EOF
ru make

echo "straight bash looping"
ru bash -c 'while read a; do
    [ "o/$a.o" -nt "i/$a.c" ] || printf "touch o/$a.o\n"
done' < inp > /dev/null

echo "Check freshness w/mk1"; ru mk1 i/%s.c o/%s.o 'touch %o' <inp
```
gives on an i7-1270P (Alder Lake) running Linux 6.2.10 built w/gcc-12:
```
initial build
TM      0.952648 wall    0.575243 usr    0.355604 sys     97.7 % 2.875 mxRM
IO      0.000000 inMB    0.000000 ouMB          0 majF  251142 minF  0 swap
ninja ON UP-TO-DATE dirs
TM      5.228888 wall   12.285471 usr    7.172243 sys    372.1 % 38.105 mxRM
IO      0.000000 inMB    0.000000 ouMB       4359 majF  4012090 minF  0 swap
ninja second time
ninja: no work to do.
TM      0.113218 wall    0.065915 usr    0.046916 sys     99.7 % 38.852 mxRM
IO      0.000000 inMB    0.000000 ouMB          0 majF    9939 minF  0 swap
Now rm .ninja_log
special, hacked ninja-nv, -t restat, freshness
ninja: no work to do.
TM      0.406945 wall    0.231055 usr    0.173422 sys     99.4 % 40.086 mxRM
IO      0.000000 inMB    0.000000 ouMB          0 majF   22173 minF  0 swap
GNU make fresh check
make: Nothing to be done for 'all'.
TM      1.376430 wall    1.302053 usr    0.070776 sys     99.7 % 82.262 mxRM
IO      0.000000 inMB    0.000000 ouMB          0 majF   32361 minF  0 swap
straight bash looping
TM      0.156478 wall    0.106107 usr    0.050059 sys     99.8 % 3.125 mxRM
IO      0.000000 inMB    0.000000 ouMB          0 majF     157 minF  0 swap
Check freshness w/mk1
mk1: no work to do
TM      0.040612 wall    0.006080 usr    0.034430 sys     99.7 % 2.750 mxRM
IO      0.000000 inMB    0.000000 ouMB          0 majF     113 minF  0 swap
```
GNU Make is indeed slow - over 34X worse than `mk1`.[^3]  But ninja's *best*
case is barely faster than the interpreted bash loop (156/113=1.38X).  `mk1` on
the other hand is ~3X faster than ninja's best case and ~4X faster than bash.

I learned what must be common knowledge among ninja users that achieving that a
best case depends strongly on `.ninja_log` files to avoid from-scratch builds
(and also that such from-scratch builds are oddly ~5.5X slower than the manual
shell touch loop - for undiagnosed reasons).

I found [a hack](
https://stackoverflow.com/questions/73058509/how-do-i-manually-populate-ninja-log-with-information-preventing-unnecesary-reb)
to fix this ninja deficiency which sort of works, but a simple bash loop still
is over 2.5X faster than that "smart but hacky" ninja way that first time.

So, either comparing against this new `mk1` thing or just bash, the "reputation"
seems to come more from make slowness than Ninja fastness.  Specifically, make's
time likely explodes when any work is delegated to complex subshells.

[^1]: It's more like 150 lines now.  But it can also support my custom Linux
kernel module that can speed things up in Spectre-Meltdown mitigation settings.

[^2]: To be fair, Nim does not support VMS or Amiga or whatever 1980s stuff.

[^3]: There are surely other approaches to my addprefix-addsuffix idea, such as
generating the whole file like build.ninja requires. Have at it, `make` fans! :)
