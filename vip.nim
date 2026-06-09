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
  Key=enum CtlO,CtlI,CtlT,CtlG,CtlL,Enter,AltEnt,CtlC,CtlZ,LineUp,LineDn,PgUp,
   PgDn,Home,End,CtlA,CtlE,CtlU,CtlK,Right,Left,Del,BkSpc,CtlR,Normal,NoBind
  Match = tuple[size: float32; ix: uint32; mch: Slice[uint32]] # 16B
  Mix = distinct int    # `j/y` ms Idx; `i` itA idx; `c/x` = trmCol; `r`=trmRow
  ExtTest = proc(mem: pointer, len: clong): cint {.noconv.}
  ExtPrint = proc(o: pointer,nO: clong; i: pointer,nI: clong): clong {.noconv.}
proc `+`(a, b: Mix): Mix {.borrow.}     # Somewhat verbose borrowing to help..
proc `-`(a, b: Mix): Mix {.borrow.}     #..check 1 of 4..6 coordinate styles..
proc `==`(a, b: Mix): bool {.borrow.}   #..in play in various places: x,y term,
proc `<`(a, b: Mix): bool {.borrow.}    #..unfiltered,filtered items,viewport,
proc `<=`(a, b: Mix): bool {.borrow.}   #..and ok-validated.
proc `[]`(x: seq[Match], j: Mix): Match = x[j.int]
proc `[]=`(x: var seq[Match], j: Mix, m: Match) = x[j.int] = m
const dlm0 = 'a'        # a)bsent delim spec & pretty useless `char` for that
const nD=1; const nT=1  # Delimiter & Terminator always 1 byte for now
var                     # 2) GLOBAL VARIABLES; NiceToHighLight: .*# [0-9A]).*$
  tW,tH,pH,uH,want,Dused:int #T)ermW)idth,H)eight,P)ick=avail-QryLine,U)seH,need
  tio: Termios          # Terminal IO State
  sigWinCh: Sig_atomic  # Flag saying WinCh was delivered
  itA: seq[int]         # 3 Parallel arrays: Item offs into D[]; len() for .len
  okS: seq[uint8]       #   Status of item
  labA: seq[int]        #   Label offs into D[] (label.b = itA[] - nD)
  ms: seq[Match]        # Matches against current query (of what has been read)
  q, D, Di: string      # Running query, user data, maybe .lowerAscii user data
  iFd = 0.cint          # Stdin; -1 once true EOF seen (writing process died)
  doSort,doIs,doRoot:bool # Sort matches by match size frac, InSensitive|Beg Mch
  trm, dlm: char        # Optional label-value delimiter; dlm0 => none
  ats: array[char, (string, string)] # Text Attrs; COULD index by enum instead.
  okx: ExtTest          # An external test function return 1 to for ok/keep
  prn: ExtPrint         # An external fn to format labels
  Buf = 4096  # Stdin Buffer Size; Lets user balance produce-consume aggression
  tmOut = Timeval(tv_sec: 0.Time, tv_usec: 40_000.Suseconds) # UI timeout
when defined bench:
  import std/times; var t0, t1: float
proc itB(i: int): int =
  if i==itA.len-1: Dused-nT elif dlm!=dlm0: labA[i+1]-nD-1 else: itA[i+1]-nT-1
proc labB(i: int): int   = itA[i]-nD-1
proc it(i: int): string  = D[itA[i]..itB(i)]
proc lab(i: int): string = D[labA[i]..labB(i)]

