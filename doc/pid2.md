Basics
------
Usage: (***NOT*** a cligen utility)
```
pid2 [integer(300)]
```
The [] notation here indicates optionality and default is in ().

This program just does `vfork()` as fast as possible to wrap a Linux process
table until the target Process ID integer is reached.

Motivation
----------

PID-wrapping was made famous more as a hacking tool for programs which foolishly
assume the next PID is neither predictable nor re-used (e.g. a shell /tmp/foo.$$
construct).

I am publishing it here mostly as an example of a big effect that OS scheduling
affinity for a particular CPU can make.  It can also sometimes be nice to
"position" within the process table if you often do PID-sorted process table
listings..(e.g. to group all your xterms or shells together).
