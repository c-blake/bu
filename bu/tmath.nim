## Various calendar & time-of-day math routines that operate directly on broken
## down representations with a convenient CLI.
import strutils, strformat
when not declared(addFloat): import std/formatfloat

type Date* = tuple[year, month, day: int]

proc `$`(date: Date): string = &"{date.year}-{date.month:02}-{date.day:02}"

proc julian*(date: Date): int =
  ## Get Julian Days for a given Gregorian date
  let a = (14 - date.month) div 12      # See calendar FAQ$2.15.1
  let y = date.year + 4800 - a
  let m = date.month + 12 * a - 3
  result = (date.day + (153 * m + 2) div 5 +
            y * 365 + y div 4 - y div 100 + y div 400 - 32045)

proc date*(jDays: int): Date =
  ## Get Gregorian date for a given Julian Day in 8 integer divides
  let a = jDays + 32044                 # See calendar FAQ$2.15.1
  let b = (4 * a + 3) div 146097        # 146097 = days in 400 Gregorian Years
  let c = a - (146097 * b) div 4
  let d = (4 * c + 3) div 1461
  let e = c - (1461 * d) div 4          # 1461 = days in 4 Gregorian Years
  let m = (5 * e + 2) div 153
  let y = 100 * b  +  d - 4800  +  m div 10
  result.year  = y
  result.month = m + 3  -  12 * (m div 10)
  result.day   = e  -  (153 * m + 2) div 5  +  1

proc rataDie*(date: Date): int =
  ## Days since Gregorian 1/1/1 for a given date (1 int div, 1 cacheLn).
  const monthDays = [306'i16, 337, 0, 31, 61, 92, 122, 153, 184, 214, 245, 275]
  var (y, m, d) = date  # ^Rotate to start Mar1; Leap days are LAST of a YEAR
  if m < 3: y -= 1      # If Jan/Feb, shift year back 1 as per `monthDays[]`.
  m -= 1                # Make month Zero-Origin for indexing `monthDays`
  let c = y div 100
  365*y + (y shr 2) - c + (c shr 2) - 306 + int(monthDays[m]) + d

proc gregory*(rDays: int): Date =
  ## Gregorian date given days since 1/1/1 (in 4 int divs).
  let z        = rDays + 306    # See Julia: stdlib/dates/src/accessors.jl
  let h        = 100*z - 25
  let a        = h div 3652425
  let b        = a - (a shr 2)
  result.year  = (100*b + h) div 36525
  let c        = b + z - 365*result.year - (result.year shr 2)
  result.month = (5*c + 456) div 153
  result.day   = c - (153*result.month - 457) div 5
  if result.month > 12:
    dec result.month, 12; inc result.year

type HMS = tuple[sign, hour, minute: int; second: float]

proc parseHMS*(hms: string): HMS =
  ## Parse HMS string into signed typed tuple
  let hms = hms.strip
  if hms.len < 1: return
  result.sign = if hms[0] == '-': -1         else: +1
  let hmsAbs = if hms[0] == '-': hms[1..^1] else: hms
  let fields = hmsAbs.split(':')
  if fields.len > 0: result.second = parseFloat(fields[^1])
  if fields.len > 1: result.minute = parseInt(fields[^2])
  if fields.len > 2: result.hour   = parseInt(fields[^3])

proc `$`*(hms: HMS): string =
  var added = false
  if hms.sign   != 1: result.add '-'
  if hms.hour   != 0: result.add &"{hms.hour:d}:"; added = true
  if hms.minute != 0:
    if added:
      result.add &"{hms.minute:02d}:"
    else:
      result.add &"{hms.minute:d}:"
      added = true
  elif added: result.add "00:"
  if hms.second != 0:
    if added:
      if hms.second - float(int(hms.second)) > 1e-6:
        result.add &"{hms.second:09.6f}"
      else:
        result.add &"{int(hms.second):02d}"
    else:
      if hms.second - float(int(hms.second)) > 1e-6:
        result.add &"{hms.second:9.6f}"
      else:
        result.add &"{int(hms.second):2d}"
  elif added: result.add "00"

proc toSeconds*(hms: HMS): float =
  ## Convert signed HMS tuple into signed seconds
  float(hms.sign) * (float(3600*hms.hour + 60*hms.minute) + hms.second)

proc toHMS*(seconds: float): HMS =
  ## Convert signed seconds into signed HMS tuple
  let sec = int(abs(seconds))
  result.sign   = if seconds < 0: -1 else: +1
  result.hour   =  sec div 3600
  result.minute = (sec - result.hour * 3600) div 60
  result.second = seconds - float(result.hour * 3600 + result.minute * 60)

proc addHMS*(args: seq[string]): HMS =
  ## HMS sum of HMS ``args[0]`` and HMS ``args[1]`` (quote "space-")
  result = toHMS(args[0].parseHMS.toSeconds + args[1].parseHMS.toSeconds)

proc toHMSes*(seconds: seq[float]): seq[HMS] =
  ## Get all elements of `seconds` as HMS
  for s in seconds: result.add toHMS(s)

proc seconds*(hmses: seq[string]): seq[float] =
  ## Get all elements of `hmses` as seconds
  for hms in hmses: result.add toSeconds(hms.parseHMS)

when isMainModule:
  import cligen, cligen/argcvt, parseutils

  # 4 echoing, "vectorized" variants for the CLI; Q: Also accept input on stdin?
  proc julians(dates: seq[Date]) =
    ## Julian Days for given Y4-M-D Gregorian dates
    for date in dates: echo julian(date)
  proc dates(jDays: seq[int]) =
    ## Get Gregorian date for a given Julian Day in 8 integer divides
    for jday in jDays: echo date(jDay)
  proc rataDies(dates: seq[Date]) =
    ## Days since Gregorian 1/1/1 for given Y4-M-D dates (1div, 1cacheLn)
    for date in dates: echo rataDie(date)
  proc gregorys(rDays: seq[int]) =
    ## Gregorian dates given days since 1/1/1 (in 4 int divs).
    for rDay in rDays: echo gregory(rDay)

  proc `$`(x: seq[HMS]): string =
    for i, e in x:
      result.add $e
      if i + 1 < x.len: result.add " "

  proc `$`(x: seq[float]): string =
    for i, e in x:
      result.add $e   # Maybe clip at 3..9 decimals?
      if i + 1 < x.len: result.add " "

  proc argParse(dst: var Date, dfl: Date, a: var ArgcvtParams): bool =
    let cols = a.val.split('-')
    if cols.len == 3 and parseInt(cols[0], dst.year) > 0 and
       parseInt(cols[1], dst.month) > 0 and parseInt(cols[2], dst.day) > 0:
      return true
    raise newException(ValueError, "Bad date; expecting int-int-int")

  dispatchMulti [julians], [dates], [rataDies], [gregorys],
                [toHMSes , echoResult=true], [seconds , echoResult=true],
                [addHMS  , echoResult=true],
                [addHMS  , cmdName="+", echoResult=true] # alias for time arith
