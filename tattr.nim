import os, cligen/humanUt, cligen

proc tattr(attrs: seq[string]) =
  ## Emit to stdout an escape string activating text colors/styles, honoring
  ## $NO_COLOR & also reading ~/.config/cligen for $LC_THEME-based aliases.
  ##
  ## Regular color keywords are in lower case; Bright bank in UPPER CASE:
  ##   black, red, green, yellow, blue, purple, cyan, white
  ##   BLACK, RED, GREEN, YELLOW, BLUE, PURPLE, CYAN, WHITE
  ## Colors are foreground by default.  Pre-pend "on_" for Background.
  ##
  ## 256-color or true color terminals like xterm|st|kitty also support:
  ##   [fb][0..23] for F)ORE/B)ACKgrnd grey scale
  ##   [fb]RGB where R, G, B are in 0..5
  ##   [fb]RRGGBB with RR, GG, BB are in hexadecimal (true color)
  ##
  ## Non-color styles (prefix with '-' to turn off):
  ##   bold, faint, italic, underline, inverse, struck,
  ##   blink (slow blink), BLINK (fast blink)
  if attrs.len == 0:
    raise newException(ValueError, "\n  Need >= 1 attrs.  See tattr --help")
  stdout.write textAttrOn(attrs, plain=existsEnv("NO_COLOR"))

dispatch(tattr)
