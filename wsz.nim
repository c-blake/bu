import std/termios
proc terminalSize(): IOctl_WinSize =
  for fd in [0, 1, 2]:
    if ioctl(fd.cint, TIOCGWINSZ, result.addr) != -1: return
let t = terminalSize()
echo "cells: "    , t.ws_col   , " x ", t.ws_row   ,
     " pixels: "  , t.ws_xpixel, " x ", t.ws_ypixel,
     " charCell: ", t.ws_xpixel div t.ws_col, " x ", t.ws_ypixel div t.ws_row
