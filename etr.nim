import std/[times, strformat, osproc, strutils, os, posix, algorithm],
       cligen, cligen/[sysUt, osUt, humanUt], adix/mvstat
when not declared(readFile): import std/[syncio, formatfloat]

type ETR* = tuple[done, rateLo,rateMid,rateHi, leftLo,leftHi:float;etc:DateTime]

var done0, done1, rate0, rate1, left0, left1, etc0, etc1, ratio0, ratio1 = ""
proc parseColor(color: seq[string]) =
  for spec in color:
    let cols = spec.strip.splitWhitespace(1)
    if cols.len < 2: Value !! "bad color line: \"" & spec & "\""
    let k = cols[0].optionNormalize; let v = cols[1].textAttr
    case k
    of "done0": done0 = v
    of "done1": done1 = v
    of "rate0": rate0 = v
    of "rate1": rate1 = v
    of "left0": left0 = v
    of "left1": left1 = v
    of "etc0" : etc0  = v
    of "etc1" : etc1  = v
    of "ratio0": ratio0  = v
    of "ratio1": ratio1  = v
    else: Value !! "bad color line: \"" & spec & "\""

proc etc*(t0: DateTime; total,did2, rateLo,rateMid,rateHi: float): ETR =
  result.done    = did2/total
  let amtLeft = total - did2
  result.rateLo  = rateLo
  result.rateMid = rateMid
  result.rateHi  = rateHi
  result.leftLo  = amtLeft/result.rateHi
  result.leftHi  = amtLeft/result.rateLo
  let leftMid = amtLeft/result.rateMid
  result.etc     = t0 + initDuration(milliseconds = int(leftMid*1000))

proc `$`*(r: ETR): string =
  if r.leftLo == r.leftHi:
    &"{done0}{100.0*r.done:.2f} %done{done1} {rate0}{r.rateMid:.2f} /s{rate1} "&
    &"{left0}{r.leftLo:.1f} secLeft{left1} {etc0}{r.etc}{etc1}"
  else:
    &"{done0}{100.0*r.done:.2f} %done{done1} {rate0}{r.rateMid:.2f} /s{rate1} "&
    &"{left0}{r.leftLo:.1f} .. {r.leftHi:.1f} sLeft{left1} {etc0}{r.etc}{etc1}"

proc expSize(r: ETR; osz, relTo: float): string =
  if relTo == 1.0: $int(osz.float/r.done) & " B"
  else: &"{osz.float/r.done/relTo.float:.3f}"

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

proc wrStatus(r: ETR; outp,pfs,relTo: string; tot,estMin,RatMin: float): int =
  if outp.len > 0:
    let osz = if outp.notInt: outp.execProcess.strip.parseFloat
              else: (try: (pfs & "fd/" & outp).getFileSize.float except: 0.0)
    let rTo = if relTo.len<1:1.0 else: (try: relTo.strip.parseFloat except:(try:
                relTo.execProcess.strip.parseFloat except:
                  erru relTo, " output did not parse as a float\n"; 1.0))
    echo r,&" {ratio0}",r.expSize(osz, if rTo > 0.0: rTo else: tot),&"{ratio1}"
    result = if r.done>=estMin and osz>RatMin*r.done*(if rTo>0:rTo else:tot): 2
             else: 0
  else: echo r

