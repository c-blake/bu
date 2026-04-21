when not declared(stdin): import std/syncio
import std/[hashes, times, strformat], cligen/[mfile, mslice, osUt], adix/oats
const bLen {.intdefine.} = 24   # <16M long;  RT params better but less easy
const bOff {.intdefine.} = 40   # <1T UNIQUE record data
type
  Key {.packed.} = object       # Dense-ish hash Key type
    when defined hashCache: hc: uint32 # 8..12 Bytes/HashCell
    len {.bitsize: bLen.}: uint32
    off {.bitsize: bOff.}: uint64
  Keys = object
    dat: seq[Key]
    nUsed: int
var s: string; oatKStack s, Keys, Key, off,uint64, MSlice, MSlice
proc key(c: Keys, i: int): MSlice = c.dat[i].key
proc used(c: Keys, i: int): bool = c.dat[i].len != 0
when defined hashCache:         # 2nd def triggers saving lpt behavior
  proc hash(ms: MSlice): Hash = mslice.hash(ms).uint32.Hash
  proc hash(c: var Keys, i: int, hc: Hash) {.used.} = c.dat[i].hc = hc.uint32
  proc hash(c: Keys, i: int): Hash = c.dat[i].hc.Hash
oatCounted c, Keys, c.nUsed; oatSeq Keys, dat   # make counted & resizable

var nR, trunc = 0; var tmLimit = 100; var reverse=false; var mf: MFile
iterator records(term: char): MSlice =
  if mf.mem.isNil:
    for (rec, nRec) in stdin.getDelims(term): yield MSlice(mem: rec, len: nRec)
  elif reverse:
    for s in mf.mslc.mSlicesReversed(term): (var s=s; s.len.inc; yield s)
  else:
    for s in mf.mslc.mSlices(term): (var s=s; s.len.inc; yield s)

proc containsOrIncl(ks: var Keys, k: MSlice): bool =
  var k = k
  if k.len > (1 shl bLen) - 1:          # Do not overflow
    if nR - trunc > tmLimit:            # Rate limit truncation messages
      erru &"k1st: stdin:{nR} truncated {$k.len}-record: {($k)[0..<16]}..\n"
      trunc = nR
    k.len = (1 shl bLen) - 1
  ks.upSert(k, i): result = true        # Found key @i:
  do:                                   # Novel key->i:
    ks.dat[i].off = s.add(k, (1 shl bOff) - 1):
      quit &"k1st: stdin:{nR}: unique data offset overflow\n", 1 # Cannot go on
    ks.dat[i].len = k.len.uint32        # Init; Keep synced w/Key.len type!

type Msgs = enum mMiss="missing", mSumm="summary", mTime="time"
proc k1st(size=999, bSize=9999, term='\n', delim='\t', keyI=0, TMLim=100,
          rev=false, msgs: set[Msgs]={}) =
  ## Write `stdin` rows in-order k)eeping only first `keyI`-*unique* rows.  Eg.:
  ##   ``< $z/history tac -s "" | k1st -t\\\\0 -d\\\\1 -k1 | vip ...``
  let t0 = if mTime in msgs: epochTime() else: 0.0
  var ks: Keys; ks.setCap size          # pre-size table & data
  mf = mopen(0)
  if mf.mem.isNil: s.setLen bSize; s.setLen 0
  reverse = rev
  tmLimit = TMLim
  var fs: seq[MSlice]
  for ms in records(term):
    inc nR
    let n = ms.msplit(fs, delim, keyI + 1)
    if n != keyI + 1:
      if mMiss in msgs: erru &"k1st: stdin:{nR} missing fields\n"
    else:
      if not ks.containsOrIncl(fs[keyI]): outu ms
  if mSumm in msgs: erru &"{nR} total  {ks.len} written  {s.len} dataBytes\n"
  if mTime in msgs: erru &"{epochTime() - t0:.6f} sec\n"

when isMainModule:import cligen;include cligen/mergeCfgEnv; dispatch k1st,help={
  "size" : "entry pre-size of table",
  "bSize": "byte pre-size of unique data;Unseekable stdin",
  "term" : "input row terminator byte",
  "delim": "input column delimiter byte",
  "keyI" : "index of unique key column",
  "TMLim": "min distance between truncation msgs",
  "rev"  : "go backwards from EOF; Seekable stdin",
  "msgs" : "emit to stderr: missing, summary, time"}
