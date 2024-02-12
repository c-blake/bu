## Small system to manage weighted sampling w/oft updated, score-driven weights
## w/1 native-endian binary file KWw.NC3CS6C (plus kData, weight sources&refs).
import std/[os,strutils,math,random,strformat,heapqueue,algorithm,sugar,hashes],
  std/tables, cligen,cligen/[mfile,mslice,osUt,strUt,textUt], adix/[oats,mvstat]
when not declared(addFloat): import std/[syncio, formatfloat]
type
  Key = distinct uint32         # Offset & length
  Ww {.packed.} = object        # Weight & Why Size=8B
    w   {.bitsize: 16.}: uint16 # weight: up to 65535
    why {.bitsize: 48.}: uint64 # explanation mask
  KWw {.packed.} = tuple[kr: Key, ww: Ww] # Key Ref & Value
  WTab* = object                #TODO Add helpers to oats|mfile.nim ..
    keys, wgts: MFile           #  .. to ease this & similar instances.
proc cap(t: WTab): int = t.wgts.len div KWw.sizeof
proc eq(t: WTab, a: Key, b: Key|MSlice): bool {.used.} =
  when b is Key: a.int == b.int # Compare internal as ints for faster resize
  else: t.keyQ(a) == b          # Compare MSlice bytes with memcmp
proc keyQ(t: WTab, k: Key): MSlice =
  MSlice(mem: t.keys.mem +! (k.uint32 shr 8), len: int(k.uint32 and 255))
proc keyR(t: WTab, q: MSlice): Key =   # `-!` needs q in `.keys`
  if not q.within(t.keys.mslc): erru "q: ", $q, " not in keys"
  Key((uint32(q.mem -! t.keys.mem) shl 8) or (q.len.uint32 and 255))
proc key(t: var WTab, i: int, k: Key) = cast[pua KWw](t.wgts.mem)[i].kr = k
proc key(t: WTab    , i: int): Key    = cast[pua KWw](t.wgts.mem)[i].kr
proc val(t: var WTab, i: int, v: Ww)  = cast[pua KWw](t.wgts.mem)[i].ww = v
proc val(t: WTab    , i: int): Ww     = cast[pua KWw](t.wgts.mem)[i].ww
proc used(t: WTab   , i: int): bool   = t.val(i).w != 0
var nUsed: int # Avoid file complexity w/global; Not MT-SAFE; Can `make` only 1
oatCounted t, WTab, nUsed #..table @time, but doesn't interleave work anyway.
#when WTab is VOat[Key,MSlice,Ww]: {.warning: "WTab is VOat"} # Nice BUT BREAKS

let dk = "dark" in getEnv("LC_THEME", "darkBG") # Formatting helper defs
let UP = if dk: "\e[97m" else: "\e[1;32m"       # Could do conf obj like `lc`..
let DN = if dk: "\e[91m" else: "\e[1;31m"       #..or `procs`, but only UP,DN.
let PL = "\e[m"                                 # Plain, Unembellished text
var dir = "."

proc wopen*(table: string; keys="", mode=fmRead, avgKL=16.6): WTab =
  if keys.len > 0: result.keys = mopen keys     #^^^^Replace w/estimation slice
  result.wgts = if mode == fmRead: mopen table else: mopen(table, PROT_READ or
    PROT_WRITE, b = oatSlots(int(result.keys.len.float/avgKL + 0.5))*KWw.sizeof)

proc close*(wt: WTab) = wt.keys.close; wt.wgts.close  # works ok if .mem == nil

iterator onBits(x: uint64): int =
  for i in 0..63: (if (x and (1u64 shl i)) != 0: yield i)

proc parseSource*(weights=""): (seq[MSlice], seq[uint16], seq[MSlice]) =
  if (let mf = mopen(weights); not mf.mem.isNil): # Leave open/Keep MSlice live
    for line in mf.mSlices:
      var line = line
      if line.len > 0: line.clipAtFirst '#'
      if line.len == 0: continue
      var cols = line.msplit(0)
      if cols.len != 3: continue
      if cols[0] == "BASE": continue
      result[0].add cols[0]             # Format is: PATH WEIGHT LABEL
      result[1].add cols[1].parseInt.uint16
      result[2].add cols[2]
      if result[0].len == 49: raise newException(IOError, "too many sources")