proc ok(i: int): bool = # validation caching system: 0 untested, 1 bad, 2 good
  if i notin 0..<itA.len: IndexDefect !! "in ok()"
  if okS[i] == 0:
    okS[i] = 1 + uint8(okx.isNil or okx(D[itA[i]].addr, i.itB - itA[i] + 1)==1)
  bool(okS[i] - 1)

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
var Ks = [Kay(CtlO, "\x0F"), Kay(CtlI, "\t"), Kay(CtlL, "\f"),
  Kay(Enter ,"\n"   ),Kay(AltEnt,"\e\n"),Tio(CtlC  ,VINTR ),Tio(CtlZ,VSUSP),
  Cap(LineUp,"kcuu1"),Kay(LineUp,"\x10"),Kay(LineUp,"\eOA"),
  Cap(LineDn,"kcud1"),Kay(LineDn,"\x0E"),Kay(LineDn,"\eOB"), Kay(CtlG, "\x07"),
  Cap(PgUp  ,"kpp"  ),Kay(PgUp  ,"\eu" ),   # v<--- Alternate Dn,Hm,End bindings
  Cap(PgDn  ,"knp"  ),Kay(PgDn  ,"\x16"),Kay(PgDn  ,"\ed" ),
  Cap(Home  ,"khome"),Kay(Home  ,"\eh" ),Cap(End   ,"kend"),Kay(End  , "\ee"),
  Kay(CtlA  ,"\x01" ),Kay(CtlE  ,"\x05"),Kay(CtlU  ,"\x15"),Kay(CtlK, "\v" ),
  Cap(Right ,"kcuf1"),Kay(Right ,"\x06"),Kay(Right ,"\eOC"),
  Cap(Left  ,"kcub1"),Kay(Left  ,"\x02"),Kay(Left  ,"\eOD"),
  Kay(BkSpc ,"\x7F" ),Kay(BkSpc ,"\b"  ),Cap(Del  ,"kdch1"),Kay(Del ,"\x04"),
  Kay(CtlT  ,"\x14" ),Kay(CtlR  ,"\x12"),Kay(NoBind,""    )] # Ctl[QSMWXY\]^_]
for k in mitems Ks:     # Populate Cp capability slots
  if k.str.len == 0 and k.cap.len > 0: k.str = tcap(k.cap)

proc getKey(ik: var string): Key =              # partial key
  ik.setLen 0
  setSigWinCh true                              # Allow SIGWINCH on 1st read.
  ik.add getc()
  setSigWinCh false
  if sigWinCh.bool: sigWinCh = 0; return CtlL   # Should trigger getTermSize()
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

var qs, qis: seq[string]      # A tri-gram idx might be better, but this..
var sqs, sqi: seq[SkipTable]  #..is ok up to a few million items.
var everIs = false    # Let insens-finders be fast w/sens not pay double D[] mem
proc qUp =
  qs = q.split; qis = q.toLowerAscii.split
  sqs.setLen 0; for q in qs: sqs.add q.initSkipTable
  sqi.setLen 0; for q in qis: sqi.add q.initSkipTable
proc DiUp = # Could be "more bulk"/have longer loops but this isolates code.
  if (let DiLen0 = Di.len; everIs and DiLen0 < D.len):
    Di.setLen D.len; copyMem Di[DiLen0].addr, D[DiLen0].addr, D.len - DiLen0
    for c in DiLen0 ..< Di.len: Di[c] = Di[c].toLowerAscii
template finda(c, a, b): untyped =
  if doIs: (DiUp(); sqi[c].find(Di, qis[c], a, b))
  else: sqs[c].find(D, qs[c], a, b)

proc bySizeInpOrder(a, b: Match): int = # 6) SORTER - MATCH SIZE, THEN INP IDX
  let c = cmp(b.size, a.size); (if c == 0: cmp(a.ix, b.ix) else: c)
const badIx = uint32.high               # 7) MATCH INPUT DATA
var clean = false

proc match(k: int): Match =
  result.ix = badIx; result.mch = uint32.high .. 0u32 # bad | .a > .b => NoMatch
  if q.len == 0: result.ix = k.uint32; return #TODO .size?
  var s = Slice[int](a: itA[k], b: itB(k)); let sLen = s.len.float32
  for c, q in qs:
    let j = c.finda(s.a, s.b)
    if j < 0 or (doRoot and c==0 and j != s.a): return
    result.mch.a = min(result.mch.a.int, j - itA[k]).uint32
    result.mch.b = uint32(j - itA[k] + q.len - 1)
    s.a = j + q.len
  result.size = if doSort: result.mch.len.float32/sLen else: 1
  result.ix = k.uint32

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
  let msLen0 = ms.len                   # Split buf to lines w/carry & update ms
  template maybeFrameAndAdd(nR: int) =
    if nR > int(dlm != dlm0):           # Do not admit empty `label&row`
      if dlm != dlm0:                   # Maybe split line into (label, thing)
        if (let p = cmemchr(D[O].addr, dlm, nR.csize_t); p != nil):
          okS.add 0u8; itA.add O + (p -! D[O].addr) + nD; labA.add O
      else:
        okS.add 0u8; itA.add O
      Dused = O + nR
      let m = if q.len>0: match(itA.len-1) else:(1,uint32(itA.len-1),1u32..0u32)
      if m.ix != badIx: ms.add m
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
  if ms.len > msLen0 and doSort: ms.sort bySizeInpOrder; clean=false

