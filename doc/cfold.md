Motivation
----------

Rather than just word-wrapping at width boundaries/word boundaries/etc., it can
sometimes be useful to wrap when a pattern is seen in the input.

Usage
-----
```
  cfold [optional-params] [pattern: string...]

cfold is to fold as csplit(1) is to split(1).  pattern is an rx at which to
segment input lines in file.

  -s, --suppress bool   false exclude matched strings
  -i, --ignore   bool   false add ignore case to re flags
  -e, --extended bool   false nim re 'extended' syntax
  -f=, --file=   string "-"   input file ("-" == stdin)
```

Related Work
------------
This can also be done with GNU sed, but ergonomics of getting \n into
expressions are poor.
