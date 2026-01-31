when not declared(File): import std/syncio
import std/[sugar, strformat, algorithm], adix/ways,
       cligen, cligen/[sysUt, osUt, mfile, mslice]
proc err(A:varargs[string,`$`]) = (for a in A: erru a); erru '\n'

# Zsh does \\ if user explicitly ends lines w/'\', \ if cmd just continues.
proc trimN*(c: var MSlice) = # Trim trailing junk ~ ": 1759392125:0;date\\\n\n"
  while c.len>2 and c[c.len-2]=='\\' and c[c.len-1]=='\n': # Bare single-\ =>
    c.len -= 2 + int(c[c.len-3]=='\\') # 3 if usr put literal '\';2 if pasted \n

type ZHistEnt* = tuple[tm, dur: int; cmd: MSlice]
proc `$`*(he: ZHistEnt): string = &": {he.tm}:{he.dur};{he.cmd}"

iterator zHistEnts*(path=""): ZHistEnt = # Old i7 parses@~33ns/entry
  ## Parse large Zsh history files; Yield `ZHistEnt`s. `path` must be mmappable.
  const D = {'0'..'9'}  # Digit
  let mf = if path.len == 0: mopen(0, err=nil) else: mopen(path, err=nil)
  if mf.mem != nil:
    var lno = 0                 # 1-origin line nums
    var he: ZHistEnt            # Assume path mmap-able in order so..
    var accum = false           #..can extend MSlice, never allocating.
    for s in mSlices mf:
      inc lno
      if accum:
        he.cmd.len = (s.mem +! s.len) -! he.cmd.mem
        if s.len > 0 and s[s.len - 1] == '\\': discard # still accumulating
        else: yield he; accum = false                  # done accumulating
      else:
        if s.len > 15:          # <16 *must* be a continuation line
          if s[0]==':'and s[1]==' 'and s[12]==':' and s[2]in D and s[3]in D and
             s[4]in D and s[5]in D and s[6]in D and s[7]in D and s[8]in D and
             s[9]in D and s[10]in D and s[11]in D:            # 10-digit epochTm
            he.tm = MSlice(mem: s.mem +! 2, len: 10).parseInt # Ie. > Sep 8,2001
            let eodur = MSlice(mem: s.mem +! 13, len: s.len - 13).find(';')
            if eodur >= 0:
              he.dur = MSlice(mem: s.mem +! 13, len: eodur).parseInt
              he.cmd.mem = s.mem +! (13 + eodur + 1)
              he.cmd.len = s.len - (13 + eodur + 1)
            else: err lno,": !ZshExtHist1: \"",$s,"\""
          else: err lno,": !ZshExtHist2: \"",$s,"\""
          accum = s[s.len - 1] == '\\'
          if not accum: yield he
        else: err lno,": !ZshExtHist3: \"",$s,"\""
    if accum: yield he  # mf.close # Keep memory alive for life of program

proc mkZHistEntItr*(path: string, trim=false): iterator(): ZHistEnt =
  iterator (): ZHistEnt =               # Closure iterator factory
    for he in zHistEnts(path):
      if trim: (var he = he; he.cmd.trimN; yield he)
      else: yield he

proc zeh(min=0, trim=false, check=false, sort=false, begT=false, endT=false,
         reps=0, paths: seq[string]) =
  ## Check|Merge, de-duplicate&clean short cmds/trailing \\n Zsh EXTENDEDHISTORY
  ## (format ": {t0%d}:{dur%d};CMD-LINES[\\]"); Eg.: `zeh -tm3 h1 h2 >H`.  Zsh
  ## saves start & duration *@FINISH TIME* => with >1 shells in play, only brief
  ## cmds match the order of timestamps in the file => provide 3 more modes on
  ## to of `--check`: `--endT`, `--sort`, `--begT`.
  if paths.len < 1: Help !! "Need >= 1 path; Full $HELP"
  if reps > 0:  # Make large histories from a smaller sample (to measure stuff)
    var hes = collect(for he in paths[0].zHistEnts: he)
    if hes.len > 1:
      let span = hes[^1].tm - hes[0].tm + 1
      for r in 0..<reps:
        for hent in paths[0].zHistEnts:
          var he = hent; he.tm += r*span; outu he,'\n'
  elif begT:
    for he in paths[0].zHistEnts:
      var he = he; he.tm -= he.dur; outu he,'\n'
  elif endT:
    for he in paths[0].zHistEnts:
      var he = he; he.tm += he.dur; outu he,'\n'
  elif sort:
    if paths.len != 1: Help !! "Need == 1 path; Full $HELP"
    var hes = collect(for he in paths[0].zHistEnts: he)
    hes.sort
    var last: ZHistEnt
    for he in hes:
      if he != last: outu he,'\n'
      last = he
  elif check:
    for path in paths:
      var eno, tLast = 0
      for he in path.zHistEnts:
        inc eno
        if he.tm<tLast: err &"zeh: {path}:{eno} out-of-order: {he.tm}!<{tLast}"
        tLast = he.tm
      err &"{eno} entries in {path}"
  else:
    let its = collect(for path in paths: path.mkZHistEntItr(trim))
    var last: ZHistEnt
    for he in kWayMerge(its):
      if he.cmd.len > min:
        if he != last: outu he,'\n'
        else: last = he

when isMainModule: include cligen/mergeCfgEnv; dispatch zeh, help={
  "min"  : "Minimum length of a command to keep",
  "trim" : "Trim trailing whitespace",
  "check": "Only check validity of each of `paths`",
  "sort" : "sort exactly 1 path by startTm,duration",
  "begT" : "add dur to take startTm,dur -> endTm,dur",
  "endT" : "sub dur to take endTm,dur -> startTm,dur",
  "reps" : "make `reps` copies of $1 w/increasing tms"}
