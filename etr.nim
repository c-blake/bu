import times, strformat, osproc, strutils, os, cligen

type ETR* = tuple[done, rate, left: float; etc: DateTime]

proc etc*(t0: DateTime; age, total, did1, did2, measure: float): ETR =
  result.done = did2 * 100.0 / total
  result.rate = if did2 > did1 and measure > 0.0: (did2 - did1)/measure
                else: did1 / age
  result.left = (total - did2) / result.rate
  result.etc  = t0 + initDuration(milliseconds = int(result.left * 1000))

func `$`*(a: ETR): string =
  &"{a.done:.2f} %done  {a.rate:.2f} /sec  {a.left:.1f} secLeft  {a.etc}"

func notInt(str: string): bool =
  for ch in str: (if ch notin {'0'..'9'}: return true)

proc processAge(pfs: string): float =
  var buf = "/proc/uptime".readFile
  let decimal = buf.find('.')
  if decimal == -1: return
  buf[decimal..decimal+1] = buf[decimal+1..decimal+2]
  buf[decimal+2] = ' '
  let uptime = parseInt(buf.split[0])
  let start = parseInt((pfs & "/stat").readFile.split[21])
  0.01 * float(uptime - start)

proc etr*(pid=0, did="", total="", age="", scaleAge=1.0, measure=0.0) =
  ## Estimate Time Remaining (ETR) using A) work already done given by `did`,
  ## B) expected total work as given by the output of `total`, and C) the age of
  ## processing (age of `pid` or that produced by the `age` command).  Commands
  ## should emit a number parsable as a float and times are Unix epoch-origin.
  ## To ease common use cases:
  ##   `pid`   given         => default `age` to age of PID
  ##   `did`   parses as int => /proc/PID/fdinfo/FD (default `total` to FD.size)
  ##   `total` parses as int => /proc/PID/fd/FD.size
  ## Some examples (each assumes only 1 matching pid found by ``pf``):
  ##   ``etr -p$(pf ffmpeg) -d3 -m5.0``
  ##   ``etr -p$(pf x) -d3 -a'fage SOME-LOG'``
  ##   ``etr -p$(pf stripe) -t'ls -1 /DIR|wc -l' -d'grep 7mslot: LOG|wc -l'``
  ## Estimation assumes a constant work rate, equal to the average so far.  If
  ## you give a `measure > 0.0` seconds that will instead use the present rate
  ## (unless there is no change in `did` across the measurement).
  if did.len == 0:
    stderr.write "Need at least `did` & likely `pid`; --help says more\n"
    raise newException(ParseError, "")
  let pfs  = "/proc/" & $pid & "/"
  let age  = if pid==0 or age.len>0: parseFloat(execProcess(age).strip)*scaleAge
             else: processAge(pfs)
  let tot  = if total.len == 0:  float(getFileInfo(pfs & "fd/" & did).size)
             elif total.notInt: parseFloat(execProcess(total).strip)
             else: float(getFileInfo(pfs & "fd/" & total).size)
  let did1 = if did.notInt: parseFloat(execProcess(did).strip)
             else: parseFloat(readFile(pfs & "fdinfo/" & did).split()[1])
  var did2 = did1
  if measure > 0.0:
    sleep(int(measure / 0.001))
    did2 = if did.notInt: parseFloat(execProcess(did).strip)
           else: parseFloat(readFile(pfs & "fdinfo/" & did).split()[1])
  echo etc(now(), age, tot, did1, did2, measure)

when isMainModule:
  dispatch etr,
           help={"pid"     : "pid of process in question",
                 "did"     : "int fd->fd of `pid`; string-> cmd for did",
                 "total"   : "int fd->size(fd); string-> cmd for all work",
                 "age"     : "cmd for `age` (age of pid if not given)",
                 "scaleAge": "re-scale output of `age` cmd as needed",
                 "measure" : "measure rate NOW across this given delay" }
