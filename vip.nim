import std/[syncio, posix, terminal, strutils, algorithm, sets], posix/termios
import cligen/[sysUt, osUt, mslice, textUt, humanUt] # ~Erlandsson pick
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
  Key=enum CtrlO,CtrlI,CtrlT,CtrlL,Enter,AltEnt,CtrlC,CtrlZ,LineUp,LineDn,PgUp,
   PgDn,Home,End,CtrlA,CtrlE,CtrlU,CtrlK,Right,Left,Del,BkSpc,CtlR,Normal,NoBind
  Item = tuple[size: float; ix, ok: uint32; it, lab, mch: Slice[int]] # 64B
  ExtTest = proc(mem: pointer, len: clong): cint {.noconv.}
  ExtPrint = proc(o: pointer,nO: clong; i: pointer,nI: clong): clong {.noconv.}
var                     # 2) GLOBAL VARIABLES; NiceToHighLight: .*# [0-9A]).*$
  tW,tH,pH,uH,want: int # T)ermW)idth,H)eight,P)ick=avail-QryLine,U)seH,toFill
  tio: Termios          # Terminal IO State
  sigWinCh: Sig_atomic  # Flag saying WinCh was delivered
  its: seq[Item]        # Items
  q, D: string          # The running query; User Data Buffer
  iFd = 0.cint          # Stdin; -1 once true EOF seen (writing process died)
  doSort,doIs,doRoot:bool # Sort matches by match size frac, InSensitive|Beg Mch
  trm, dlm: char        # Optional label-value delimiter; '\0' => none
  ats: array[char, (string, string)] # Text Attrs; COULD index by enum instead.
  okx: ExtTest          # An external test function return 1 to for ok/keep
  prn: ExtPrint         # An external fn to format labels
  Buf = 4096  # Stdin Buffer Size; Lets user balance produce-consume aggression
  tmOut = Timeval(tv_sec: 0.Time, tv_usec: 40_000.Suseconds) # UI timeout

proc ok(i: int): bool = # validation caching system: 0 untested, 1 bad, 2 good
  if i notin 0..<its.len: IndexDefect !! "in ok()"
  if its[i].ok == 0:
    its[i].ok = 1+uint32(okx.isNil or okx(D[its[i].it.a].addr,its[i].it.len)==1)
  bool(its[i].ok - 1)

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

proc handle_sigwinch(sig: cint){.noconv.} = sigWinCh = Sig_atomic(sig==SIGWINCH)
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
  Cap(PgUp  ,"kpp"  ),Kay(PgUp  ,"\eu" ),   # v<--- Alternate Dn,Hm,End bindings
  Cap(PgDn  ,"knp"  ),Kay(PgDn  ,"\x16"),Kay(PgDn  ,"\ed" ),
  Cap(Home  ,"khome"),Kay(Home  ,"\eh" ),Cap(End   ,"kend"),Kay(End  , "\ee"),
  Kay(CtrlA ,"\x01" ),Kay(CtrlE ,"\x05"),Kay(CtrlU ,"\x15"),Kay(CtrlK, "\v" ),
  Cap(Right ,"kcuf1"),Kay(Right ,"\x06"),Kay(Right ,"\eOC"),
  Cap(Left  ,"kcub1"),Kay(Left  ,"\x02"),Kay(Left  ,"\eOD"),
  Kay(BkSpc ,"\x7F" ),Kay(BkSpc ,"\b"  ),Cap(Del  ,"kdch1"),Kay(Del ,"\x04"),
  Kay(CtrlT ,"\x14" ),Kay(CtlR  ,"\x12"),Kay(NoBind,""    )] # Ctl[GMQSWXY\]^_]
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

