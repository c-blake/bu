Usage
-----
```
  funnel [optional-params] FIFOs...

Read term-terminated records from FIFOS fs as ready, writing ONLY WHOLE records
to stdout.

Options:
  -f=, --fin=   string ""    once fin exists, empty pipes => end
  -r, --rm      bool   false unlink FIFOs fs when done
  -t=, --term=  char   '\n'  IO terminator
  -u=, --uterm= Unterm add   unterminated last record: add=Add term as needed
                             log=write labeled to stderr; drop=discard data
  -s=, --sec=   float  0.002 select timeout in seconds
  -i=, --ibuf=  int    4096  initial input buf size (doubled as needed)
  -o=, --obuf=  int    65536 output buf size
```

Motivation
----------
`tail -q -n+1 -f --pid=stopIfGone A B..` is wary of partial lines with input
from stdin pipes but NOT multi-input FIFOs.  If you are ok with PID wraparound
races, this program may be unneeded -- someday.  If you are not or that never
gets fixed then this program may be useful to you.

Example `xargs` Wrapper Script
------------------------------
This is a somewhat careful/general POSIX shell script with under 25 lines of
real logic called `xa` that uses `funnel` to ease using `xargs -P`:
```sh
#!/bin/sh
if [ $# -lt 1 ]; then cat 1>&2 <<EOF
Wrap GNU findutils (xa)rgs -P\${j:-\$(nproc)} to combine terminated outputs (out
of order) via temporary FIFOs & \`funnel\` respecting record boundaries.  E.g.:

  find . -print0| xa -0 sh -c 'grep "X.*Z" "\$@" >"\$XA/o/\$XA_SLOT"' d0 |sort
                     ^anyXArgsOpts

\$XA/e/* can also be used to combine command stderrs to stderr of this script.
You can override XA_SIGS:="HUP INT TERM" to adjust cleanup-implying signals.
j=<integer> controls GNU xargs parallelism as in \`j=3 xa -0 program\`.
EOF
    exit 1
fi
: ${j:=$(nproc)}
: ${XA_SIGS:="HUP INT TERM"}    # Overridable list of signals that imply cleanup
if [ "${XA-UNSET}" = "UNSET" ]; then
    XA=$(mktemp -d -- "${TMPDIR:-/dev/shm}/xa.XXX") || {
        echo 1>&2 mktemp FAILED; exit 1; }
    XA_WAS_MADE=1
fi
export XA                       # --,"$XA" make even TMPDIR="-a b" work
clean() { [ "${XA_WAS_MADE-0}" -eq 1 ] && rm -r -- "$XA"; }
for s in $XA_SIGS; do trap "clean; trap - $s EXIT; kill -s $s "'"$$"' $s; done
trap clean EXIT

[ -d "$XA/o" -a -d "$XA/e" ] ||
    mkdir -p -- "$XA/o" "$XA/e" # stdout & stderr FIFO dirs

[ -p "$XA/o/0" ] || eval mkfifo -- $(i=0
    while [ $i -lt $j ];do      # xargs process-slot-var uses 0 .. maxProc-1
        echo \"$XA\"/o/$i \"$XA\"/e/$i
        i=$((i+1))
    done)
# Launch funnels first, then xargs, then tell funnel writers are done.
[ -e "$XA/.fin" ] && rm -f -- "$XA/.fin"    # Just to be sure
${XA_TP-"funnel"} -f"$XA"/.fin -- "$XA"/e/* 1>&2 &
${XA_TP-"funnel"} -f"$XA"/.fin -- "$XA"/o/* &
xargs --process-slot-var=XA_SLOT -P "$j" "$@"
echo>"$XA/.fin"                 # Tell funnel writers are dead

wait                            # Wait for funnel to finish
```
Yes, yes.  It could probably be even more careful & general or, with more
assumptions (e.g. temp space, bash, EPOCHREALTIME) it could also be much
simpler, not even requiring `funnel`.  I tried to strike a balance.

