import std/[times, strformat, osproc, strutils, os, posix],
       cligen, cligen/[sysUt, osUt, humanUt]
when not declared(readFile): import std/[syncio, formatfloat]

type ETR* = tuple[done, rate, left: float; etc: DateTime]

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

proc etc*(t0: DateTime; age, total, did2, rate: float): ETR =
  result.done = did2/total
  result.rate = rate
  result.left = (total - did2)/result.rate
  result.etc  = t0 + initDuration(milliseconds = int(result.left*1000))

proc `$`*(r: ETR): string =
  &"{done0}{100.0*r.done:.2f} %done{done1} {rate0}{r.rate:.2f} /sec{rate1} " &
  &"{left0}{r.left:.1f} secLeft{left1} {etc0}{r.etc}{etc1}"

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
  let start = parseInt((pfs & "/stat").readFile.split[21])
  0.01 * float(uptime - start)

proc wrStatus(r: ETR; outp,pfs,relTo: string; tot,estMin,RatMin: float): int =
  if outp.len > 0:
    let osz = if outp.notInt: outp.execProcess.strip.parseFloat
              else: (try: (pfs & "fd/" & outp).getFileSize.float except Ce: 0.0)
    let rTo = try: relTo.strip.parseFloat except Ce: (try:
                relTo.execProcess.strip.parseFloat except Ce:
                  erru relTo, " output did not parse as a float\n"; 1.0)
    echo r,&" {ratio0}",r.expSize(osz, if rTo > 0.0: rTo else: tot),&"{ratio1}"
    result = if r.done>=estMin and osz>RatMin*r.done*(if rTo>0:rTo else:tot): 2
             else: 0
  else: echo r

proc etr*(pid=0, did="", total="", age="", scaleAge=1.0, measure=0.0, outp="",
          relTo="", RatMin=1e17, estMin=0.0, kill="NIL",
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
  ##   ``etr -p "$(pf ffmpeg)" -d3 -o4 -m1 -r0 -R.9 -e.01 -k=kill`` # Test ratio
  ##   ``etr -p "$(pf stripe)" -t'ls -1 /DIR|wc -l' -d'grep 7mslot: LOG|wc -l'``
  ## Estimation assumes a constant work rate, equal to average rate so far.  If
  ## `measure>0.0` seconds `etr` instead loops, sleeping that long between polls
  ## monitoring progress, maybe killing & exiting on bad ratios.  If `outp` is
  ## given, report includes expected total output byte/byte ratio.  Exit status
  ## is 2 if *output:input > RatMin* after `estMin` progress.
  if did.len == 0:
    erru "Need @least `did` &likely `pid`; --help says more\n";Parse!!""
  let pfs  = "/proc/" & $pid & "/"
  let age  = if pid==0 or age.len>0: parseFloat(execProcess(age).strip)*scaleAge
             else: processAge(pfs)
  let tot  = if total.len == 0: float(getFileInfo(pfs & "fd/" & did).size)
             elif total.notInt: parseFloat(execProcess(total).strip)
             else: float(getFileInfo(pfs & "fd/" & total).size)
  template q: untyped = (if did.notInt: parseFloat(execProcess(did).strip)
                         else: parseFloat(readFile(pfs&"fdinfo/"&did).split[1]))
  color.parseColor
  var did1 = q                  # 1 data point affords only a trivial estimate..
  let etr = etc(now(), age, tot, did1, did1/age)  #.. for rate == did1/age.
  template writeStatusMaybeKill(etr) =
    result = wrStatus(etr, outp, pfs, relTo, tot, estMin, RatMin)
    if result != 0:                      # outp given & yet getting a too big
      discard execCmd(&"{kill} {pid}");quit 2 #..out/in size ratio => Kill & Quit.
  writeStatusMaybeKill etr
  if measure > 0:
    var did2 = did1; let dt = int(measure/0.001)  # Nim sleep takes millisec
    while pfs.dirExists:
      sleep dt
      did2 = q                                    #TODO Make this much fancier..
      let rate = (did2 - did1)/measure            #..EWMA/LWMA w/moving stddevs
      did1 = did2                                 #..|quantiles for "rate pair".
      let etr = etc(now(), age, tot, did2, rate)  #Add 2nd rate here for 95%/+-
      writeStatusMaybeKill etr

when isMainModule: include cligen/mergeCfgEnv; dispatch etr,
  help={"pid"     : "pid of process in question",
        "did"     : "int fd->fd of `pid`; string-> cmd for did",
        "total"   : "int fd->size(fd); string-> cmd for all work",
        "age"     : "cmd for `age` (age of pid if not given)",
        "scaleAge": "re-scale output of `age` cmd as needed",
        "measure" : "measure rate NOW across this given delay",
        "outp"    : "int->size(fd(pid)); str->cmd giving out used",
        "relTo" :"""emit exp.size : {this float | <=0 to-total}
      | str cmd giving such a float""",
        "RatMin"  : "exit 1 (i.e. \"fail\") for ratios > this",
        "estMin"  : "require > this much progress for RatMin",
        "kill"    : "run this cmd w/arg `pid` if ratio test fails",
        "colors"  : "color aliases; Syntax: name = ATTR1 ATTR2..",
        "color"   : "text attrs for syntax elts; Like lc/etc."}
