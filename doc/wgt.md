Motivation
----------
Sometimes you want to simulate workloads from logs/records or other bases of
synthesis.  There may be many ways to "score" items in terms of desired sampling
frequency.  Here each kind of score is a "source" of weight (e.g. requires a DB
query or required device IO or whatever).  These are listed in a weight meta
file specified by `-w`.  E.g.:
```
# SOURCE  WEIGHT  LABEL
# Some base weight for all known tokens
BASE      100     ""
# tokens that need a real DB query
NeedDB     25     DB
# tokens that needed IO
NeededIO   25     IO
```
So, the idea is we want to "skew" sampling toward (or away from) items/tokens of
costs that vary.  (There can even be uses besides "cost" such as desirability.)
What `wsample` does is calculate the total weight over all scores and then use
this to create a sampling of tokens weighted however.

Usage
-----
```
  wsample [NEED,optional-params]

Print n-sample of tokens {nl-delim file tokens} weighted by path weights which
has fmt: SRC W LABEL\n where each SRC file is a set of nl-delimited tokens.
BASE in weights = tokens (gets no label).

  -w=, --weights= string NEED  path to weight meta file
  -t=, --tokens=  string NEED  path to tokens file
  -n=, --n=       int    4000  sample size
  -m=, --m=       int    3     max duplicates for any given token
  -d=, --dir=     string "."   path to directory to run in
  -e, --explain   bool   false print WEIGHT TOKEN SOURCE(s) & exit
  -s, --stdize    bool   false divide explain weight by mean weight
```

A few more "whys"
-----------------
`--dir` is included here since the tokens & weights files are closely related
and may often be co-located in the file tree in some directory.

You may also want to limit/cap the total number of samples any given token can
realize, a kind of back stop against over-skewed scores.

This all rather complex to drive.  So, you also may want to report & explain
total weights on a per token basis.  That is what the --explain flag tells
`wsample` to do, and `--stdize` reports in terms of overall mean weight.

(There may well be other interesting refinements - such as standardizing by
median not mean weight, etc., etc.  As with everything, this is but a start.)

Related Work
------------
More a TODO than related - I should port my reservoir sampling with and without
replacement ways to Nim/cligen and add that flat-weighted sampler.