The e.g. in the doc blurb of `xa` above can be used, e.g., to compare perf of
something like `ripgrep` & GNU `grep`, using [ru](ru.md) & [cstats](cstats.md):
```
cd /dev/shm
export LC_ALL=C # Below clone fetches GiB! Adapt to your own extant, if possible
# git reset --hard c2bf05db6c78f53ca5cd4b48f3b9b71f78d215f1 ~reproduces data
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
cd linux                            # Search a non-trivial git repo
git log|head -n1                    # No ripgreprc file in effect below
rg --files | tr \\n \\0 > ../f0     # git ls-files [-o] is faster, if ok to use
mv ~/.config/git ~/.config/git--    # Be more reproducible
(repeat 10; {rm -f ../xa/.fin; j=4 XA=../xa ru -t xa <../f0 -0n800 sh -c 'grep "Linus.*Torvlds" "$@" >"$XA/o/$XA_SLOT" 2>"$XA/e/$XA_SLOT"' D0})|&sort -g|head -n3|cstats
(repeat 10; {rm -f ../xa/.fin; j=4 XA=../xa ru -t xa <../f0 -0n800 sh -c 'grep "Linus.*Torvlds" "$@" >"$XA/o/$XA_SLOT" 2>"$XA/e/$XA_SLOT"' D0})|&sort -g|head -n3|cstats
(repeat 10 ru -t rg Linus.*Torvlds)|&sort -g|head -n3|cstats
(repeat 10 ru -t rg Linus.*Torvlds)|&sort -g|head -n3|cstats
(repeat 10 ru -t rg --files>/dev/null)|&sort -g|head -n3|cstats
(repeat 10 ru -t rg --files>/dev/null)|&sort -g|head -n3|cstats
(repeat 10; {rm -f ../xa/.fin; j=4 XA=../xa ru -t xa <../f0 -0n800 sh -c 'rg "Linus.*Torvlds" "$@" >"$XA/o/$XA_SLOT" 2>"$XA/e/$XA_SLOT"' D0})|&sort -g|head -n3|cstats
(repeat 10; {rm -f ../xa/.fin; j=4 XA=../xa ru -t xa <../f0 -0n800 sh -c 'rg "Linus.*Torvlds" "$@" >"$XA/o/$XA_SLOT" 2>"$XA/e/$XA_SLOT"' D0})|&sort -g|head -n3|cstats
(repeat 10; {ru -t xargs <../f0 -0n800 rg "Linus.*Torvlds" })|&sort -g|head -n3|cstats
(repeat 10; {ru -t xargs <../f0 -0n800 rg "Linus.*Torvlds" })|&sort -g|head -n3|cstats
```
produces { Easy wraps make for nicer, but [dependent](tim.md) `tim 'g0 Torvlds
../f0'` } on an i7-6700k @4.0GHz all-core, noHT w/DIMMs @38 GiB/s BW, 67 ns mlat
w/Linux 6.2.10, rg-13.0 +SIMD +AVX compiled with rust-1.69.0/llvm-15.0.6, gnu
grep-3.11 compiled with gcc-12.3.0/glibc-2.37:
```
commit c2bf05db6c78f53ca5cd4b48f3b9b71f78d215f1
TM 0.310498 +- 0.000023 wall 0.6946  +- 0.0097  usr 0.4976 +- 0.0098 sys 384.000 +- 0.047 % 2005 +-  35 mxRS
TM 0.310612 +- 0.000020 wall 0.687   +- 0.014   usr 0.505  +- 0.014  sys 384.00  +- 0.12  % 1963 +-  35 mxRS
TM 0.29962  +- 0.00028  wall 0.559   +- 0.014   usr 0.610  +- 0.015  sys 389.967 +- 0.027 % 8149 +-  35 mxRS
TM 0.299533 +- 0.000043 wall 0.5772  +- 0.0050  usr 0.5911 +- 0.0052 sys 390.07  +- 0.12  % 8277 +-  35 mxRS
TM 0.08983  +- 0.00014  wall 0.2523  +- 0.0040  usr 0.0829 +- 0.0041 sys 373.20  +- 0.71  % 8277 +-  92 mxRS
TM 0.08923  +- 0.00052  wall 0.24398 +- 0.00089 usr 0.0874 +- 0.0026 sys 371.37  +- 0.84  % 8700 +- 160 mxRS
TM 0.41368  +- 0.00050  wall 0.617   +- 0.011   usr 0.896  +- 0.012  sys 365.77  +- 0.47  % 6997 +-  35 mxRS
TM 0.412    +- 0.010    wall 0.6398  +- 0.0059  usr 0.8751 +- 0.0059 sys 368.1   +- 1.7   % 6955 +-  35 mxRS
TM 0.88624  +- 0.00060  wall 0.5771  +- 0.0064  usr 0.8696 +- 0.0066 sys 163.267 +- 0.054 % 6955 +-  35 mxRS
TM 0.8769   +- 0.0020   wall 0.6147  +- 0.0035  usr 0.8302 +- 0.0033 sys 164.77  +- 0.36  % 6912 +-   0 mxRS
```
The `.fin` `rm` & `j=4..` environ.var sets block not strictly needed work. (The
above was reformatted with `align -dw +.d`.)

