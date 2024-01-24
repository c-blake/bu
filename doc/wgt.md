Motivation
----------
Sometimes you want to simulate workloads from logs/records or other bases of
synthesis.  There may be many ways to "score" items in terms of desired sampling
frequency.  Here each kind of score is a "source" of weight (e.g. requires a DB
query or required device IO or whatever).  These are listed in a weight meta
file specified by `wgt make -w`.  E.g.:
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
What `wgt` does is calculate the total weight over all scores and then use this
to create a sampling of tokens weighted however.  `wgt make` additionally allows
an updating state machine to effect a self-avoiding random-walk style sampler
with a colorful sample-to-sample weight delta report.

Usage
-----
```
⁞ wgt [-d|--dir=(".")] {SUBCMD} [sub-command options & parameters]

SUBCMDs:

  help    print comprehensive or per-cmd help
  make    Write keyOff,Len,Wgt,Why dictionary implied by source & keys
  print   Emit WEIGHT TOKEN SOURCE(s) for all/some keys to stdout
  assay   Emit aggregate stats assay for given .NC3CS6C files
  sample  Emit n-sample of keys {nl-delim file} weighted by table weights
  diff    Emit color-highlighted diff of old & new weights for keys

wgt {-h|--help} or with no args at all prints this message.
wgt --help-syntax gives general cligen syntax help.
Run "wgt {help SUBCMD|SUBCMD --help}" to see help for just SUBCMD.
Run "wgt help" to get *comprehensive* help
```

A few more "whys"
-----------------
`--dir` is included here since the tokens & weights files are closely related
and may often be co-located in the file tree in some directory.

You may also want to limit/cap the total number of samples any given token can
realize, a kind of back stop against over-skewed scores.

This all rather complex to drive.  So, you also may want to report & explain
total weights on a per token basis (`print`). 

Related Work
------------
More a TODO than related - I should port my reservoir sampling with and without
replacement ways to Nim/cligen and add that flat-weighted sampler.
