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
      sort -g | head -n5 | mnsd         # NOTE: mnsd.nim is in adix/util
}
(tm env -i PATH=$PATH ru -t stripe 1    # stripe 1 w/1 envar
 tm ru -t stripe 1                      # stripe 1 w/~50 envars
 tm ru -t xargs -n1 $t/true             # xargs -n1
 tm ru -t parallel -j1)|                # parallel -j1
    align -dw                           # make table easier to read

# You will probably want a wide terminal window for the below.  Sorry.
# i7-6700k w/HT off taskset 0x3 chrt -r 99 full meltdown-spectre mitigations                                           RATIO
# TM 0.041408 +- 0.000070 wall 0.03259 +- 0.00048 usr 0.01003 +- 0.00050 sys 102.94  +- 0.20  % 2424  +- 20 mxRS       1
# TM 0.04484  +- 0.00010  wall 0.03489 +- 0.00041 usr 0.01105 +- 0.00040 sys 102.460 +- 0.046 % 2481  +- 14 mxRS       1.08288
# TM 0.15775  +- 0.00040  wall 0.11863 +- 0.00098 usr 0.0506  +- 0.0014  sys 107.28  +- 0.27  % 1920  +- 28 mxRS       3.80965
# TM 2.5313   +- 0.0057   wall 1.257   +- 0.017   usr 1.841   +- 0.014   sys 122.380 +- 0.059 % 19290 +- 15 mxRS       61.1307
# (0.04484-0.041408)/49e3*1e9 =~ 70.0 ns/envar
#
# i7-1270P w/taskset 0x7 chrt -r 99 full meltdown-spectre mitigations                                                  RATIO
# TM 0.022668 +- 0.000057 wall 0.01666 +- 0.00030 usr (7.38   +- 0.29)e-03 sys 106.040 +- 0.061 % 2453.60 +- 0.88 mxRS 1
# TM 0.02523  +- 0.00011  wall 0.01907 +- 0.00025 usr (7.57   +- 0.27)e-03 sys 105.64  +- 0.20  % 2485    +- 31   mxRS 1.11302
# TM 0.07492  +- 0.00020  wall 0.05964 +- 0.00050 usr 0.02344 +- 0.00037   sys 110.880 +- 0.052 % 1970    +- 31   mxRS 3.3051
# TM 1.649    +- 0.045    wall 0.764   +- 0.011   usr 1.233   +- 0.085     sys 120.9   +- 1.6   % 19322   +- 12   mxRS 72.7457
# (0.02523-0.022668)/49e3*1e9 =~ 52 ns/envar
#
# External facts: Run-to-run deltas have means within 0.2-4 sigma of each other.
# For example `paste` two together (with manually computed ratio column above
# included) & pipe to awk '{print ($3-$25)/($5**2+$27**2)**.5}', I got 0.670551
# -1.87678 2.26593 -0.263955: quite decent considering system noise has a heavy
# tail with slow convergence to Normal.  (align -1 can provide columns for awk).
# Hence mean,sdev(best 5 of 20 trials) leads to locally reproduced estimates of
# both time & errors.  You should do things like this on your own systems before
# believing timing numbers (for this *AND OTHER* measurements). If you get >4sig
# run-to-run inconsistency, fix CPU freqs via BIOS|OS, do chrt, taskset, etc.
#
# Some stylized observations from the above:
#   - GNU parallel uses 73x more time overhead on a modern CPU
#   - GNU parallel uses 8-10x more space overhead
#   - xargs is not so bad at only 2-4X higher time overhead & 80% the space
#   - stripe overhead is low enough that usually neglected things
#     (like environ.len, argc, etc.) start to matter a lot.
#
# One can also study other scenarios, like failed execs on i7-1270P:                                                          RATIO
# TM 0.01507  +- 0.00016   wall (9.44   +- 0.38)e-03 usr (6.42    +-  0.26)e-03 sys 105.22  +- 0.18  %  2375    +-   24  mxRS 1
# TM 0.017871 +- 0.000026  wall 0.01210 +- 0.00031   usr (6.61    +-  0.30)e-03 sys 104.640 +- 0.088 %  2344    +-   21  mxRS 1.18587
# TM (3.31    +- 0.15)e-04 wall (4.38   +- 0.44)e-04 usr 0.000000 sys 138       +-  23      %  1960  +- 16      mxRS          0
# TM 1.836    +- 0.010     wall 0.794   +- 0.014     usr 1.4731   +-  0.0056    sys 123.48  +- 0.11  %  19328.0 +-   2.3 mxRS 121.831
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