proc filterQuit(qGrew=false) =  # Filter read-so-far using current query `q->ms`
  if qGrew:                             # Thin already matched list for speed
    var w=0.Mix; for j in 0.Mix ..< ms.len.Mix:
      if (let m = match(ms[j].ix.int); m.ix != badIx):
        ms[w] = m; w = w + 1.Mix
    ms.setLen w.int
  else:                                 # query shrank: filter all `it()`
    ms.setLen 0
    for i in 0 ..< itA.len:
      let m = match(i)
      if m.ix != badIx: ms.add m
  if doSort: ms.sort bySizeInpOrder

proc collect(yO: Mix, h: int): (int, seq[(Mix, int)]) = # 8) OK MATCH NAVIGATION
  for j in yO.int ..< ms.len:   # Collect up to `h` indices from `yO` to show
    if result[1].len < h:
      let ix = ms[j].ix.int
      if ix.ok: result[1].add (j.Mix, ix)
      result[0] = ix + 1
    else: return

proc first(j0: Mix): Mix =      # Get index of first valid >= i0 or -2
  for j in j0.int ..< ms.len: (if ms[j].ix.int.ok: return j.Mix)
  return Mix(-2)
proc next(j:Mix): Mix = (if j.int in -1..ms.len-2: first(j+1.Mix) else: Mix(-2))

proc last(j0: Mix): Mix =       # Get index of last valid <= i0 or -2
  for j in countdown(j0.int, 0, 1): (if ms[j].ix.int.ok: return j.Mix)
  return Mix(-2)
proc prev(j:Mix): Mix = (if j.int in +1..ms.len: last(j-1.Mix) else: Mix(-2))

template goHm = (if ms.len > 0: (pick = first(0.Mix); yO = pick; visIx = 0))

proc goDn(yO, pick: var Mix; visIx: var int; h: int; wrap=false) =
  if ms.len == 0: return
  let nxt = pick.next           # Move pick to next ok|wrap;Maybe Shift viewport
  if nxt == Mix(-2): (if wrap: goHm); return
  pick = nxt
  if visIx == min(h, ms.len) - 1:
    let newYO = yO.next         # Shift yO down one ok step
    if newYO != Mix(-2): yO = newYO
  else: visIx += 1

proc goUp(yO, pick: var Mix; visIx: var int; h: int; wrap=false) =
  if ms.len == 0: return
  let prv = pick.prev           # Move pick to prev ok|wrap;Maybe Shift viewport
  if prv == Mix(-2):
    if wrap:
      pick = last(Mix(ms.len - 1)); visIx = min(h, ms.len) - 1; yO = pick
      for _ in 1..<h: (let newYO = yO.prev; if newYO != Mix(-2): yO = newYO)
      want = 0 # suppress getData post wrap; User is navigating, not following
    return
  pick = prv
  if visIx > 0: visIx -= 1
  else: yO = pick

const esc: array[char, char] = block:
  var a: array[char, char]; a['\a']='a'; a['\b']='b'; a['\t']='t'; a['\n']='n'
  a['\v']='v'; a['\f']='f'; a['\r']='r'; a['\\']='\\'; a # Leave Esc-seqs alone
proc put1(l,s:string; hL=false,j=Mix(-1))= # 9) RENDERING
  var used = 0; var mOn = false         # Calc. max l.printedLen @parseIn?
  if hL: putp ats['c'][0]
  if dlm != dlm0 or l.len > 0:
    for (slc, w) in l.printedChars:     # printedChars presently counts \n as 0
      var w=w; for c in slc: w += int(esc[l[c]] != '\0') + int(l[c].ord < 27)
      if used + w > tW div 2: break     # Do not use more than tW/2 for label
      for c in slc:
        if esc[l[c]] != '\0': putc '\\'; putc esc[l[c]]
        else: putc l[c]
      used += w
  for (slc, w) in s.printedChars:       # printedChars presently counts \n as 0
    if j >= 0.Mix and ms[j].ix != badIx:
      if slc.b >= ms[j].mch.a.int and not mOn: putp ats['m'][0]; mOn = true
      if slc.a >  ms[j].mch.b.int            : putp ats['m'][1]; mOn = false
    var w=w; for c in slc: w += int(esc[s[c]] != '\0') + int(s[c].ord < 27)
    if used + w > tW: break             # Do not use more than tW
    for c in slc:
      if esc[s[c]] != '\0': putc '\\'; putc esc[s[c]]
      else: putc s[c]
    used += w
  if mOn: putp ats['m'][1]
  for _ in 1 .. tW - used: putc ' '     # Want a whole terminal row highlit
  if hL: putp ats['c'][1]