func findIs(s, sub: string; start: Natural = 0; last: int = -1): int =
  let last = if last < 0: s.high else: last # Just a dumb placeholder.
  let nlen = sub.len          # Faster idea: memchr/find both cases IF even diff
  let hlen = last - start + 1 # Then start @min(two indices) & cmp char-by-char.
  if nlen == 0: return start  # But really a case-folding Boyer-Moore-Horspool..
  if nlen > hlen: return -1   #..with a pre-computed shift table is best.  BUT..
  let n0 = sub[0].toLowerAscii # REALLY a bi/tri-gram index is best of all.
  let limit = last - nlen + 1   # last position where sub can start
  for i in start .. limit:
    if s[i].toLowerAscii == n0:
      var j = 1; (while j < nlen and s[i+j].toLowerAscii == sub[j]: inc j)
      if j == nlen: return i
  return -1
template finda(q,a,b): untyped = (if doIs:D.findIs(q,a,b)else:D.find(q,a,b))

proc bySizeInpOrder(a, b: Item): int =  # 6) SORTER - MATCH SIZE, THEN INP IDX
  let c = cmp(a.size, b.size); (if c == 0: cmp(b.ix, a.ix) else: c)
const badSlc = -1 .. -1                 # 7) MATCH INPUT DATA
var clean = false

proc match(k: int, qs: seq[string]): bool =
  let s = its[k].it
  its[k].mch.a = s.a + 1; its[k].mch.b = -1 # Encodes no match
  for i, q in qs:
    if (let j = q.finda(s.a + its[k].mch.b + 1, s.b); j >= 0):
      if doRoot and i==0 and j!=s.a:its[k].mch=badSlc;its[k].size=0;return false
      its[k].mch.a = min(its[k].mch.a, j - s.a)
      its[k].mch.b = j - s.a + q.len - 1
    else: its[k].mch = badSlc; its[k].size = 0; return false
  its[k].size = if doSort: its[k].mch.len.float/s.len.float else: 1
  true

proc ioCheck(): (bool, bool, bool) =    # (winch, tty ready, input ready)
  var rfds: TFdSet; FD_ZERO rfds; FD_SET(tFd, rfds) # rfds.incl tFd 
  let wake = want>0 and iFd>=0          # wake up only if user types
  if wake: FD_SET(iFd, rfds)            # Only include `iFd` if should
  let nfds = (if wake: max(tFd, iFd) else: tFd) + 1
  setSigWinCh true
  let nReady = select(nfds, rfds.addr, nil, nil, if wake: tmOut.addr else: nil)
  setSigWinCh false
  if sigWinCh.bool: return (true, false, false)
  result[1] = nReady > 0 and FD_ISSET(tFd, rfds) != 0
  result[2] = nReady > 0 and want > 0 and iFd >= 0 and FD_ISSET(iFd, rfds) != 0

var O = 0                               # Offset in D of current row
proc getData =                          # Read, Parse rows, Match & maybe Sort
  let qs = (if doIs: q.toLowerAscii else: q).split # Split buf to lines w/carry
  var nMch = 0
  template maybeFrameAndAdd(nR: int) =
    if nR > int(dlm != '\0'):           # Do not admit empty `label&row`
      if dlm != '\0':                   # Maybe split line into (label, thing)
        if (let p = cmemchr(D[O].addr, dlm, nR.csize_t); p != nil):
          let d = p -! D[O].addr        # Offset(delim char within new data)
          its.add (1.0, its.len.uint32, 0u32, O+d+1 ..< O+nR, O ..< O+d, badSlc)
      else:
          its.add (1.0, its.len.uint32, 0u32, O     ..< O+nR, 0 ..< 0  , badSlc)
      if q.len==0 or match(its.len - 1, qs):
        inc nMch; clean = false #[= doSort? TODO]#
  var N = D.len; D.setLen N + Buf       # Nim has fast, constant time allocator
  let n = read(iFd, D[N].addr, Buf)     # So, just grow and read right into D[]
  if n > 0:                             # EOF: flush carry then close
    D.setLen N + n; let m = N + n       # Parse rows
    while (O < m and (let p = cmemchr(D[O].addr, trm, csize_t(m - O)); p!=nil)):
      maybeFrameAndAdd(p -! D[O].addr); O = p -! D[0].addr + 1
  else:                                 # True EOF; Handle any trailing data
    iFd = -1
    if N > O:                           # At most 1 row by construction
      D.setLen N                        # Right-size D[]
      if N>0 and D[^1]!=trm: D.add trm  # Force term if have any data
      maybeFrameAndAdd(D.len - O)
    else: D.setLen N                    # Nothing to do but right-size D[]
  if nMch > 0:
    its.sort bySizeInpOrder, order=Descending; clean = false; want -= nMch

