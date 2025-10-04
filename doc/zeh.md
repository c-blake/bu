# Motivation
The [Zsh](https://zsh.org/) `setopt EXTENDEDHISTORY` feature is nice.  It adds
to the basic multi-line command format the starting epoch time & command
duration to the history file.

However, if you have various user accounts and different computers you may want
to merge history files.  The history file may just get too big for the shell to
load efficiently.  `zeh` goes at about 1..1.5 GB/s for me and yet still takes
10s of milliseconds for a 600k/26MB file and seems faster than Zsh itself.
Enough 10s and you have noticeable delay.

So, you may want to perform various manipulations to thin your history.  E.g.,
discarding very short commands, less than say 5 bytes.  Trailing newlines are
easy to enter by mistake (either with \ or by pasting newlines) but do not
add any value (at least to my command histories).  And so on.  The format has
been the same for like 30 years and it's easy enough to whip up tools to do
basic things.  This is one.

# Usage
```
  zeh [optional-params] [paths: string...]

Check|Merge, de-duplicate&clean short cmds/trailing \n Zsh EXTENDEDHISTORY
(format ": {t0%d}:{dur%d};CMD-LINES[\]"); Eg.: zeh -tm3 h1 h2 >H.  Zsh saves
start & duration @FINISH TIME => with >1 shells in play, only brief cmds match
the order of timestamps in the file => provide 3 more modes on to of --check:
--endT, --sort, --begT.

  -m=, --min= int  0     Minimum length of a command to keep
  -t, --trim  bool false Trim trailing whitespace
  -c, --check bool false Only check validity of each of paths
  -s, --sort  bool false sort exactly 1 path by startTm,duration
  -b, --begT  bool false add dur to take startTm,dur -> endTm,dur
  -e, --endT  bool false sub dur to take endTm,dur -> startTm,dur
```

# Testing
This is new code a new `adix/ways.kWayMerge` iterator.  So, it's very possible
there are bugs, but this works anyway, and maybe constitutes an example:
```sh
seq2zh() { sed 's/^\(.*\)$/: 1000000\1:0;cmd\1/' ;}
zh2cmd() { sed 's/.*;//' ;}
seq -w 1 3 100|seq2zh>by3
seq -w 2 2 100|seq2zh>by2
seq -w 4 4 100|seq2zh>by4
cat by[234]|zh2cmd|sort>costly
zeh by*|zh2cmd>cheap
cmp cheap costly
```

# Examples
Check a file { or do a parsing benchmark :-) } :

`zeh -c $ZDOTDIR/history`

XXX should really add a bunch of vignettes here.

# Future work
An idea for near-term extensions might be adding a fancier filter language than
just "length >= min", such as the first whitespace delimited command is not in
some set (e.g. `ps`).
