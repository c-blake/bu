Motivation
----------

OS kernels can down clock CPUs, but are often not aggressive enough to block
thermal shutdown.  This controller can sometimes do better.

This approach is limited, but still useful for me (e.g. on old laptops with
failing fans &| overclocked gamer rigs that only overheat with just the right L3
cache loads, often from g++ compiles).

Operation
---------

At CPU temperature `T > temp.b`, `thermctl` sends SIGSTOP to all runnable PIDs
& at `T <= temp.a`, it sends SIGCONT to all stopped PIDs.

Limitations
-----------

Pausing can fail to block future work (loadAvg-targeting work ctl, permissions,
rarely scheduled dispatchers, ..).  Operation can also undesirably SIGCONT jobs
stopped in shells with job control.

Temperature query & Parameter tuning
------------------------------------
```
thermctl [optional-params]
  -q=, --qry=   string  "auto"     auto:Intel?turbostat -sCPU,CoreTmp:cpuTemp
  -i=, --ival=  float   1.0        $1 param to qry (likely a delay)
  -m=, --match= string  "."        pattern selecting cpuTemp line
  -e=, --excl=  strings thermctl   cmd names to never SIGSTOP
  -l=, --log=   string  ""         path to log control transitions to
  -t=, --temp=  Slice   80.0..90.0 > b => pause; < a => resume
```
Note that `turbostat` is distributed with Linux kernel sources.  So, if you
build your own kernels you can usually get it with
```
make -C /usr/src/linux/tools turbostat_install WERROR=0 HOME=/usr/local
```
For AMD CPUs you will probably need some kind of wrapper program to post-process
the output of `lmsensors` (e.g. `sensors k10temp-pci-00cb k10temp-pci-00c3`) run
in a loop.

Physics-minded folk might worry that turbostat itself adds to CPU load pseudo-
Heisenberg-style which is true, but also a small effect.  I see 0.02% usage by
turbostat with 1 second delays on a laptop with a 12 year old CPU. (The small
effect can, however, become a large battery drain effect if temperature polling
activity prevents a hard sleep mode.)

Anyway, I usually launch `thermctl -l/var/log/therm` at system boot.
