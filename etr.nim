import std/[times, strformat, osproc, strutils, os, posix, math],
       cligen, cligen/[sysUt, osUt, humanUt], adix/[xhist1, lna, lmbist]
when not declared(readFile): import std/[syncio, formatfloat]
xhist1.def LBist, lna, exp, LMBist[uint16]
xhist1.defMove RDist, LBist, it.t + 1, it.t + 1 - it.win
proc initRDist(w: int): RDist = initRDist(win=w)

type ETR* = tuple[done,total, leftLo,rateMid,leftHi: float; etc: DateTime]

var done0, done1, rate0, rate1, left0, left1, etc0, etc1, ratio0, ratio1 = ""
proc parseColor(color: seq[string]) =
  for spec in color:
    let cols = spec.strip.splitWhitespace(1)
    if cols.len < 2: Value !! "bad color line: \"" & spec & "\""
    let v = cols[1].textAttr
    case cols[0].optionNormalize # key
    of "done0" : done0  = v
    of "done1" : done1  = v
    of "rate0" : rate0  = v
    of "rate1" : rate1  = v
    of "etc0"  : etc0   = v
    of "etc1"  : etc1   = v
    of "left0" : left0  = v
    of "left1" : left1  = v
    of "ratio0": ratio0 = v
    of "ratio1": ratio1 = v
    else: Value !! "bad color line: \"" & spec & "\""

proc etc*(t0: DateTime; total, did, rateLo, rateMid, rateHi: float): ETR =
  let invTot     = if total != 0: 1/total else: 1
  result.total   = total
  result.done    = did*invTot
  result.rateMid = rateMid*invTot
  result.leftLo  = (total - did)/rateHi
  let leftMid    = (total - did)/rateMid
  result.leftHi  = (total - did)/rateLo
  result.etc     = t0 + initDuration(milliseconds=int(leftMid*1000))

proc `$`*(e: ETR): string =
  let et = e.etc.format("MMdd'T'HH:mm:ss'.'fff")[0..^3]
  &"{done0}{1e2*e.done:06.3f} %{done1} " &
  &"{rate0}{1e4*e.rateMid:.2f} bp/s {e.rateMid*e.total:.4g} /s{rate1} " &
  &"{etc0}{et}{etc1} {left0}{e.leftLo:.1f} - {e.leftHi:.1f} sLeft{left1}"

proc expSize(e: ETR; osz, relTo: float): string =
  if relTo == 1.0: $int(osz.float/e.done)
  else: &"{osz.float/e.done/relTo.float:.3f}"

func notInt(str: string): bool =
  for ch in str: (if ch notin {'-','0'..'9'}: return true)

proc processAge(pfs: string): float =
  var buf = "/proc/uptime".readFile
  let decimal = buf.find('.')
  if decimal == -1: return
  buf[decimal..decimal+1] = buf[decimal+1..decimal+2]
  buf[decimal+2] = ' '
  let uptime = parseInt(buf.split[0])
  let start = (pfs & "/stat").readFile.split[21].parseInt
  float(uptime - start)*0.01    # Jiffies -> seconds

proc wrStatus(e: ETR; outp,pfs,relTo: string; tot,estMin,RatMin: float): int =
  if outp.len > 0:
    let osz = if outp.notInt: outp.execProcess.strip.parseFloat
              else: (try: (pfs & "fd/" & outp).getFileSize.float except: 0.0)
    let rTo = if relTo.len<1:1.0 else: (try: relTo.strip.parseFloat except:(try:
                relTo.execProcess.strip.parseFloat except:
                  erru relTo, " output did not parse as a float\n"; 1.0))
    echo e,&" {ratio0}",e.expSize(osz, if rTo > 0.0: rTo else: tot),&"{ratio1}"
    result = if e.done>=estMin and osz>RatMin*e.done*(if rTo>0:rTo else:tot): 2
             else: 0
  else: echo e

