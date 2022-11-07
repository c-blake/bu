Motivation
----------

Programs sometimes have multi-row/multi-line outputs with decent regularity.
You may want to "table-ify" such outputs for further processing, e.g. to do some
quick arithmetic work across columns with an `awk` or [rp](rp.md) at the end of
a shell pipeline.

This can also be useful in extract-transform-load (ETL) contexts where you want
to re-shape inputs to a table loading pipeline.

Sometimes it seems more natural to create multi-row outputs and then pipe them
to `unfold`.  For example:
```sh
cat /sys/devices/system/cpu/cpu0/cpufreq/base_frequency \
    /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq |
    unfold -n2 | awk '{print $1/$2}' # Float arithmetic here
```

Usage
-----
```
  unfold [optional-params] 
Join blocks of stdin lines into one line sent to stdout.
  -h, --help                  print this cligen-erated help
  --help-syntax               advanced: prepend,plurals,..
  -s=, --sep=    string "\t"  separates the old lines within the new
  -n=, --n=      int    0     Join |n| lines into 1
  -b=, --before= string ""    join blocks beginning with a matching line
  -a=, --after=  string ""    join blocks ending with a matching line
  -i, --ignore   bool   false regex are case-insensitive
  -e, --extended bool   false regexes are nim re 'extended' syntax
```

Related Work
------------
There are ways to do this with `awk`|etc. directly, but require either state
machine-think that distracts in the heat of the analysis moment or else some
devoted `awk`|etc. scripts.  You could think of this program as a replacement
for some such scripts (that probably runs faster than them).