var ls=newStringOfCap(640); ls.setLen 1 # Label String buffer; Ensure realized
proc putN(yO, pick: Mix) =              # put1 pH times from `itA`
  let h = min(uH, pH)
  let (i, ixs) = collect(yO, h)
  want = h - ixs.len
  if want == 0 and i >= itA.len: want = 1 # full pg but hit EO its[]: need more
  if dlm == dlm0: (for (j, i) in ixs: put1 "", it(i), j == pick, j)
  else:                                 #XXX CLI param 2set label TERMINAL width
    for (j, i) in ixs:
      if prn.isNil: ls = lab(i)
      else:ls.setLen prn(ls.cstring,640, D[labA[i]].addr, labB(i)-labA[i]+1).int
      put1 ats['l'][0] & ls & ats['l'][1], it(i), j == pick, j
  if ixs.len > 0: putp tparm1(parm_up_cursor, ixs.len.cint)

proc putH(h: int) =
  if h >= 7: # Stay <= 46 col for narrow terminal windows
    put1 "", "^O OrdMchOrInp ^T      ToggleInsen  ^L Refresh"
    put1 "", "^R RootedMchs  Alt-ENT PickLabel   ^C/^Z Usual"
    put1 "", "ListNavigate   TAB(Arrow|Pg)(Up|Dn)Home|End"
    put1 "", "      Esc-|Alt-u,d,h,e for PgUp,Dn,Home,End"
    put1 "", "QueryEdit     ArrowLeft/Right Backspace Delete"
    put1 "", " ^G ->EOF      ^A Beg ^E End ^U LKill ^K RKill"
    put1 "", "OTHER KEYS EXIT THIS HELP; See bu/doc/vip.md."
  else: put1 "", "No Room For Help"

proc isContin(c: char): bool = (c.uint and 0xC0) == 0x80 # UTF8 continuationByte
proc tui(alt=false): (bool, int) =      # 10) MAIN TERMINAL USER-INTERFACE
  var yO, pick: Mix; var visIx: int     # yO = Origin/Offset
  var (doFilt, qGrew) = (true, false)
  var jC = q.len                        # cursor as byte index into q[]
  var iK: string
  want = min(uH, pH)
  while true:
    let h = min(uH, pH)
    if doFilt:
      filterQuit(qGrew); qGrew = false; want = want.max(h - ms.len)
      if ms.len>0: doFilt=false; pick=0.Mix.first; yO=0.Mix.max(pick); visIx=0
    putp cursor_invisible, fatal=false
    putp carriage_return; putp clr_eos
    let den = (if doSort: "%" else: "/") & $itA.len & # /x denominator w/status
              (if doIs: "-" else: " ") & (if doRoot: "^" else: " ")
    let hdr = ats['h'][0] & align($ms.len, den.len - 3) & den & ats['h'][1]
    put1 hdr, ats['q'][0] & q & ats['q'][1]
    putN(yO, pick)
    putp carriage_return                          # Position cursor on qry line
    let jCtot = hdr.printedLen + q[0..<jC].printedLen # right_cursor treats 0 as
    if jCtot > 0: putp tparm1(parm_right_cursor, jCtot.cint) #..1=>only mv if>0.
    putp cursor_normal, fatal=false; oFlush()
    when defined bench: (if t1==0 and (iFd < 0 or want == 0): t1 = epochTime())
    let (winch, tReady, dReady) = ioCheck()
    if winch: sigWinCh = 0; getTermSize(); continue
    let q0 = q
    if tReady:                          # terminal input (priority)
      case iK.getKey #Parts List,View,Mch params,Exits,ListNav,Bulk+1@TmQNavEdit
      of CtlO:  doSort = not doSort; doFilt = true # List parameter
      of CtlT:  doIs   = not doIs  ; doFilt = true # Toggle case-sensitiveMatch
      of CtlR:  doRoot = not doRoot; doFilt = true # Toggle match-root/anchor
      of CtlG:  (while iFd >= 0: getData())
      of CtlL:  getTermSize()                      # Viewport parameter
      of Enter: return (false, (if ms.len>0: ms[pick].ix.int else: -1)) #3 exits
      of AltEnt:return (true , (if ms.len>0: ms[pick].ix.int else: -1))
      of CtlC:  return (true , -1)
      of CtlZ:  tRestore alt; discard kill(getpid(), SIGTSTP); tInit alt
      of LineUp:      goUp yO,pick,visIx, h,true   # LIST NAVIGATION (
      of LineDn,CtlI: goDn yO,pick,visIx, h,true
      of PgUp:  (for _ in 1..h: goUp yO,pick,visIx, h,false) #Ok to mv visIx to
      of PgDn:  (for _ in 1..h: goDn yO,pick,visIx, h,false) #..top/bot(page)?
      of Home:  goHm
      of End:   goHm; goUp yO,pick,visIx, h,true   # LIST NAVIGATION )
      of CtlA:  jC = 0                  # Qry Bulk NavEdit: ^A=Start,^E=End
      of CtlE:  jC = q.len              # Ensure jC byte idx ends @EndOf UChar
      of CtlK:  q.delete jC ..< q.len; doFilt = true         # ^K=Kill RHS
      of CtlU:  q.delete 0 ..< jC; jC = 0; doFilt = true     # ^U=Kill LHS
      of Right: (while jC < q.len:
                   inc jC; if jC == q.len or not q[jC].isContin: break)
      of Left:  (while jC > 0 and q[(dec jC; jC)].isContin: discard)
      of Del:   (if jC < q.len:         # 1@Time Edit DEL-(Right|Left), put
                   var n=1; while jC + n < q.len and q[jC + n].isContin: inc n
                   q.delete jC ..< jC + n; doFilt = true)
      of BkSpc: (if jC > 0:
                   var n = 1; while jC >= n and q[jC - n].isContin: inc n
                   let slice = max(0, jC - n) ..< jC
                   q.delete slice; jC -= slice.len; doFilt = true)
      of Normal: q.insert iK, jC; qGrew = true; jC += iK.len; doFilt = true
      of NoBind: putH(h); oFlush(); discard iK.getKey
    elif dReady:                        # data input (not done if viewport full)
      getData(); doFilt = pick.int < 0 and itA.len > 0
    (if doIs: everIs = true); if q != q0: qUp()

