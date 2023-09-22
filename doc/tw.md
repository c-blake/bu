Motivation
----------
Sometimes you have maybe-colorized, maybe-utf8 output which has "tabular shape"
but a trailing final column prone to line wrap which then makes the table hard
to read.

For example, C compiles often have very long command lines due to the lack of
any other standard source of compiler options.  So, some `ps ww` invocation may
create a "table" with a dozen terminal rows.

Having an easy way to "clip" or "crop" lines to fit in your terminal can thus be
nice.

Usage (***NOT*** a `cligen` utility)
-----

With no argument, this roughly reproduces what many VTXXX compatible terminals
can do with `printf '\033[?7l'; command; printf '\033[?7h'`:
```sh
$ input-generator|tw
```

Unlike the VTXXX approach, though, with `tw` you can optionally pass a first
argument which is an integer number of rows to limit wrapping to.  For the
motivating compiler example, this can be useful:[^1]
```sh
$ pd -w|tw 2
```

Finally, with a second argument you can override the terminal width detected
by $COLUMNS and ioctls, as in

```sh
$ pd -w|tw 2 40
```
One application of this last mode might be useful to "re-format" a table given
easily split leading & trailing text per row for re-assembly fitting in bounds.

Related Work
------------
While I did look, I did not find any one really doing this anywhere, but it is
hard to make such searches truly exhaustive.  The core of this is just a 30-line
state machine.  The idea is pretty obvious though - basically the "width-wise"
version of `head` or `tail`.  In fact, in combination they let you crop to your
viewable terminal via e.g. `tail -n $LINES|tw`.[^2]

If you know the input has neither ANSI SGR Color escape sequences nor multi-byte
utf8 characters then you can, of course, just `cut -c "1-${COLUMNS:-80}"`.

If you are willing to depend upon regex and terminal libraries as well as do
terminal manipulation (like alternate screen buffers etc.) and you never want
bounded but multiple rows then you can do `less -RES --redraw-on-quit
--rscroll=-`.  That's a lot of IFs, though.[^3]  `tw` is also several times
faster due to its more limited scope.

Future Work
-----------
The current impl does handle Unicode combining characters (including as the
final non-clipped character) but not double wide or grapheme extension type
renders.

[^1]: `pd` here is `procs display` as per https://github.com/c-blake/procs

[^2]: For me this is just `|t|tw` which may become `|ttw` or `|crop` someday.

[^3]: [noc](noc.md) lets you enforce no escape sequence part of the IFs.