proc filterQuit(nIt=0): int =   # Filter 1st `nIt` using current query `q`
  if q.len == 0 and clean: return its.len
  let qs = (if doIs: q.toLowerAscii else: q).split
  for i in 0 ..< nIt: result += match(i, qs).int # Return number of matches
  its.sort bySizeInpOrder, order=Descending # order couples w/`result` calc.
  clean = false

proc collect(yO, h: int): (int, seq[int]) = # 8) NAVIGATION OVER VALID/OK SYSTEM
  for i in yO ..< its.len:      # Collect up to `h` indices from `yO` to show
    if q.len>0 and its[i].size==0: return   # Have a query & at end of matches
    if result[1].len < h:
      if i.ok: result[1].add i
      result[0] = i + 1
    else: return

proc first(i0, nIt: int): int = # Get index of first valid >= i0 or -2
  for i in i0 ..< nIt: (if i.ok: return i)
  return -2
proc next(i,nIt: int): int = (if i in -1 .. nIt - 2: first(i + 1, nIt) else: -2)

proc last(i0: int): int =       # Get index of last valid <= i0 or -2
  for i in countdown(i0, 0, 1): (if i.ok: return i)
  return -2
proc prev(i,nIt: int): int = (if i in +1 .. nIt: last(i - 1) else: -2)

template goHm = (if nIt > 0: (pick = first(0, nIt); yO = pick; visIx = 0))

proc goDn(yO, pick, visIx: var int; h, nIt: int; wrap=false) =
  if nIt == 0: return
  let nxt = pick.next(nIt)      # Move pick to next ok|wrap;Maybe Shift viewport
  if nxt == -2: (if wrap: goHm); return
  pick = nxt
  if visIx == min(h, nIt) - 1:
    let newYO = yO.next(nIt)    # Shift yO down one ok step
    if newYO != -2: yO = newYO
  else: visIx += 1

proc goUp(yO, pick, visIx: var int; h, nIt: int; wrap=false) =
  if nIt == 0: return
  let prv = pick.prev(nIt)      # Move pick to prev ok|wrap;Maybe Shift viewport
  if prv == -2:
    if wrap:
      pick = last(nIt - 1); visIx = min(h, nIt) - 1; yO = pick
      for r in 1..<h: (let newYO = yO.prev(nIt); if newYO != -2: yO = newYO)
    return
  pick = prv
  if visIx > 0: visIx -= 1
  else: yO = pick

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
  for _ in 1 .. tW - used: putc ' '     # Want a whole terminal row highlit
  if hL: putp ats['c'][1]

var ls=newStringOfCap(640); ls.setLen 1 # Label String buffer; Ensure realized
proc putN(yO, pick: int): int =         # put1 pH times from `its`
  let h = min(uH, pH)
  let (i, ixs) = collect(yO, h)
  want = h - ixs.len
  if want == 0 and i >= its.len: want = 1 # full pg but hit EO its[]: need more
  if dlm == '\0': (for j in ixs: put1 "", D[its[j].it], j == pick, j)
  else:                                 #XXX CLI param 2set label TERMINAL width
    for j in ixs:
      if prn.isNil: ls = D[its[j].lab]
      else:ls.setLen prn(ls.cstring,640,D[its[j].lab.a].addr,its[j].lab.len).int
      put1 ats['l'][0] & ls & ats['l'][1], D[its[j].it], j == pick, j
  if ixs.len > 0: putp tparm1(parm_up_cursor, ixs.len.cint)
  return i