proc vip(n=9, alt=false, inSen=false, root=false, sort=false, term='\n',
    delim=dlm0, quit="", buf=4096, TmOut=50, keep="", print="",
    colors:seq[string] = @[], color:seq[string] = @[], qs: seq[string]): int =
  ## `vip` parses stdin lines, does TUI incremental-interactive pick, emits 1.
  when defined bench: t0 = epochTime()
  var i: int; var ex = false
  uH = n - 1; q = qs.join(" "); qUp(); doSort = sort; Buf = buf
  trm = term; dlm = delim; doIs = inSen; doRoot = root; if doIs: everIs = true
  tmOut.tv_usec = Suseconds(TmOut*1000)
  colors.textAttrRegisterAliases; color.setAts          # colors => aliases, ats
  if keep.len  > 0: okx = cast[ExtTest](keep.loadSym)   # Maybe Load Plug-In
  if print.len > 0: prn = cast[ExtPrint](print.loadSym) # Maybe Load Plug-In
  try    : tInit alt; (ex, i) = tui(alt)                # Run the TUI
  finally: tRestore alt
  when defined bench: tFd.write $int((t1 - t0)*1e6)&" usec to EOF"&"\n"
  if not ex: echo it(i)                                 # Exit: Normal, ^C, alt
  elif i == -1: echo (if quit.len>0: quit else: q); return 1 # ^C
  elif dlm==dlm0: echo it(i); return 2      # No inner row structure
  else: echo D[labA[i]..itB(i)]; return 2   # Caller can ${out#*$dlm} or etc.

when isMainModule:import cligen; include cligen/mergeCfgEnv; dispatch vip,help={
  "qs"    : "initial query strings to interactively edit",
  "n"     : "max number of terminal rows to use",
  "alt"   : "use the alternate screen buffer",
  "inSen" : "match query case-insensitively; Ctrl-I",
  "root"  : "root/anchor/^ match to record starts; Ctrl-R",
  "sort"  : "sort by match score,not input order; Ctrl-O",
  "term"  : "input record terminator (vs. newline)",
  "delim" : "Pre-1st-*THIS* =Label; Post=AnItem;'a'=>absent",
  "quit"  : "value written upon quit (e.g. Ctrl-C)",
  "buf"   : "bytes for stdin read buffer",
  "TmOut" : "UI timeout in milliseconds (50ms=~20fps)",
  "keep"  : "Eg `-klibvip.so:cdable` ptr,len->cint==1",
  "print" : "Eg `-plibvip.so:zxhPrint` (ou,mxOu,i,nI)->nO",
  "colors": "colorAliases;Syntax: NAME = ATTR1 ATTR2..",
  "color":""";-separated on/off attrs for UI elements:
  qtext choice match label"""}, short={"color": 'c'}
