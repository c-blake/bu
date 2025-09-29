import std/[syncio, posix, terminal, strutils, algorithm, sets], posix/termios
import cligen/[sysUt, osUt, mfile, mslice, textUt, humanUt] # ~Erlandsson pick
{.passl: "-lncurses".}                  # 0) C-LEVEL CURSES SET UP
when defined linux: {.passl: "-ltinfo".}
proc tigetstr(capCode: cstring): cstring                  {.header:"curses.h".}
proc setupterm(t: cstring, fd: cint, err: ptr cint): cint {.header:"curses.h".}
proc tputs(s: cstring; cnt: cint; put: pointer): cint     {.header:"curses.h".}
proc tparm(s: cstring; a,b,d,e,f,g,h,i,j: clong): cstring {.header:"curses.h".}
proc strlen(s: cstring): clong                            {.header:"string.h".}
discard setlocale(LC_CTYPE, "")         # Tell libc to use LC_ environ variables
var tFd = open("/dev/tty", O_RDWR)      # Open Controlling Terminal
if tFd < 0: OS !! "check permissions on /dev/tty"
discard setupterm(nil, tFd, nil)        # This MUST PRECEDE below impC's
template impC(name) {.dirty.} =         # Define some constants from curses lib
  var `wr name` {.header: "term.h", importc: astToStr(name) .}: cstring
  let name {.inject.} = `wr name`
impC carriage_return; impC parm_up_cursor; impC parm_right_cursor; impC clr_eos
impC enter_ca_mode; impC exit_ca_mode; impC cursor_invisible; impC cursor_normal
impC keypad_xmit; impC keypad_local
const SIGWINCH = 28.cint                # Nim stdlib ~ woefully Windows-centric
var POSIX_VDISABLE {.header: "term.h", importc: "_POSIX_VDISABLE" .}: cchar
proc tcap(cap: string): string =        # termcap/curses convenience wraps
  let s = tigetstr(cap.cstring)
  if cast[int](s) != -1 and not s.isNil:
    result.setLen s.strlen; copyMem result.cstring, s, result.len
proc tparm1(cap: cstring; a: cint): cstring = tparm(cap, a, 0,0,0,0, 0,0,0,0)

type                    # 1) TYPES; Main Logic is here to end of `proc vpick`.
  Key=enum CtrlO,CtrlI,CtrlR,CtrlL,Enter,AltEnt,CtrlC,CtrlZ,LineUp,LineDn,PgUp,
    PgDn, Home,End, CtrlA,CtrlE,CtrlU,CtrlK, Right,Left,Del,BkSpc, Normal,NoBind
  Item = tuple[size: float; ix,ok:uint32; it,lab: MSlice; mch: Slice[int]] # 64B
  ExtTest = proc(mem: pointer, len: clong): cint {.noconv.}
var                     # 2) GLOBAL VARIABLES; NiceToHighLight: .*# [0-9A]).*$
  tW, tH, pH, uH: int   # T)erminal W)idth, H)eight, P)ick=avail-QryLine, U)ser
  tio: Termios          # Terminal IO State
  sigWinCh: Sig_atomic  # Flag saying WinCh was delivered
  its: seq[Item]        # Items
  q, den: string        # The running query, denom
  doSort,doIs,Rev: bool # Sort matches by match size fraction, InSensitive Mch
  dlm: char             # Optional label-value delimiter; '\0' => none
  ats: array[char, (string, string)] # Text Attrs; COULD index by enum instead.
  data: MSlice          # All user-data, either mmap read-only/buffers
  okx: ExtTest          # An external test function return 1 to for ok/keep

proc ok(i: int): bool = # validation caching system: 0 untested, 1 bad, 2 good
  if i < its.len and its[i].ok > 0:
    return bool(its[i].ok - 1)
  okx.isNil or okx(its[i].it.mem, its[i].it.len) == 1

