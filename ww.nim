import strutils, cligen, cligen/textUt
when not declared(stdin): import std/syncio

proc ww(maxWidth=0, power=3) =
  ## Multi-paragraph with indent=>pre-formatted optimal line wrapping using
  ## badness metric *sum excess space^power*.
  let maxWidth = if maxWidth != 0: maxWidth else: ttyWidth
  stdout.write wrap(stdin.readAll, maxWidth, power)

include cligen/mergeCfgEnv
dispatch ww, help={"maxWidth": "maximum line width; *0* => tty width",
                   "power"   : "power of excess space for badness"}