First, though methodology here is more careful than average, this is just a one
(machine, OS, source tree, reg-ex, locale) test to demo one wrapper script
possibility for `funnel`.  Second, this is a 0 match test.  Linus' name is not
misspelled this way in his big project.  Third, mean of the best 3/10[^1] are
reproduced run-to-run to within its stderrs[^2] or at least within 5 sigma.[^3]
While other things can (and maybe should) be done[^4], we use the min of the 2
trials next.

Interpreting in more detail, here `rg` is 310498/299533 =~ 1.037X faster.  Since
I found no way to disable `rg` dir scans/.., it is more fair to subtract an `rg
--files` time of 89230 (this "BS adjusts" downward since *some* work is needed)
and use 210390 as a time for `rg` & get an `rg` =~ 1.48x faster.  OTOH, if one
tries to use `xargs` as suggested in a closed `rg` files-from issue), time grows
to the final pair 412000 usec instead of shrinking, now GNU grep \*1.33.  Many
`rg` users surely do many queries over static source trees, varying patterns
until one yields an answer of interest.  So, having no way to skip repeating all
that ~30% total time work may be regrettable in more than benchmarking { though,
yes, only some users might use such a feature }.  Finally, if one uses a naive
`xargs rg` (with no implicit `xargs -P$(nproc)`) things get even slower -- ~3X
worse than base.  That is probably from every 800 files spawning of `nproc`
threads as the time drops to 667ms for `xargs -n1600`.

TLDR: Low-overhead parallel dispatch like `xa/funnel`[^5] can make GNU `grep`
"about as fast" as `rg`, depending.  `rg` has many other nice features builtin,
of course { but could (maybe) profitably grow a `--files-from` option }.

Related Work
------------
Ole Tange might advise using his 15,000 line GNU parallel Perl with its nagware
license and need for a special, threads-enabled Perl5 to work fully, not 1..3
100-line simple programs in a faster prog.lang.  His overhead is near 2 orders
of magnitude bigger than need be (see `bu/execstr.nim`).  This kills performance
on fully file cached parallel grep workloads, being slower than serial grep.

[^1]: Heavy-tailed noise in `tMeasured = t0 + noise` is a tricky thing, but most
would agree `t0` is more interesting than noise dependent upon everything going
on concurrently in a system - which seems a bizarrely popular thing to assess.
mean(best3/10) is only one easy upper bound for the true t0.  `eve` also in this
package is an attempt at a better t0 estimator, but can be glitchy.  Even the
best 3/10 method is polluted by whatever noise makes it into the best 30%. "The
perfect" here is a bit elusive, but "not awful" is not so hard to get.

[^2]: Whatever you use - same environment reproducibility requires *some* way to
compare runs/assess said reproduction.  For errors small enough that [classic
error propagation](https://en.wikipedia.org/wiki/Propagation_of_uncertainty)
holds, `sig(A-B)=(sigA**2+sigB**2)**.5`, for example.  "Numbers of sigma" refer
to `|A-B|/sig(A-B)`, an informal two-sided Student T test for zero-hood.  In a
Nim setting, https://github.com/SciNim/Measuremancer also has more details.
Sigma distances of the 5 wall time pairs are: 114/30=3.8, 9/28=0.32, 6/5=1.2,
2/10=0.2, and 93/21=4.4.

[^3]: A common workaround for hostile, unknown heavy tails in particle physics
is to use 5 rather than 3 sigma as a "strong" threshold.  This actually may be
too optimistic for "computer system timing noise", especially depending on
background activity like web browsers/..where I occasionally see 10+ sigma.

[^4]: E.g. using a global min over all 20 runs, possibly adjusted & with error
estimates.  [tim](tim.md) docs have some more color on difficulties here.

[^5]: On multi-CPU computers, even shell pipelines are "parallel programming"
with OS kernels doing the heavy lifting.  People too readily receive wisdom
about monolithic threaded programs as the best solution.