proc etr*(pid=0, did="", total="", age="", ageScl=1.0, measure=0.0, outp="",
          relTo="", RatMin=1e17, estMin=0.0, kill="NIL", locus="6", scale="0",
          colors: seq[string] = @[], color: seq[string] = @[]): int =
  ## Estimate Time Remaining (ETR) using A) work already done given by `did`,
  ## B) expected total work as given by the output of `total`, and C) the age of
  ## processing (age of `pid` or that produced by the `age` command).  Commands
  ## should emit a number parsable as a float and times are Unix epoch-origin.
  ## To ease common use cases:
  ##   `pid`   given         => default `age` to age of PID
  ##   `did`   parses as int => /proc/PID/fdinfo/FD (default `total` to FD.size)
  ##   `total` parses as int => /proc/PID/fd/FD.size
  ## Some examples (assumes 1 matching pid found by ``pf``, but see procs f -1):
  ##   ``etr -p "$(pf x)" -d3 -a'fage SOME-LOG'``
  ##   ``etr -p "$(pf ffmpeg)" -d3 -o4 -m1 -R.9 -e.01 -k=kill`` # Ratio v.Tot
  ##   ``etr -p "$(pf stripe)" -t'ls -1 /DIR|wc -l' -d'grep 7mslot: LOG|wc -l'``
  ## Estimation assumes a constant work rate, equal to average rate so far.  If
  ## `measure>0.0` seconds `etr` instead loops, sleeping that long between polls
  ## monitoring progress, maybe killing & exiting on bad ratios.  If `outp` is
  ## given, report includes expected total output byte/byte ratio.  Exit status
  ## is 2 if *output:input > RatMin* after `estMin` progress.
  if did.len == 0:
    erru "Need @least `did` &likely `pid`; --help says more\n";Parse!!""
  let pfs  = "/proc/" & $pid & "/"
  let age  = if pid==0 or age.len>0: age.execProcess.strip.parseFloat*ageScl
             else: pfs.processAge
  let tot  = if total.len == 0: getFileInfo(pfs & "fd/" & did).size.float
             elif total.notInt: total.execProcess.strip.parseFloat
             else: getFileInfo(pfs & "fd/" & total).size.float
  template q: untyped = (if did.notInt: did.execProcess.strip.parseFloat
                         else: readFile(pfs&"fdinfo/"&did).split[1].parseFloat)
  color.parseColor
  try:
    var did1 = q; var t = now()   # 1 data point affords only a trivial estimate
    let r = did1/age              #.. for rate, namely `did1/age`.
    template writeStatusMaybeKill(et) =
      result = wrStatus(et, outp, pfs, relTo, tot, estMin, RatMin)
      if result != 0:                   # outp given,yet Osz/Isz getting too big
        discard execCmd(&"{kill} {pid}");quit 2 # => Kill & Quit.
    writeStatusMaybeKill etc(t, tot, did1, r, r, r)
    if measure > 0:                     # -m also could stand for "monitor"
      let dt  = int(measure/0.001)      # Nim sleep takes millisec
      var tms = @[t.toTime.toUnixFloat - age, t.toTime.toUnixFloat]
      var dids = @[0.0, did1] #TODO `tot` MAY be dyn,but reQry wasteful if not
      #TODO Generalize to (EW|LW|x)M[AD]|Qtls for rate location & scale estimate
      let (winL, winS) = (locus.parseInt, scale.parseInt)
      var loc = initMovingStat[float, float](options={OrderStats})
      loc.push did1/age
      while pfs.dirExists:              # Re-query time to trust sleep dt less..
        sleep dt; dids.add q            #..in case we get SIGSTOP'd or etc.
        let t = now()
        tms.add t.toTime.toUnixFloat
        let rate = (dids[^1] - dids[^2])/(tms[^1] - tms[^2])
        if dids.len > winL:             # Location gets a simple moving window
          let winLp1 = winL + 1
          loc.pop (dids[^winL] - dids[^winLp1])/(tms[^winL] - tms[^winLp1])
        loc.push rate
        let rateMid = loc.mean
        let leftMid = (tot - dids[^1])/rateMid
  # If N sec left,want data from past N sec to estim.scale.  Start anew each tm.
        var scl = initMovingStat[float, float](options={OrderStats})
        let i0 = lowerBound(tms, tms[^1] - leftMid)
        for i in i0..<tms.len - 1:                  
          scl.push (dids[i+1] - dids[i])/(tms[i+1] - tms[i])
        let rateLo = if dids.len < 7: scl.min else: scl.quantile 0.25
        let rateHi = if dids.len < 7: scl.max else: scl.quantile 0.75
        writeStatusMaybeKill etc(t, tot, dids[^1], rateLo, rateMid, rateHi)
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
        "locus"  : "maker for moving rate location (for ETC)",
        "scale"  : "maker for moving rate scale (for range)",
        "colors" : "color aliases; Syntax: name = ATTR1 ATTR2..",
        "color"  : "text attrs for syntax elts; Like lc/etc."},
  short={"ageScl": 'A'}
