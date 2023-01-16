Motivation
----------

The "usability idea" is to leverage user recall of `test` flags by staying as
close as reasonable to that set.  The only real difference is that `ft` {for
f)ile t)ype} uses `h` to mean a h)ard link not an alias for -L.

Yes, there are more verbose ways to do this with `man 1 find` and shell `for`
loops and more terse ways to do it with Zsh extended globbing (`man 1 zshexpn`).

I suspect most people are more comfortable with a shell loop that would also be
portable, but OTOH, it really is a very small program.

Usage
-----
```
  ft [optional-params] [paths: string...]
Batch (in both predicates & targets) test / [ .  Emit subset of paths that pass
expr.  E.g.: $(ft -eL *) =~ Zsh extended glob *(@).  Can also read stdin as in
find -type f|ft -ew.  (Yes, could cobble together with GNU find -files0-from
less tersely & with more quoting concerns.) Maybe counter-intuitively, exit with
status = match count (0=NONE).

  -f=, --file=    string ""   optional input ( "-" | !tty = stdin )
  -d=, --delim=   char   '\n' input file delimiter; \0 -> NUL
  -t=, --term=    char   '\n' output path terminator
  -p=, --pattern= string "$1" emit a $1-using pattern; E.g. "match:$1"
  -e=, --expr=    string "e"  Concatenated extended one-letter test(1) codes
                                  e  (e)xists in any way
                                  b  is (b)lock special
                                  c  is (c)haracter special
                                  d  is a (d)irectory
                                  f  is a regular (f)ile
                                 l|L is a symbolic (l)ink; NOTE: h differs!
                                  p  is a named (p)ipe {aka FIFO}
                                  S  is a (S)ocket; CASE differs from ls/find
                                  s  has a (s)ize greater than zero
                                  h  is a (h)ard link; Link count > 1
                                  N  (N)ew; modify time > access time
                                  k  has its stic(k)y bit set
                                  u  its set-(u)ser-ID bit is set
                                  g  is set-(g)roup-ID
                                  O  is (O)wned by the effective user ID
                                  G  is owned by effective (G)roup ID
                                r|R|A user|World|Group can (r)ead
                                w|W|I user|World|Group can (w)rite
                                x|X|E user|World|Group can e(x)ecute|traverse
                              In all cases a file must exist for 'true'
                              Codes are logically ANDed; '^' prefix => NOT
```