proc setAts(color: seq[string]) =       # defaults, config, cmdLine -> ats
  const def = @["h bold;-bold", "q WHITE on_blue;-bg -fg", "c inverse;-inverse",
                "m YELLOW on_red;-bg -fg", "l italic;-italic"]
  for s in def & color: # h)eader q)uery c)urrent pick m)atch l)abel
    let cols = s.strip.splitWhitespace(1)
    if cols.len < 2: Value !! "bad color: \"" & s & "\""
    let k = if cols[0].len > 0: cols[0].toLowerAscii[0] else: '\0'
    let val = cols[1].split(';')
    if val.len != 2: IO !! s & "not: \"key On ; Off\""
    if k in {'q','c','m','l','h'}: ats[k] = (val[0].textAttr, val[1].textAttr)
    else: IO !! cols[0] & " not in: q* c* m* l* h*"

var oBuf: array[1024,char]; var oUsed=0 # 3) BUFFERED TERMINAL OUTPUT
proc oFlush() =
  if write(tFd, oBuf[0].addr, oUsed)<0 and sigWinCh==0.Sig_atomic: quit "putc",1
  oUsed = 0
proc putc(c: char) {.noconv.} =                 # Call back for curses output..
  if oUsed == oBuf.sizeof: oFlush()
  oBuf[oUsed] = c; inc oUsed
proc putp(capability: cstring; fatal=true) =    #..And our own `putp` wrapper.
  if tputs(capability, 1.cint, cast[pointer](putc)) == cint(-1) and fatal:
    quit astToStr(capability) & ": unknown terminfo capability", 1
proc putp(capability: string; fatal=true) = putp capability.cstring

proc getc(): char =                     # 4) TERMINAL INPUT,SIGNALS,INIT,RESTORE
  if read(tFd, result.addr, 1) < 0 and sigWinCh==0.Sig_atomic: quit "getc", 1

proc handle_sigwinch(sig: cint) {.noconv.} =
  sigWinCh = Sig_atomic(sig == SIGWINCH)
proc setSigWinCh(enable: bool) =        # SIGNALS
  var sa = Sigaction(sa_handler: (if enable: handle_sigwinch else: SIG_IGN))
  discard sigemptyset(sa.sa_mask)
  if sigaction(SIGWINCH, sa, nil) == -1: quit "sigaction: SIGWINCH", 1

proc getTermSize() = ((tW, tH) = terminalSize(); pH = tH - 1)

proc tInit(alt=false) =                 # INIT
  discard tcGetAttr(tFd, tio.addr)
  var na = tio                          # N)ew A)ttributes
  na.c_iflag = na.c_iflag or ICRNL      # map CR to NL
  na.c_lflag = na.c_lflag and not (ISIG or ICANON or ECHO or IEXTEN)
  na.c_cc[VTIME] = chr(0)               # == POSIX_VDISABLE
  na.c_cc[VMIN] = chr(1)
  na.c_cc[13] = POSIX_VDISABLE          # VDISCARD missing in Nim stdlib
  discard tcSetAttr(tFd, TCSANOW, na.addr)
  getTermSize()
  putp keypad_xmit, fatal=false
  if alt: putp enter_ca_mode, fatal=false
  setSigWinCh false

proc tRestore(alt: bool) =              # RESTORE
  discard tcSetAttr(tFd, TCSANOW, tio.addr)
  putp carriage_return; putp clr_eos; putp keypad_local, fatal=false
  if alt: putp exit_ca_mode, fatal=false
  oFlush()