proc globalStats*(wt: WTab): (MovingStat[float, uint16], Hash) =## stats&why.sig
  result[0].init 0.5, 65535.5, 1024, {OrderStats}
  for ww in wt.values: result[0].push ww.w.float; result[1]=result[1] !& ww.why.int
  result[1] = !$result[1]

proc fmt[F: SomeFloat, C: SomeInteger](s: MovingStat[F,C]): seq[string] =
  result.add &"W: {s.sum.int} "
  result.add "av: " & fmtUncertainMerged(s.mean.float, s.stderror.float)
  result.add "mn: " & $s.min.int
  for q in [0.10, 0.50, 0.90]:
    result.add "q" & ($q)[1..^1] & ": " & formatFloat(s.quantile q,ffDefault,4)
  result.add "mx: " & $s.max.int

type HQR = tuple[wratio: float; key: MSlice; chg, bg: string] # HeapQueueRecord

proc wdiff(labs: seq[MSlice]; key: MSlice; ol,nw: Ww; kMx,cMx: var int): HQR =
  result.wratio = max(nw.w.float / ol.w.float, ol.w.float / nw.w.float)
  result.key = key              # Set ratio & key & build pretty printed diff
  result.chg.add if   nw.w < ol.w: &" {DN}{ol.w:2}->{nw.w:2}{PL}"
                 elif nw.w > ol.w: &" {UP}{ol.w:2}->{nw.w:2}{PL}"
                 else:             &" ={ol.w}"
  for b in onBits(ol.why and not nw.why): result.chg.add &" {DN}-{labs[b]}{PL}"
  for b in onBits(nw.why and not ol.why): result.chg.add &" {UP}+{labs[b]}{PL}"
  for b in onBits(ol.why and nw.why)    : result.bg.add  &" {labs[b]}"
  kMx = max(kMx, key.len)       # Accumulate maxes for caller
  cMx = max(cMx, result.chg.printedLen)

proc cmp(sOld, sNew: WTab; labs: seq[MSlice], only="") =
  let (stO, sigO) = sOld.globalStats; let (stN, sigN) = sNew.globalStats
  if sigO == sigN: return
  func spc(n: int): string = repeat(" ", n)
  var kMx, cMx: int
  var hq = HeapQueue[HQR]()
  if only.len > 0:                      # 2 loop structures more thrifty here
    for key in only.toMSlice.mSlices(sep='\n'):
      let ol = sOld.getOrDefault(key)   # w=why=0 ok for missing
      let nw = sNew.getOrDefault(key)   # w=why=0 ok for missing
      if ol != nw: hq.push labs.wdiff(key, ol, nw, kMx, cMx)
  else:
    for key, nw in sNew:                # skip 1 hash lookup
      let kq = sNew.keyQ(key)
      let ol = sOld.getOrDefault(kq)    # w=why=0 appropriate for missing old
      if ol != nw: hq.push labs.wdiff(kq, ol, nw, kMx, cMx)
  while hq.len > 0:
    let (_, key, chg, bg) = hq.pop
    outu key, spc(kMx - key.len), chg, spc(cMx - chg.printedLen), bg, '\n'
  let stOf = stO.fmt; let stNf = stN.fmt
  template f(x, e, atr): untyped =      # inverse4max(old,new); unchanged=plain
    if e < x: atr & e & PL elif e > x: "\e[7m" & atr & e & PL else: e
  outu &"{DN}0:{PL}"; (for j,e in stOf: outu " ", f(stNf[j], e, DN)); outu '\n'
  outu &"{UP}1:{PL}"; (for j,e in stNf: outu " ", f(stOf[j], e, UP)); outu '\n'