proc putH(h: int) =
  if h >= 7: # Stay <= 46 col for narrow terminal windows
    put1 "", "^O OrdMchOrInp ^T      ToggleInsen  ^L Refresh"
    put1 "", "^R RootedMchs  Alt-ENT PickLabel   ^C/^Z Usual"
    put1 "", "ListNavigate   TAB(Arrow|Pg)(Up|Dn)Home|End"
    put1 "", "      Esc-|Alt-u,d,h,e for PgUp,Dn,Home,End"
    put1 "", "QueryEdit     ArrowLeft/Right Backspace Delete"
    put1 "", "               ^A Beg ^E End ^U LKill ^K RKill"
    put1 "", "OTHER KEYS EXIT THIS HELP; See bu/doc/vip.md."
  else: put1 "", "No Room For Help"

proc isContin(c: char): bool = (c.uint and 0xC0) == 0x80 # UTF8 continuationByte
proc tui(alt=false): int =         # 10) MAIN TERMINAL USER-INTERFACE
  var nIt, nMch, pick, yO, visIx: int   # O = Origin/Offset
  var (doFilt, doPicks, qGrew) = (true, false, false)
  var jC = q.len                        # cursor as byte index into q[]
  var iK: string
  want = min(uH, pH)
  while true:
    let h = min(uH, pH)
    if not qGrew: nIt = its.len         # If q grew, then filterQuit can only..
    qGrew = false                       #..be MORE restrictive => Use last nIt.
    if doFilt:
      nMch = filterQuit(nIt); doPicks = nMch >= 0; want = max(want, h - nMch)
      if doPicks: doFilt = false; pick = first(0,nIt); yO = 0.max pick; visIx=0
    putp cursor_invisible, fatal=false
    putp carriage_return; putp clr_eos
    let den = (if doSort: "%" else: "/") & $its.len & # /x denominator w/status
              (if doIs: "-" else: " ") & (if doRoot: "^" else: " ")
    let hdr = ats['h'][0] & align($nMch, den.len - 3) & den & ats['h'][1]
    put1 hdr, ats['q'][0] & q & ats['q'][1]
    if yO >= 0: discard putN(yO, pick)
    putp carriage_return                          # Position cursor on qry line
    let jCtot = hdr.printedLen + q[0..<jC].printedLen # right_cursor treats 0 as
    if jCtot > 0: putp tparm1(parm_right_cursor, jCtot.cint) #..1=>only mv if>0.
    putp cursor_normal, fatal=false; oFlush()
    let (winch, tReady, dReady) = ioCheck()
    if winch: sigWinCh = 0; getTermSize(); continue
    if tReady:                          # terminal input (priority)
      let nNv = if q.len > 0: nMch else: nIt        # For navigation
      case iK.getKey #Parts List,View,Mch params,Exits,ListNav,Bulk+1@TmQNavEdit
      of CtrlO:  doSort = not doSort; doFilt = true # List parameter
      of CtrlT:  doIs   = not doIs  ; doFilt = true # Toggle case-sensitiveMatch
      of CtlR:   doRoot = not doRoot; doFilt = true # Toggle match-root/anchor
      of CtrlL:  getTermSize()                      # Viewport parameter
      of Enter:  return (if nIt>0: pick else: -1)   # Exits..
      of AltEnt: (if nIt>0: (its.add (1.0, its.len.uint32, 2u32, its[pick].lab,
                                      its[pick].it, badSlc); return its.len - 1)
                  else: return -1)
      of CtrlC:  return -1              # & below exit-like suspend
      of CtrlZ:  tRestore alt; discard kill(getpid(), SIGTSTP); tInit alt
      of LineUp:       goUp yO,pick,visIx, h,nNv,true   # LIST NAVIGATION (
      of LineDn,CtrlI: goDn yO,pick,visIx, h,nNv,true
      of PgUp:   (for _ in 1..h:goUp yO,pick,visIx, h,nNv,false) #Ok to mv visIx
      of PgDn:   (for _ in 1..h:goDn yO,pick,visIx, h,nNv,false) #..to top/bot?
      of Home:   goHm
      of End:    goHm; goUp yO,pick,visIx, h,nNv,true   # LIST NAVIGATION )
      of CtrlA:  jC = 0                 # Qry Bulk NavEdit: ^A=Start,^E=End
      of CtrlE:  jC = q.len             # Ensure jC byte idx ends @EndOf UChar
      of CtrlK:  q.delete jC ..< q.len; doFilt = true         # ^K=Kill RHS
      of CtrlU:  q.delete 0 ..< jC; jC = 0; doFilt = true     # ^U=Kill LHS
      of Right:  (while jC < q.len:
                    inc jC; if jC == q.len or not q[jC].isContin: break)
      of Left:   (while jC > 0 and q[(dec jC; jC)].isContin: discard)
      of Del:    (if jC < q.len:        # 1@Time Edit DEL-(Right|Left), put
                    var n=1; while jC + n < q.len and q[jC + n].isContin: inc n
                    q.delete jC ..< jC + n; doFilt = true)
      of BkSpc:  (if jC > 0:
                    var n = 1; while jC >= n and q[jC - n].isContin: inc n
                    let slice = max(0, jC - n) ..< jC
                    q.delete slice; jC -= slice.len; doFilt = true)
      of Normal: q.insert iK, jC; qGrew = true; jC += iK.len; doFilt = true
      of NoBind: putH(h); oFlush(); discard iK.getKey
    elif dReady:                        # data input (not done if viewport full)
      getData(); doFilt = pick < 0 and its.len > 0 or q.len > 0