type K = tuple[key: Key; cap,str: string; tio: cint] # 5) KEY PRESS HANDLING
proc Cap(k: Key, s: string): K = result.key = k; result.cap = s; result.tio = -1
proc Kay(k: Key, s: string): K = result.key = k; result.str = s; result.tio = -1
proc Tio(k: Key, i: cint)  : K = result.key = k; result.tio = i
var Ks = [Kay(CtrlO, "\x0F"), Kay(CtrlI, "\t"), Kay(CtrlL, "\f"),
  Kay(Enter ,"\n"   ),Kay(AltEnt,"\e\n"),Tio(CtrlC ,VINTR ),Tio(CtrlZ,VSUSP),
  Cap(LineUp,"kcuu1"),Kay(LineUp,"\x10"),Kay(LineUp,"\eOA"),
  Cap(LineDn,"kcud1"),Kay(LineDn,"\x0E"),Kay(LineDn,"\eOB"),
  Cap(PgUp  ,"kpp"  ),Kay(PgUp  ,"\ev" ),   # v<--- Alternate Dn,Hm,End bindings
  Cap(PgDn  ,"knp"  ),Kay(PgDn  ,"\x16"),Kay(PgDn  ,"\e " ),
  Cap(Home  ,"khome"),Kay(Home  ,"\e<" ),Cap(End   ,"kend"),Kay(End  , "\e>"),
  Kay(CtrlA ,"\x01" ),Kay(CtrlE ,"\x05"),Kay(CtrlU ,"\x15"),Kay(CtrlK, "\v" ),
  Cap(Right ,"kcuf1"),Kay(Right ,"\x06"),Kay(Right ,"\eOC"),
  Cap(Left  ,"kcub1"),Kay(Left  ,"\x02"),Kay(Left  ,"\eOD"),
  Kay(BkSpc ,"\x7F" ),Kay(BkSpc ,"\b"  ),Cap(Del   ,"kdch1"),Kay(Del ,"\x04"),
  Kay(CtrlR ,"\x12" ),Kay(NoBind,""    )]
for k in mitems Ks:     # Populate Cp capability slots
  if k.str.len == 0 and k.cap.len > 0: k.str = tcap(k.cap)

proc getKey(ik: var string): Key =              # partial key
  ik.setLen 0
  setSigWinCh true                              # Allow SIGWINCH on 1st read.
  ik.add getc()
  setSigWinCh false
  if sigWinCh.bool: sigWinCh = 0; return CtrlL  # Should trigger getTermSize()
  while true:           # This is kinda messy logic to match `ik` against..
    var i = -1          #..`Ks[]` while also building `ik` at the same time.
    while i+1 < Ks.len: #..Should probably just `import std/critbits` instead.
      inc i; let k = Ks[i]
      if k.tio >= 0:
        if ik.len == 1 and tio.c_cc[k.tio] == ik[0] and
           tio.c_cc[k.tio] != POSIX_VDISABLE: return k.key
        continue
      if not k.str.startsWith(ik): continue     # Cannot match this `k`
      if ik.len == k.str.len: return k.key      # Matches exactly
      break             # Only startsWith match found, continue reading
    if Ks[i].key == NoBind: break
    ik.add getc()
  if ik.len > 1 and ik[0] == '\e' and (ik[1] == '[' or ik[1] == 'O'):
    var c = ik[^1]      # EscSeq of unsupported key being read. Discard rest
    while c < '@' or c > '~': c = getc()
    return NoBind
  if (ik[0].uint and 0xC0) != 0xC0:             # NOT start of UTF8
    return if ik[0] >= ' ' and ik[0] <= '~': Normal else: NoBind
  while ((ik[0].int shl ik.len) and 0x80) != 0: # Finish 1 whole UTF8 char len==
    ik.add getc()                               #..Num(MSBs in 1st byte).
  return Normal

const badSlc = Slice[int](a: -1, b: -1) # 6) PARSE INPUT DATA
const emptyS = MSlice(mem: nil, len: 0)
var clean = false
var buf: string                         # Must have program lifetime
proc parseIn() =
  if (let mf = mopen(0); mf.mem != nil): data = mf.mslc
  else: buf = stdin.readAll; data = MSlice(mem: buf.cstring, len: buf.len)
  var labIt: seq[MSlice]
  var i = 0
  for line in mSlices(MSlice(mem: data.mem, len: data.len), sep='\n'):
    if line.len > int(dlm != '\0'):     # Do not admit an empty line & label
      if dlm != '\0':
        if line.msplit(labIt, dlm, n=2) == 2:
          its.add (1.0, i.uint32, 0u32, labIt[1], labIt[0], badSlc)
      else:
          its.add (1.0, i.uint32, 0u32, line    , emptyS  , badSlc)
      inc i
  if not Rev: its.reverse
  clean = true

var low: string
proc match(s: MSlice, qs: seq[MSlice]): Slice[int] = # 7) FILTERING, SORTING
  result.a = s.len + 1; result.b = -1
  let s = if doIs and low.len>0: s.rebase(data.mem, low[0].addr) else: s
  for q in qs:
    if (let j = s.find(q, start=result.b + 1); j >= 0):
      result.a = min(result.a, j)
      result.b = j + q.len - 1
    else: return badSlc

