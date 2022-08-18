Basic invocation:
----------------
```
  tattr [optional-params] [attrs: string...]
```
Emit to `stdout` an escape string activating text colors/styles, honoring
`$NO_COLOR` & also reading `~/.config/cligen` for `$LC_THEME`-based SGR aliases.

Regular/ANSI dim color keywords are in lower case while the bright bank is in
UPPER CASE.  This is the list of both:
 * dim   black, red, green, yellow, blue, purple, cyan, white
 * lite  BLACK, RED, GREEN, YELLOW, BLUE, PURPLE, CYAN, WHITE

Colors are foreground by default.  Pre-pend the string "on_" for Background.
So, e.g. `YELLOW on_red` will be bright yellow text on dark red background.

You can use this to e.g.
```sh
echo "$(tattr WHITE on_blue)some$(tattr WHITE on_blue)other$(tattr plain)"
```
{ If you do things like this often, you probably want your shell `PS1` prompt
variable to contain an `\\e[m` ANSI SGR Escape color deactivation substring
so that it's ok to forget the `tattr plain` at the end. }

More colors when supported by the terminal
------------------------------------------

256-color terminals like xterm-256|st|kitty also support:

 * [fb][0..23] for F)ORE/B)ACKground grey scale (1..2 decimal digits)
 * [fb]RGB where each of R, G, B is in 0..5 (3 decimal digits)

as in:
```sh
echo "$(tattr f153 b4)hello in green-on-gray4"
```

True color terminals (xterm|st|kitty|..) additionally support:
 * [fb]RRGGBB with RR, GG, BB are in hexadecimal (6 hex digits)

as in:
```sh
echo "$(tattr f28FFA0 b303030)hello in green-on-gray"
```

Related Work
------------

The main rationale of this utility is to "fit well" with other cligen tools and
configurations like `lc`, `procs`, `hldiff`, `cligen` help tables, etc.  While
you can do things like:
```
echo $(tput setaf 214)256 $(tput setaf 202)colors
```
they will not honor `.config/cligen/$LC_THEME` switching or any color aliases
stored in said themes.  Meanwhile, if you have a 6 color hue range defined
on-top of the 8-ANSI color scheme you can say `tattr fhue0` or `tattr fhue5`.
