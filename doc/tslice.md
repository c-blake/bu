# Motivation

Sometimes you want to use some column (e.g. the first) of a colorful report
to filter it (say with grep) and then post-process this to slice out a subset of
interest.  If the report is "text tabular", then this utility can be useful.

To be more concrete, the inspiring example to publish this was in the [release
notes](https://github.com/c-blake/procs/blob/master/RELEASE-NOTES.md#version-080)
for procs 0.8.0 in the shell script example.

# Usage
```
  tslice [a]:[b]

does UTF8-SGR aware Py-like slices of terminal columns on stdin
```

More specifically, either `a` or `b` or both can be omitted or negative.
Negative indices are added to the length (in character cells).  If `a`
is missing, `0` is used.  If `b` is missing (there is no upper bound),
the rest of the row is selected.

# Example

On a system where `wc -c < /proc/sys/kernel/pid_max` reports "6",
```sh
pd | tslice 6:
```
will slice out the NON-pid portion of the listing.