proc make*(table="wt.NC3CS6C", keys="keys", weights="weights",
           refTab="", refKey="", only="", avgKL=16.6) =
  ## Write keyOff,Len,Wgt,Why dictionary implied by `source` & `keys`
  ##
  ## `weights` has the format: SRC W LABEL\\n where each SRC file is a set of
  ## nl-delimited keys.  BASE in `weights` = `keys` (i.e. gets no label).
  if dir != ".": setCurrentDir dir
  if refTab.len > 0: (try: moveFile(table, refTab) except: discard)
  let (paths, pathWt, labs) = parseSource weights
  var wt = wopen(table, keys, fmWrite, avgKL)
  for q in wt.keys.mSlices:
    wt.upSert(q, i): erru "wgt: ",q," appears>once in ",keys,"\n"
    do: wt.key i, wt.keyR(q); wt.val i, Ww(w: 1, why: 0)
  for j, path in paths:
    if (let mf = mopen $path; not mf.mem.isNil):
      let bit = 1u64 shl j
      for q in mf.mSlices:
        if q.len == 0: continue
        wt.upSert(q, i):
          let owhy = wt.val(i).why      # Only turn on bit if already off
          if (owhy and bit) != 0: erru "wgt: multiple ",q," in ",path,"\n"
          else: wt.val i, Ww(w: wt.val(i).w, why: owhy or bit)
          wt.val i, Ww(w: wt.val(i).w + pathWt[j], why: wt.val(i).why)
        do: erru "wgt: ",q," not in ",keys,"\n"
      mf.close #TODO: append checksums @EOF & add a `check` subcmd
  if refTab.len > 0:
    let w0 = wopen(refTab, if refKey.len > 0: refKey else: keys)
    if w0.wgts.mem != nil: cmp w0, wt, labs, only; w0.close
  wt.close

proc diff*(oldNew: seq[string], keys="keys", weights="weights", only="") =
  ## Emit color-highlighted diff of old & new weights for keys
  cmp wopen(oldNew[0],keys),wopen(oldNew[1],keys), parseSource(weights)[2],only

