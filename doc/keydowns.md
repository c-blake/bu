Motivation
==========
People often discuss human computer interaction (HCI) "ergonomics".  This has
many dimensions.  One is data entry.  Such conversation is often less objective
than it might be, and one way this is true is measuring only numbers of bytes &|
rendered string lengths.  `keydowns` is an attempt to elevate the conversation
ever so slightly by making it trivial to copy-paste into a terminal to measure
needed keyboard depressions to enter a string.

Doing this in one's head/manually is not so hard, but it is also monotonous, and
error-prone.  So, a little program can help.

Usage
=====
```
  keydowns [optional-params]

Return min key downs needed to enter all lines on stdin, optimizing SHIFTs.

  -s=, --shift= string "~!@#$%^&*()_+|}{:\"?><" in addition to 'A'..'Z'
  -v, --v       bool   false                    err log counts & strings
```

Example
=======
```sh
$ keydowns -v
awk -F, 'BEGIN{a=1;b=2;c=3}{print $a,$b+$c}'
rp -d, -fa,b,c 'echo s[a],b.f+c.i.float'
^D
51 awk -F, 'BEGIN{a=1;b=2;c=3}{print $a,$b+$c}'
41 rp -d, -fa,b,c 'echo s[a],b.f+c.i.float'1234
92
```
The byte-length measurement makes it seems like the Nim is "4 bytes easier"
while it is 10 fewer keydowns.  I mostly wrote this program because I had a
vague sense that Nim generally scores well on this metric compared to other PLs.

More examples are in the [rp docs](rp.md#comparing-examples-to-awk) and limited
only by your imagination.

Caveats
=======
Some people don't enter via keyboards at all, but rather with voice or other
interfaces.  This metric obviously does not apply there.

Real people may or may not optimize their use of the SHIFT key or of Caps-Lock
modes; `keydowns` always does.  So, in some sense it is a lower bound.

Defaults are set up for a US-style keyboard and people and societies can & do
re-map keys.  `--shift` allows some adaptation to that.  An ambitious person can
adjust their keyboard mappings to their input text families to minimize this
metric (at some perhaps significant re-learning costs) making it useless.
I don't do that.  So, I don't find it useless. :-)

Presently `keydowns` does not optimize for keys which are traditionally
unmodified by SHIFT.  The headliner example of this is the space bar where you
can continue holding SHIFT across the space in "{ }".  My own typing rarely
optimizes for this, but since it is possible, the program should grow an option
to measure both ways.
