#!/bin/bash
: ${t:=/dev/shm}                # Arrange for minimal test program not on disk.
: ${c:=musl-gcc}
rm -f $t/true.c $t/true || exit 1
echo 'int main(int ac,char**av){return 0;}' > $t/true.c || exit 2
$c -static -Os $t/true.c -o $t/true && rm $t/true.c || exit 3

# Make some work; 1000 makes it easy to mentally convert msec -> usec/job
(for i in {1..1000}; do echo $t/true; done) >$t/w

tm() { # Now measure dispatch overhead
    (for i in {1..20}; do $@ < $t/w; done) |&
      sort -g | head -n5 | mnsd -t,     # NOTE: mnsd.nim is in adix/util
}
(tm env -i PATH=$PATH ru -hut stripe 1  # stripe 1 w/1 envar
 tm ru -hut stripe 1                    # stripe 1 w/~50 envars
 tm ru -hut xargs -n1 $t/true           # xargs -n1
 tm ru -hut parallel -j1)|              # parallel -j1
    align                               # make table easier to read

# i7-6700k w/HT off taskset 0x3 chrt -r 99 full meltdown-spectre mitigations
# wall                 usr                sys                %                mxRS         /first
# 0.041408 +- 0.000070 0.03259 +- 0.00048 0.01003 +- 0.00050 102.94  +- 0.20  2424  +- 20  1
# 0.04484  +- 0.00010  0.03489 +- 0.00041 0.01105 +- 0.00040 102.460 +- 0.046 2481  +- 14  1.08288
# 0.15775  +- 0.00040  0.11863 +- 0.00098 0.0506  +- 0.0014  107.28  +- 0.27  1920  +- 28  3.80965
# 2.5313   +- 0.0057   1.257   +- 0.017   1.841   +- 0.014   122.380 +- 0.059 19290 +- 15  61.1307
# (0.04484-0.041408)/49e3*1e9 =~ 70.0 ns/envar
#
# i7-1270P w/taskset 0x7 chrt -r 99 full meltdown-spectre mitigations
# wall                 usr                sys                  %                mxRS            /first
# 0.022668 +- 0.000057 0.01666 +- 0.00030 (7.38   +- 0.29)e-03 106.040 +- 0.061 2453.60 +- 0.88 1
# 0.02523  +- 0.00011  0.01907 +- 0.00025 (7.57   +- 0.27)e-03 105.64  +- 0.20  2485    +- 31   1.1130
# 0.07492  +- 0.00020  0.05964 +- 0.00050 0.02344 +- 0.00037   110.880 +- 0.052 1970    +- 31   3.3051
# 1.649    +- 0.045    0.764   +- 0.011   1.233   +- 0.085     120.9   +- 1.6   19322   +- 12   72.746
# (0.02523-0.022668)/49e3*1e9 =~ 52 ns/envar
#
# External facts: Run-to-run deltas have means within 0.2-4 sigma of each other.
# Eg. paste run1 run2|grep -v wall|awk '{print ($1-$16)/($3**2+$18**2)**.5}' got
# me 0.670551 -1.87678 2.26593 -0.263955: quite decent considering system noise
# has a heavy tail with slow convergence to Normal. (align -1 provides columns
# for awk).  Hence mean,sdev(best 5 of 20 trials) leads to locally reproduced
# estimates of both time & errors.  You should do things like this on your own
# systems before believing timing numbers (for this *AND OTHER* measurements).
# If you get >5sig run-to-run inconsistency, fix CPU freqs via BIOS|OS, do chrt,
# taskset, kill/suspend web browsers/other background activity, etc.
#
# Some stylized observations from the above:
#   - GNU parallel uses 73x more time overhead on a modern CPU
#   - GNU parallel uses 8-10x more space overhead
#   - xargs is not so bad at only 2-4X higher time overhead & 80% the space
#   - stripe overhead is low enough that usually neglected things
#     (like environ.len, argc, etc.) start to matter a lot.
#
# One can also study other scenarios, like failed execs on i7-1270P:
# wall                  usr                  sys                    %                mxRS           /first
# 0.01507  +- 0.00016   (9.44   +- 0.38)e-03 (6.42    +-  0.26)e-03 105.22  +- 0.18  2375    +- 24  1
# 0.017871 +- 0.000026  0.01210 +- 0.00031   (6.61    +-  0.30)e-03 104.640 +- 0.088 2344    +- 21  1.1859
# (3.31    +- 0.15)e-04 (4.38   +- 0.44)e-04 0.000000               138     +- 23    1960    +- 16  0
# 1.836    +- 0.010     0.794   +- 0.014     1.4731   +-  0.0056    123.48  +- 0.11  19328.0 +- 2.3 121.83
# (xargs here is only failing *1* exec, while the other two fail 1000...)
#
# From the delta of the successful exec case, one can read off costs of making
# new address spaces in the kernel vs. just input parsing, vfork, dispatch, etc.
# In this case it is about 7.60 +- 0.17 usec|7.36 +- 0.11 (depending on if you
# use the env -i line or not..These two estimates are only 1.2 sigma apart and
# could also be weighted-averaged if desired).  (Yes, the failed exec case for
# GNU parallel seems ~4 sigma *bigger*, but GNU parallel is so crazy slow here
# that heavy tailed noise likely hits it harder..).
#
# There are many other scenarios such as timing bu/execstr v. dash v. bash v.
# zsh v. Plan9 rc, >1 amounts of parallelism etc.  One needs to be very careful
# about shell startup "rc" files, etc.  While fast, dash is ~3..5x slower than
# execstr.  It is mostly nice to know "what features cost what" in this area.
#
# But, this mini-report has grown too long already.  I wrote it mostly to show
# easy to re-apply sort -g|head|mnsd ideas for reproducible timings after I saw
# Yet Another Probably Very Irreproducible Timing Table (YAPVITT!), but this is
# far from the story's end.  bu/eve (I am not 100% satisfied w/it) is another
# attempt at reliable timing numbers in the face of system noise, but needs more
# stats bkgd/a paper to explain.  There is also quantile &| density estimation
# &| interpolation & more.  TLDR: start w/at least local reproduction within
# some kind of estimated range of variation.