proc vip(n=9, alt=false, inSen=false, root=false, sort=false, term='\n',
    delim='\0', label=0, quit="", buf=4096, TmOut=50, keep="", print="",
    colors:seq[string] = @[], color:seq[string] = @[], qs: seq[string]): int =
  ## `vip` parses stdin lines, does TUI incremental-interactive pick, emits 1.
  var i = -1; uH = n - 1; q = qs.join(" "); doSort = sort; Buf = buf
  trm = term; dlm = delim; doIs = inSen; doRoot = root
  tmOut.tv_usec = Suseconds(TmOut*1000)
  colors.textAttrRegisterAliases; color.setAts          # colors => aliases, ats
  if keep.len  > 0: okx = cast[ExtTest](keep.loadSym)   # Maybe Load Plug-In
  if print.len > 0: prn = cast[ExtPrint](print.loadSym) # Maybe Load Plug-In
  try    : tInit alt; i = tui(alt)                      # Run the TUI
  finally: tRestore alt
  if i < 0: echo (if quit.len>0: quit else: q); return 1 # Exit|Emit
  echo D[its[i].it]
  if label != 0: write label.cint, D[its[i].lab]

when isMainModule:import cligen; include cligen/mergeCfgEnv; dispatch vip,help={
  "qs"    : "initial query strings to interactively edit",
  "n"     : "max number of terminal rows to use",
  "alt"   : "use the alternate screen buffer",
  "inSen" : "match query case-insensitively; Ctrl-I",
  "root"  : "root/anchor/^ match to record starts; Ctrl-R",
  "sort"  : "sort by match score,not input order; Ctrl-O",
  "term"  : "input record terminator (vs. newline)",
  "delim" : "Pre-1st-*THIS* = Context Label; Post=AnItem",
  "label" : "emit parsed label to this file descriptor",
  "quit"  : "value written upon quit (e.g. Ctrl-C)",
  "buf"   : "bytes for stdin read buffer",
  "TmOut" : "UI timeout in milliseconds (50ms=~20fps)",
  "keep"  : "Eg `-klibvip.so:cdable` ptr,len->cint==1",
  "print" : "Eg `-plibvip.so:zxhPrint` (ou,mxOu,i,nI)->nO",
  "colors": "colorAliases;Syntax: NAME = ATTR1 ATTR2..",
  "color":""";-separated on/off attrs for UI elements:
  qtext choice match label"""}, short={"color": 'c'}