proc rend(wt: WTab, fmt: string, cs: seq[MacroCall], labs: seq[MSlice],
          labTab: Table[string, (int, string, string)], k: Key|string, ww: Ww) =
  for (id, arg, call) in cs:
    if id.idIsLiteral: outu fmt[arg]
    else:
      let id = fmt[id].toString # type MaCallX=(MacroCall,string) &tmplParsedX?
      case id
      of "w"  : outu ww.w
      of "k"  : (when k is Key: outu wt.keyQ(k) else: outu k)
      of "why": (var wr=false; for i in ww.why.onBits:
                                 (if wr: outu " " else: wr=true); outu labs[i])
      else:
        try:
          let (bit, y, n) = labTab[id]
          outu if ((1'u shl bit) and ww.why) != 0: y else: n
        except KeyError: outu fmt[call]
  outu '\n'

proc toTab(fmt: string, cs: seq[MacroCall], labs: seq[MSlice]):
    Table[string, (int, string, string)] =
  for (id, arg, call) in cs:
    if not id.idIsLiteral and (let id = fmt[id].toString; ',' in id):
      let cols = id.split(',')
      if cols.len!=3: raise newException(IOError, "bad syntax: \"" & id & "\"")
      let bit = labs.find(cols[0].toMSlice)
      if bit<0: raise newException(IOError, "unknown label \"" & cols[0] & "\"")
      result[id] = (bit, cols[1], cols[2])

proc print*(table="wt.NC3CS6C", keys="keys", weights="weights",fmt="$w $k $why",
            ks: seq[string]) =
  ## Print weights for all/some keys based on `fmt`
  if dir != ".": setCurrentDir dir
  let wt = wopen(table, keys); let (_, _, labs) = parseSource(weights)
  let cs = fmt.tmplParsed; let labTab = fmt.toTab(cs, labs)
  if ks.len == 0: (for k, ww in wt: wt.rend(fmt,cs, labs,labTab, k,ww))
  else:                 #   No `ks` => all in hash-order else ..
    for k in ks:        #.. `ks` => requested order w/lookups.
      let ww = wt.getOrDefault(k.toMSlice); wt.rend(fmt,cs, labs,labTab, k,ww)

proc assay*(tables: seq[string]) =
  ## Emit aggregate stats assay for given .NC3CS6C files
  for table in tables:
    let wt = wopen table
    if wt.wgts.mem.isNil: continue
    let (st, _) = wt.globalStats
    let sf = st.fmt; let nTot = st.n.float; let wTot = st.sum
    outu &"SCORE:\n"; for e in sf: outu "  ", e, "\n"
    var wd = collect(for ww in wt.values: ww.w.int); wd.sort; wd.cumsum
    outu "FrWt\tFrEntry\tNinBin\tPinBin\n"
    var n0 = 0; var p0 = 0.0
    for q in 1..9:
      let n = wd.lowerBound(int(q.float*0.1*wTot)); let p = n.float / nTot
      outu &"0.{q}0\t{n.float / nTot:.05f}\t{n-n0}\t{p-p0:.05f}\n"; n0=n; p0=p
    outu &"1.00\t{1.0:.05f}\t{nTot.int - n0}\t{1.0-p0:.05f}\n"

iterator cappedSample*[T](x: openArray[T], cdf: openArray[float], n=1, m=3): T =
  ## Weighted sample of size `n` capping to `m` copies of any one element.  Use
  ## to get heavily weighted elements early in samples, but still limit copies.
  ## Algo does not inf.loop, but does slows down for `n >~ m*keys.len`.
  let nEffective = min(n, m * x.len)
  var count: CountTable[T]
  for i in 0 ..< nEffective:    # Algo must infinite loop at >= nEffective
    var k {.noinit.}: T
    while true:                 # Becomes slow after n >=~ (m-1)*x.len
      k = sample(x, cdf); count.inc k
      if count[k] <= m: break
    yield k

proc sample*(table="wt.NC3CS6C", keys="keys", n=4000, m=3) =
  ## Emit `n`-sample of keys {nl-delim file} weighted by `table` weights
  if dir != ".": setCurrentDir dir
  let wt = wopen(table, keys)               # Hash-not-file order to be 1-pass
  var kys: seq[MSlice]; var cdf: seq[float] # COULD make `cdf` persistent
  for k, ww in wt:
    kys.add wt.keyQ k; cdf.add (if cdf.len==0: 0.0 else: cdf[^1]) + ww.w.float
  if m>0: (for k in kys.cappedSample(cdf, n, m): outu k, "\n")
  else  : (for i in 1..n: outu kys.sample(cdf), "\n")

when isMainModule:
  when not declared(stdout): import std/syncio
  var b = newSeq[char](8192); discard c_setvbuf(stdout, b[0].addr, 0, 8192)
  when defined release: randomize()
  include cligen/mergeCfgEnvMulti
  const hK="path to keys file"; const hW="path to weight source meta file"
  const hT="path to kLkO,WtWhy.NC3CS6C table"; const hO="only \\\\n-delim keys"
  dispatchMulti ["multi", doc="weighted sampling maintainer", vars = @["dir"],
                 mergeNames = @[ "wgt", "_" ], usage="""${doc}
Usage:
⁞ $command [-d|--dir=(".")] {SUBCMD} [sub-command options & parameters]
SUBCMDs:
$subcmds
$command {-h|--help} or with no args at all prints this message.
$command --help-syntax gives general cligen syntax help.
Run "$command {help SUBCMD|SUBCMD --help}" to see help for just SUBCMD.
Run "$command help" to get *comprehensive* help"""],
                [make  , help={"table":hT, "keys":hK, "weights":hW, "only":hO,
                  "refTab": "if given `table`->that, then cmp", "refKey":
                  "if given, keys for refTab for cmp"}, short={"refKey":'R'}],
                [print , help={"table":hT, "keys":hK, "weights":hW, "fmt":
                               "w:weight k:key why:labels; label,Y,N"}],
                [assay , help={"tables": hT & "s" }],
            [wgt.sample, help={"table":hT, "keys":hK, "n":"sample size",
                  "m": "max dups for any given key"}],
                [diff  , help={"oldNew": "<OldLenOffWgtWhy> <NewLenOffWgtWhy>",
                  "keys":hK, "weights":hW, "only":hO}]
