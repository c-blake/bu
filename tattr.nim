import std/os, cligen/[sysUt, humanUt], cligen
when not declared(stdout): import std/syncio

proc tattr(attrs: seq[string]) =
  ## Emit to stdout an escape string activating text colors/styles, honoring
  ## $NO_COLOR & also reading ~/.config/cligen for $LC_THEME-based aliases.
  ##
  ## Non-color styles; Prefix with '-' to turn off.
  ##   bold, faint, italic, inverse, hid, struck, blink (slow), BLINK (fast),
  ##   under{line double dot dash curl}, over.
  ##
  ## Regular color keywords are in lower case; Bright bank in UPPER CASE:
  ##   black, red, green, yellow, blue, purple, cyan, white
  ##   BLACK, RED, GREEN, YELLOW, BLUE, PURPLE, CYAN, WHITE
  ## Colors are foreground by default.  Pre-pend "on_" for Background.
  ##
  ## 256-color or true color terminals like xterm|st|kitty also support:
  ##   {fbu}[0..23] for F)ORE/B)ACKgrnd U)NDER grey scale
  ##   {fbu}RGB where R, G, B are in 0..5
  ##   {fbu}RRGGBB with RR, GG, BB are in hexadecimal (true color)
  ##
  ## An element of color scale NAME {viridis hue wLen gray pm3d} can be chosen
  ## via:
  ##   {fbu}sNAME<0.-1>[,..]
  ## where only `hue` and `wLen` take [,sat,val] optionally.  "wLen" is for
  ## "waveLength" - (yes, I know RGB light is a mixture; terms are just to imply
  ## *rough* "spectral order" or hot..cold / cold..hot / "heat" map).
  ##
  ## off, none, NONE turn off all special graphics renditions while -fg, -bg
  ## turn off just ForeGround, BackGround embellishment.
  ##
  ## *NOTE* May Need "--" for -bg, -bold, etc.
  if attrs.len == 0: Value !! "\n  Need >= 1 attrs.  See tattr --help"
  stdout.write textAttrOn(attrs, plain=existsEnv("NO_COLOR"))

dispatch tattr
