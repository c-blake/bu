Motivation
----------

You may want more evenly sized right margins than delivered by a greedy word
wrap algorithm (filling as much as possible before breaking).  cligen/textUt
has this built into it (for help message formatting).  It minimizes a penalty
formula that is the sum of the p-th power of right margin space sizes.  So this
program is a razor thin CLI wrapper that is easy to use from, e.g. just :!ww
from a vim visual select as I did for this very paragraph.  Higher powers will
penalize non-uniformity more.

Usage
-----
```
  ww [optional-params] 
Multi-paragraph with indent=>pre-formatted optimal line wrapping using badness
metric sum excess space^power.
  -h, --help             print this cligen-erated help
  --help-syntax          advanced: prepend,plurals,..
  -m=, --maxWidth= int 0 maximum line width; 0 => tty width
  -p=, --power=    int 3 power of excess space for badness
```

Related Work
------------
Donald Knuth did some impressive work in his TeX layout engine on the much
harder problem that combines kerning adjustment of proportionally spaced fonts
and word wrap.  This program is the kind of high school version of that, but
the concept of "badness" does still show up in tex/latex error messages and is
in the same general dimension.