proc etr*(pid=0,did="",total="",age="",ageScl=1.0,measure=0.0, outp="",relTo="",
 RatMin=1e17, estMin=0.0, kill="NIL", locus=15, scale=0.2..0.8, update=false,
 write="", colors: seq[string] = @[], color: seq[string] = @[]): int =
  ## Estimate Time Remaining (ETR) using A) work already done given by `did`,
  ## B) expected total work as given by the output of `total`, and C) the age of
  ## processing (age of `pid` or that produced by the `age` command).  Commands
  ## should emit a number parsable as a float and times are Unix epoch-origin.
  ## To ease common use cases:
  ##   `pid`   given         => default `age` to age of PID
  ##   `did`   parses as int => /proc/PID/fdinfo/FD (default `total` to FD.size)
  ##   `total` parses as int => /proc/PID/fd/FD.size
  ## Some examples (assumes 1 matching pid found by ``pf``, but see procs f -1):
  ##   ``gzip -9 < in > o.gz & sleep 2; etr -p $! -d0 -o1 -m2 -r0``
  ##   ``etr -p "$(pf x)" -d3 -a'fage SOME-LOG'``
  ##   ``etr -p "$(pf ffmpeg)" -d3 -o4 -m1 -r0 -R.9 -e.01 -k=kill`` # RatioV.Tot
  ##   ``etr -p "$(pf stripe)" -t'ls -1 /DIR|wc -l' -d'grep 7mslot: LOG|wc -l'``
  ## If `measure>0.0` seconds `etr` instead loops, sleeping that long between
  ## polls monitoring progress, maybe killing & exiting on bad ratios.  If
  ## `outp` is given, report includes expected total output byte/byte ratio.
  ## Exit status is 2 if *output:input > RatMin* after `estMin` progress.
  if did.len == 0:
    erru "Need @least `did` &likely `pid`; --help says more\n";Parse!!""
  let pfs = &"/proc/{pid}/"
  let age = if pid==0 or age.len>0: age.execProcess.strip.parseFloat*ageScl
            else: pfs.processAge
  let t00 = now()
  template qT:untyped=(if total.len==0: getFileInfo(&"{pfs}fd/{did}").size.float
                       elif total.notInt: total.execProcess.strip.parseFloat
                       else: getFileInfo(&"{pfs}fd/{total}").size.float)
  template qD:untyped=(if did.notInt: did.execProcess.strip.parseFloat
                       else: readFile(&"{pfs}fdinfo/{did}").split[1].parseFloat)
  color.parseColor
  try:
    var tot  = qT
    var did0 = qD; var t0=now() # 1 data point affords only a trivial estimate
    let r0   = did0/age         #.. for rate, namely `did0/age`.
    template writeStatusMaybeKill(e) =
      result = wrStatus(e, outp, pfs, relTo, tot, estMin, RatMin)
      if result != 0:           # outp given,yet Osz/Isz getting too big
        discard execCmd(&"{kill} {pid}");quit 2 # => Kill & Quit.
    writeStatusMaybeKill etc(t0, tot, did0, r0, r0, r0)
    if measure > 0:             # -m also could stand for "monitor"
      let ms = int(measure*1e3) # Nim sleep takes millisec
      var rate = initRDist(abs(locus))
      rate.add r0
      let w = if write.len>0: (try: open(write, fmAppend, 0) except:nil)else:nil
      if w != nil: w.write &"age dt did0 did1 tot\n"
      while pfs.dirExists:      # Re-query time to trust sleep dt less..
        sleep ms                #..in case we get SIGSTOP'd or etc.
        let did1 = qD; let t = now()
        if update: tot = qT
        let da = (t - t00).inNanoseconds.float*1e-9
        let dt = (t - t0).inNanoseconds.float*1e-9
        rate.add (did1 - did0)/dt
        if w != nil: w.write &"{age+da:.6f} {dt:.6f} {did0} {did1} {tot}\n"
        did0 = did1; t0 = t
        let (a, b) = (rate.quantile scale.a, rate.quantile scale.b)
        let m = if locus < 0: 0.5*(a + b) else: rate.quantile 0.5
        writeStatusMaybeKill etc(t, tot, did1, a, m, b)
  except IOError: quit 3        # Probably some racy `readFile` failure

when isMainModule: include cligen/mergeCfgEnv; dispatch etr,
  help={"pid"    : "pid of process in question",
        "did"    : "int fd->fd of `pid`; string-> cmd for did",
        "total"  : "int fd->size(fd); string-> cmd for all work",
        "age"    : "cmd for `age` (age of pid if not given)",
        "ageScl" : "re-scale output of `age` cmd as needed",
        "measure": "measure rate NOW across this given delay",
        "outp"   : "int->size(fd(pid)); str->cmd giving out used",
        "relTo" :"""expctdSz rel.To: { float / ""|<=0 => total }
               | str cmd giving such a float""",
        "RatMin" : "exit 1 (i.e. \"fail\") for ratios > this",
        "estMin" : "require > this much progress for RatMin",
        "kill"   : "run this cmd w/arg `pid` if ratio test fails",
        "locus"  : "window for moving rate location (for ETC)",
        "scale"  : "lo,hi probabilities for rate/etc range",
        "update" : "re-query total each sample in measure mode",
        "write"  : "log \"raw\" data samples to this file",
        "colors" : "color aliases; Syntax: name = ATTR1 ATTR2..",
        "color"  : "text attrs for syntax elts; Like lc/etc."},
  short={"ageScl": 'A'}
