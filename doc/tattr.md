Basic invocation:
-----------------
```
  tattr [optional-params] [attrs: string...]
```
Emit to `stdout` an escape string activating text colors/styles, honoring
`$NO_COLOR` & also reading `~/.config/cligen` for `$LC_THEME`-based SGR aliases.

Regular/ANSI dim color keywords are in lower case while the bright bank is in
UPPER CASE.  This is the list of both:
 * dim   black red green yellow blue purple cyan white
 * lite  BLACK RED GREEN YELLOW BLUE PURPLE CYAN WHITE

Colors are foreground by default.  Pre-pend the string "on_" for Background.
So, e.g. `YELLOW on_red` will be bright yellow text on dark red background.

You can use this to e.g.
```sh
echo "$(tattr WHITE on_blue)some$(tattr WHITE on_blue)other$(tattr plain)"
```
{ If you do things like this often, you may want your shell `PS1` prompt
variable to contain an `\\e[m` ANSI SGR Escape color deactivation substring
so that it's ok to forget the `tattr off` at the end. }

More colors when supported by the terminal
------------------------------------------

256-color terminals like xterm-256|st|kitty|alacritty also support:

 * {fbu}[0..23] for F)ORE/B)ACKground grey scale (1..2 decimal digits)
 * {fbu}RGB where each of R, G, B is in 0..5 (3 decimal digits)

as in:
```sh
echo "$(tattr f153 b4)hello in green-on-gray4"
```

True color terminals (xterm|st|kitty|..) additionally support:
 * {fbu}RRGGBB with RR, GG, BB are in hexadecimal (6 hex digits)

as in:
```sh
echo "$(tattr f28FFA0 b303030)hello in green-on-gray"
```
For both of the above, a "u" refers to the foreground color of underline or
undercurl (or any underfoo, really).

Even more ways to specify color
-------------------------------
An element of color scale NAME {viridis hue wLen gray pm3d} can be chosen via:

  {fbu}sNAME<0.-1>[,..]

where only `hue` and `wLen` take [,sat,val] optionally.  "wLen" is for
"waveLength" - (yes, I know RGB light is a mixture; terms are just to contrast
with "frequency order" or hot..cold / cold..hot).  This can be useful in making
[1-1 mappings between numerical ranges and
colors](https://cran.r-project.org/web/packages/viridis/vignettes/intro-to-viridis.html).

More styles when supported by the terminal
------------------------------------------

Non-color styles are:
 * bold - most terminals support this, some mapping to HIGH
 * faint - few terminals support this
 * italic - many terminals support this
 * inverse - all terminals I know of support this
 * struck - few terminals support this
 * blink (slow) - most terminals support this..
 * BLINK (fast) - ..or the above, but often not 2 speeds
 * underline - sometimes mapped back/forth to italic
 * underdouble - kitty/alacritty added these extensions
 * underdot - ..The names after "under" refer to the
 * underdash - ..shape/style underneath the rendered
 * undercurl - ..text which can also have its own color.
 * overline - text with a line above, opposed to underline

These can be prefixed with '-' for the turn off esc sequence, including -fg and
-bg for foreground & background colors.  Use `tattr -- string` to pass a
specifier beginning with a '-'.

Rationale/Related Work
----------------------

The main rationale of this utility is to "fit well" with other
[cligen](https://github.com/c-blake/cligen) tools and [related
configurations](https://github.com/c-blake/cligen/wiki/Text-Attributes-supported-in-Config-files)
like [lc](https://github.com/c-blake/lc),
[procs](https://github.com/c-blake/procs),
[hldiff](https://github.com/c-blake/hldiff), `cligen` help output, etc.
While you can do things like:
```
echo $(tput setaf 214)256 $(tput setaf 202)colors
```
they will not honor `.config/cligen/$LC_THEME` switching or any color aliases
stored in said themes.  Meanwhile, if you have a 6 color hue range defined
on-top of the 8-ANSI color scheme you can say `tattr fhue0` or `tattr fhue5`.
Or maybe you prefer the whole English word style for attribute naming which
is usually less abbreviated than terminfo/termcap, culturally.

It is also more|less a 1-line proc and a locus for documenting my very compact
syntax for SGR ANSI terminal attribute specification.  As a simple side-effect
it also lets you use all these terminal attributes easily from shell scripts.
