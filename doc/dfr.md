Basics
------

This tool mostly works like `df` as in `df <NOTHING>` gives a brief table while
`df <PATH>` will scope to the filesystem hosting that <PATH>.  It's basically
just a dumb `statfs(1)` formatting program you might enjoy.  A bit more detail:
```
  dfr [optional-params] [paths: string...]

Print disk free stats for paths in user-specified units (GiB by default).

  -d=, --devs=  strings cgroup_root  devices to EXCLUDE
  -f=, --fs=    strings devtmpfs     FS types to EXCLUDE
  -u=, --unit=  float   1073741824.0 unit of measure
  -s, --pseudo  bool    false        list pseudo FSes
  -a=, --avail= float   0.0          exit N if this % is unavailable on N args
  -D, --Dups    bool    false        skip dup-suppressing stat
  --colors=     strings {}           color aliases; Syntax: name = ATTR1 ATTR2..
  -c=, --color= strings {}           text attrs for syntax elts; Like lc/etc.
  -p, --plain   bool    false        do not colorize
```

More Motivation
---------------

The default report is a bit nicer than usual `df` fare.  It looks like:
```
Filesystem        Total     Used    Avail  Use% IUse% MntOn
/dev/root        930.32   445.35   484.97 47.87  0.58 /
tmpfs            125.00     0.00   125.00  0.00  0.00 /dev/shm
/dev/nvme1n1p1   372.43   116.90   255.53 31.39  0.00 /3
```
GNU `df` has a --block-size parameter, but its 1 KiB default is antiquated.
There is no `DF_BLOCK_SIZE` or config file.  So, you are stuck with shell
aliases and it also rounds down to the nearest block integer.  While I'm sure
Big Tech guys have petabyte+ scales, basically GiB to units of 0.01 GiB or
0.01 TiB are mostly what you want these days on "home file systems".  Defaults
here get you to 99999.99 GiB = 100 TiB in 8 terminal columns.

Even with `dfr -u$((1<<40))` for TiB units, the extra 2 decimals reach down to
10GiB precision while "centering the numbers" on the TiB scale - also nicer.
Reasonable people can differ, but, at least for this kind of report, my view is
that one fixed unit scale is more "human readable" than what GNU `df` calls
`--human-readable`.  Often one does `dfr` just to see "Where is there space?"
and so there is an implicit "human mind comparison" in play which is aided by
a consistent scale rather than varying K/M/G/T units.  This even relates to
utility of the "percentage" columns.

You can also see that besides direct data space usage/availability, terminal
space reclaimed by more centered units can be re-purposed to add i-node usage
in a single table (though, yes, some FSes can dynamically grow space for
such)..No need for `df -i`.

Configuration
-------------

I also wanted to colorize rows by how critically full file systems are.  My
personal `~/.config/dfr` looks like:
```
# Percentage STYLES (6 char fmts w/heatmap color scheme).
color = "header inverse"
color = "pct0   fhue0"
color = "pct5   fhue1"
color = "pct25  fhue2"
color = "pct50  fhue3"
color = "pct75  fhue4"
color = "pct85  bold"
color = "pct95  bold fhue5"
color = "pct100 FHUE+"  # Weird >100% values
```
This uses a common set of cligen definitions I use, elaborated upon at
https://github.com/c-blake/cligen/wiki/Color-themes-schemes

Future Work:
------------

These fullness levels themselves should probably be user config'd, but best of
all would be an option for a true-color HSV scale (with Hue tracking PercentFull
and S)aturation and V)alue being `LC_THEME`-driven.