proc bySizeInpOrder(a, b: Item): int =
  let c = cmp(a.size, b.size)
  return if c == 0: (if Rev: cmp(b.ix, a.ix) else: cmp(a.ix, b.ix)) else: c

proc filterQuit(nIt=0): int =   # Filter 1st `nIt` using current query `q`
  var pfd = TPollfd(fd: tFd)
  if q.len == 0 and clean: return its.len
  if doIs and low.len != data.len:
    low.setLen data.len
    for i in 0 ..< data.len:
      low[i] = if data[i] in {'A'..'Z'}: chr(data[i].ord + 32) else: data[i]
  let q = if doIs: q.toLowerAscii else: q
  var qs: seq[MSlice]; discard msplit(q, qs)    # Split maybeLower; initSep?
  for i in 0 ..< nIt:
    let s = its[i].it; let m = match(s, qs); its[i].mch = m # Save for highlight
    result += (m.b >= 0).int    # Report number of matches to caller
    its[i].size = if m.b < 0: 0 elif not doSort: 1 else: m.len.float/s.len.float
    if (i + 1) mod 1024 == 0:   # Routinely poll for user input to maybe abort
      pfd.events = POLLIN
      if (let nReady = poll(pfd.addr, 1, 0); nReady != -1):
        if nReady == 1 and (pfd.revents and (POLLIN or POLLHUP)) != 0: return -1
      else: quit "poll", 1
  its.sort bySizeInpOrder, order=Descending # order couples w/`result` calc.
  clean = false

proc collect(yO, h: int): (int, seq[int]) = # 8) NAVIGATION OVER VALID/OK SYSTEM
  for i in yO ..< its.len:      # Collect up to `h` indices from `yO` to show
    if q.len>0 and its[i].size==0: return   # Have a query & at end of matches
    if result[1].len < h and i.ok: result[1].add i
    result[0] = i + 1

proc first(i0, nIt: int): int = # Get index of first valid >= i0
  var i = i0
  while i < nIt and not i.ok: i += 1
  if i < nIt: i else: -1
proc next(i, nIt: int): int = (if i == -1: -1 else: first(i + 1, nIt))

proc last(i0: int): int =       # Get index of last valid <= i0
  var i = i0
  while i >= 0 and not i.ok: i -= 1
  if i >= 0: i else: -1
proc prev(i: int): int = (if i == -1: -1 else: last(i - 1))

proc goDn(yO, pick, visIx: var int; h, nIt: int; wrap=false) =
  if nIt == 0: return
  let nxt = pick.next(nIt)      # Move pick to next ok|wrap;Maybe Shift viewport
  if nxt == -1:
    if wrap: pick = first(0, nIt); yO = pick; visIx = 0
    return
  pick = nxt
  visIx += 1
  if visIx == h:                # Shift yO down one ok step
    let newYO = yO.next(nIt)
    if newYO != -1: yO = newYO; visIx -= 1

proc goUp(yO, pick, visIx: var int; h, nIt: int; wrap=false) =
  if nIt == 0: return
  let prv = pick.prev           # Move pick to prev ok|wrap;Maybe Shift viewport
  if prv == -1:
    if wrap:
      pick = last(nIt - 1); visIx = min(h, nIt) - 1; yO = pick
      for r in 1..<h: (let newYO = yO.prev; if newYO != -1: yO = newYO)
    return
  pick = prv
  if visIx == 0:
    let newYO = yO.prev         # Shift yO up one ok step
    if newYO != -1: yO = newYO
    else: visIx = 0             # Cannot shift yO further up => visIx becomes 0
  else: visIx -= 1

template goHm = (if nIt > 0: (pick = first(0, nIt); yO = pick; visIx = 0))

