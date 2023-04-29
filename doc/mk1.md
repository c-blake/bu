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

A fast build tool for a special but common case when, for many pairs, just 1
inp makes just 1 out by just 1 rule.  file has back-to-back even-odd already
quoted if necessary input-output pairs.  If ages indicate updating, %[io] are
interpolated into cmd.  mk1 only prints commands.  To run, pipe to /bin/sh,
xargs -n1 -P$(nproc)..  E.g.:
  touch a.x b.x; printf 'a.x\na.y\nb.x\nb.y\n' | mk1 'touch %o'

Ideally, save file somewhere & update that only if needed based on other
context, such as dir mtimes.  Options are gmake-compatible (where sensible in
this much more limited role).

  -f=, --file=      string  "/dev/stdin" input file of name stubs
  -n=, --nl=        char    '\n'         input string terminator
  -m=, --meta=      char    '%'          self-quoting meta for %sub
  -x, --explain     bool    false        add #(absent|stale|forced) @EOL
  -k, --keep        bool    false        keep going if cannot age %i
  -B, --always-make bool    false        always emit build commands
  -q, --question    bool    false        question if work is empty
  -o=, --old-file=  strings {}           keep %o if exists & is stale
  -W=, --what-if=   strings {}           pretend these %i are fresh
```

A Motivating Example
====================
It is often easy to weave freshness checking into tools, such as my
[framed.nim](https://github.com/c-blake/ndup/blob/main/framed.nim).  Sometimes,
though, interfaces are beyond your control &| stdin/stdout just seem nice. E.g.:
```sh
find . -type f -print | tmpls %s /myHashes/%s |
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
cd /dev/shm             # Elim device IO, clean-up & set-up
rm -rf t-mk1; mkdir t-mk1; cd t-mk1; mkdir i o

echo "initial build"; ru -ht bash -c '
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
echo "ninja ON UP-TO-DATE dirs"; ru -ht ninja --quiet
echo "ninja second time"       ; ru -ht ninja --quiet
echo "Now rm .ninja_log"       ; rm .ninja_log
echo "special, hacked ninja-nv, -t restat, freshness"
ru -ht sh -c 'ninja-nv -nv >/dev/null; ninja -t restat; ninja --quiet'

echo "GNU make fresh check"
cat >Makefile <<EOF
.PHONY: all
all: \$(addprefix o/, \$(addsuffix .o,\$(shell cat inp)))
o/%.o: i/%.c; touch "\$@" # $< unused
EOF
ru -ht make

echo "straight bash looping"
ru -ht bash -c 'while read a; do
    [ "o/$a.o" -nt "i/$a.c" ] || printf "touch o/$a.o\n"
done' < inp > /dev/null

tmpls i/%s.c o/%s.o < inp > inp2 # `tim` sez (3.76+-0.04)ms
echo "Check freshness w/mk1"; ru -ht mk1 'touch %o' < inp2
```
gives on an i7-1270P (Alder Lake) running Linux 6.2.10 built w/gcc-12:
```
initial build
TM      1.112654 wall    0.610959 usr    0.471952 sys     97.3 % 3.000 mxRM
ninja ON UP-TO-DATE dirs
TM      7.777944 wall   15.247225 usr   22.734465 sys    488.3 % 37.859 mxRM
ninja second time
ninja: no work to do.
TM      0.119358 wall    0.073478 usr    0.045673 sys     99.8 % 38.980 mxRM
Now rm .ninja_log
special, hacked ninja-nv, -t restat, freshness
ninja: no work to do.
TM      0.410272 wall    0.235480 usr    0.172278 sys     99.4 % 40.180 mxRM
GNU make fresh check
make: Nothing to be done for 'all'.
TM      1.550844 wall    1.432694 usr    0.114489 sys     99.8 % 82.133 mxRM
straight bash looping
TM      0.151993 wall    0.099890 usr    0.051956 sys     99.9 % 3.125 mxRM
Check freshness w/mk1
mk1: no work to do
TM      0.039390 wall    0.005039 usr    0.034388 sys    100.1 % 3.875 mxRM
```
GNU Make is indeed slow - ~40X worse than `mk1`.[^3]  But ninja's *best* case is
barely faster than the interpreted bash loop (152/119=1.28X).  `mk1` on the
other hand is ~3X faster than ninja's best case and ~4X faster than bash.

I learned what must be common knowledge among ninja users -- achieving that best
case depends strongly on `.ninja_log` files to avoid from-scratch builds (and
also that such from-scratch builds are oddly ~7X slower than the manual shell
touch loop - for undiagnosed reasons, but worsened by lower parallelism).

I found [a hack](
https://stackoverflow.com/questions/73058509/how-do-i-manually-populate-ninja-log-with-information-preventing-unnecesary-reb)
to fix this ninja deficiency which sort of works, but a simple bash loop still
is over 2.5X faster than that "smart but hacky" ninja way that first time.

So, either comparing against this new `mk1` thing or just bash, the "reputation"
seems to come more from make-slowness than Ninja-fastness.  Specifically, make's
time likely explodes when any work is delegated to complex subshells.

[^1]: It's more like 150 lines now, but can also support my custom Linux kernel
module that can get 2X+ speed ups in Meltdown-Spectre mitigation settings where
it winds up over 4X faster than ninja.  https://github.com/blackmius/nimuring
ought to yield similar results.

[^2]: To be fair, Nim does not support VMS or Amiga or whatever 1980s stuff.

[^3]: There are surely other approaches to my addprefix-addsuffix idea, such as
generating the whole file like build.ninja requires. Have at it, `make` fans! :)