proc put1(l,s: string; hL=false,i= -1)= # 9) RENDERING
  var used = 0; var mOn = false         # Calc. max l.printedLen @parseIn?
  let m = if i >= 0: its[i].mch else: badSlc    # `m` sez underline extent
  if hL: putp ats['c'][0]
  if dlm != '\0' or l.len > 0:
    for (slc, w) in l.printedChars:
      if used + w > tW div 2: break     # Do not use more than tW/2 for label
      for j in slc: putc l[j]           # Handle hard-tab?
      used += w
  for (slc, w) in s.printedChars:
    if m.b >= 0:
      if slc.b >= m.a and not mOn: putp ats['m'][0]; mOn = true
      if slc.a >  m.b            : putp ats['m'][1]; mOn = false
    if used + w > tW: break             # Do not use more than tW
    for j in slc: putc s[j]             # Handle hard-tab & NUL?
    used += w
  if mOn: putp ats['m'][1]
  for j in 1 .. tW - used: putc ' '     # Want a whole terminal row highlit
  if hL: putp ats['c'][1]

proc putN(yO: int; pick: int): int =    # put1 pH times from `its`
  let h = min(uH, pH)
  let (i, ixs) = collect(yO, h)
  for j in ixs:
    let l = if dlm != '\0': ats['l'][0] & $its[j].lab & ats['l'][1] else: ""
    put1 l, $its[j].it, j == pick, j
  if ixs.len < h and i - yO < its.len:  # Space left & maybe more to put
    putc '\n'    # clr_eos clrs from curr col->end. If last vis.pick chosen, hL
    putp clr_eos #..in last&curr col will be also be cleared=>mvDn 1 pre-clear.
    putp tparm1(parm_up_cursor, cint(ixs.len + 1 + int(i == its.len - 1)))
  elif i > 0:   # parm_up_cursor interprets 0 as 1 => only mv up if put an item
    putp tparm1(parm_up_cursor, min(i, h).cint)
  return min(its.len, i)

proc isContin(c: char): bool = (c.uint and 0xC0) == 0x80 # UTF8 continuationByte
proc tui(alt=false, d=5): int =    # 10) MAIN TERMINAL USER-INTERFACE
  var nIt, nMch, pick, yO, visIx: int   # O = Origin/Offset
  var (doFilt, doPicks, qGrew, doHelp) = (true, false, false, false)
  var jC = q.len                        # cursor as byte index into q[]
  var iK: string
  while true:
    let h = min(uH, pH)
    if not qGrew: nIt = its.len         # If q grew, then filterQuit can only..
    qGrew = false                       #..be MORE restrictive => Use last nIt.
    if doFilt:
      nMch = filterQuit(nIt); doPicks = nMch >= 0
      if doPicks: doFilt = false; pick = first(0, nIt); yO = pick; visIx = 0
    putp cursor_invisible, fatal=false
    putp carriage_return; putp clr_eos
    den[0]  = if doSort: '%' else: '/'
    den[^1] = if doIs  : '-' else: ' '
    let hdr = ats['h'][0] & align($nMch, d) & den & ats['h'][1]
    put1 hdr, ats['q'][0] & q & ats['q'][1]
    if doHelp:
      doHelp = false
      if h >= 5: # Stay <= 40 col for narrow terminal windows
        put1 "", "^O toggleOrder ^R reversInsen ^L Refresh"
        put1 "", "ENTER Pick Alt-ENT PickLabel ^C/^Z usual"
        put1 "", "ListNavigate TAB(Arrow|Pg)(Up|Dn)HomeEnd"
        put1 "", "QueryEdit ArrowL/R/Backspace/Delete ^U^K"
        put1 "", "OTHER KEYS EXIT THIS HELP"
      else: put1 "", "No Room For Help"
      discard iK.getKey
    elif doPicks and yO >= 0: nIt = putN(yO, pick)
    putp carriage_return
    let jCtot = hdr.printedLen + q[0..<jC].printedLen # right_cursor treats 0 as
    if jCtot > 0: putp tparm1(parm_right_cursor, jCtot.cint) #..1=>only mv if>0.
    putp cursor_normal, fatal=false; oFlush()
    case iK.getKey  # Parts List,View,Mch params,Exits,ListNav,Bulk+1@TmQNavEdit
    of CtrlO:  doSort = not doSort; doFilt = true # List parameter
    of CtrlR:  doIs   = not doIs  ; doFilt = true # Toggle case-sensitive match
    of CtrlL:  getTermSize()                      # Viewport parameter
    of Enter:  return (if nIt>0: pick else: -1)   # Exits..
    of AltEnt: (if nIt>0: (its.add (1.0, its.len.uint32, 2u32, its[pick].lab,
                                    its[pick].it, badSlc); return its.len - 1)
                else: return - 1)
    of CtrlC:  return -1                # & below exit-like suspend
    of CtrlZ:  tRestore alt; discard kill(getpid(), SIGTSTP); tInit alt
    of LineUp:       goUp yO,pick,visIx, h,nIt,true         # LIST NAVIGATION (
    of LineDn,CtrlI: goDn yO,pick,visIx, h,nIt,true
    of PgUp:   (for r in 1..h: goUp yO,pick,visIx, h,nIt,false) # Ok to mv visIx
    of PgDn:   (for r in 1..h: goDn yO,pick,visIx, h,nIt,false) #..to top/bot??
    of Home:   goHm
    of End:    goHm; goUp yO,pick,visIx, h,nIt,true
    of CtrlA:  jC = 0                   # Qry Bulk NavEdit: Start,End,Right,Left
    of CtrlE:  jC = q.len               # Ensure jC byte idx ends @End Of UChar
    of CtrlK:  q.delete jC ..< q.len; doFilt = true
    of CtrlU:  q.delete 0 ..< jC; jC = 0; doFilt = true
    of Right:  (while jC < q.len:
                  inc jC; if jC == q.len or not q[jC].isContin: break)
    of Left:   (while jC > 0 and q[(dec jC; jC)].isContin: discard)
    of Del:    (if jC < q.len:          # 1@Time Edit DEL-(Right|Left), put
                  var n = 1; while jC + n < q.len and q[jC + n].isContin: inc n
                  q.delete jC ..< jC + n; doFilt = true)
    of BkSpc:  (if jC > 0:
                  var n = 1; while jC >= n and q[jC - n].isContin: inc n
                  let slice = max(0, jC - n) ..< jC
                  q.delete slice; jC -= slice.len; doFilt = true)
    of Normal: q.insert iK, jC; qGrew = true; jC += iK.len; doFilt = true
    of NoBind: doHelp = true

proc vip(n=9, alt=false, inSen=false, sort=false, delim='\0', label=0, digits=5,
         quit="", keep="", rev=false, colors: seq[string] = @[],
         color:seq[string] = @[], qs: seq[string]):int=
  ## `vip` parses stdin lines, does TUI incremental-interactive pick, emits 1.
  var i = -1;uH = n-1;q = qs.join(" ");doSort=sort;dlm=delim;doIs=inSen;Rev=rev
  colors.textAttrRegisterAliases; color.setAts          # colors => aliases, ats
  parseIn(); den = "/"&alignLeft($its.len,digits)&" "   # Read input data
  if keep.len > 0: okx = cast[ExtTest](keep.loadSym)    # Maybe Load Plug-In
  try    : tInit alt; i = tui(alt, digits)              # Run the TUI
  finally: tRestore alt
  if i < 0: echo (if quit.len>0: quit else: qs.join(" ")); return 1 # Exit|Emit
  echo $its[i].it
  if label != 0: write label.cint, $its[i].lab

when isMainModule:import cligen; include cligen/mergeCfgEnv; dispatch vip,help={
  "qs"    : "initial query strings to interactively edit",
  "n"     : "max number of terminal rows to use",
  "alt"   : "use the alternate screen buffer",
  "inSen" : "match query case-insensitively; Ctrl-I",
  "sort"  : "sort by match score,not input order; Ctrl-O",
  "delim" : "Before *THIS* =Context Label;After=AnItem",
  "label" : "emit parsed label to this file descriptor",
  "digits": "num.digits for nMatch/nItem on query Line",
  "rev"   : "reverse default \"log file\" input order",
  "quit"  : "value written upon quit (e.g. Ctrl-C)",
  "keep"  : "eg. `-kfoo.so:Ok==1` keeps if cstr->cint==1",
  "colors": "colorAliases;Syntax: NAME = ATTR1 ATTR2..",
  "color":""";-separated on/off attrs for UI elements:
  qtext choice match label"""}, short={"color": 'c', "digits": 'D'}
