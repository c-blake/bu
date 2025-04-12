import std/[os, posix, tables, sets, strformat, strutils],
       cligen, cligen/[sysUt, humanUt]
when not declared(stdout): import std/[syncio, formatfloat]
proc er(a: varargs[string, `$`]) = stderr.write(a); stderr.write("\n") #alias

var levels: seq[(int,string)] = @[(0, "purple"), (5, "blue"), (25, "cyan"),
  (50, "green"), (75, "yellow"),        # Default colors: violet->red rainbow
  (85, "bold"),                         # Orange on my hacked `st` terminals
  (95, "bold red"), (100, "BLACK")]     # Critical & Weird >100% values
var attrHeader = "inverse"

proc parseColor(color: seq[string], plain=false) =
  for spec in color:
    let cols = spec.strip.splitWhitespace(1)
    if cols.len < 2: Value !! "bad color line: \"" & spec & "\""
    let key = cols[0].optionNormalize
    if key == "header": attrHeader = cols[1]
    elif key.startsWith("pct") and (let thr = parseInt(key[3..^1]); thr >= 0):
      if levels.len > 0 and thr < levels[^1][0]:
        levels.setLen 0
      levels.add (thr, cols[1])
    else: Value !! "expected header|pctINT; got \""&spec&"\""
  for kv in mitems(levels): kv[1] = textAttrOn(kv[1].split, plain)
  levels.add (int.high, "")
  attrHeader = textAttrOn(attrHeader.split, plain)

proc on(f: float): string =
  for i in 1..levels.high:
    if 100*f < levels[i][0].float: return levels[i-1][1]
  levels[^1][1]

var devNmOf = initTable[string, string]()
var devLenMx = len("Filesystem")  # max over ALL MOUNTED, no matter what printed
proc parseMount(mt: string): seq[tuple[devNm, mntPt, fsType: string]] =
  var i = 0
  for line in lines(open(mt)):
    inc i
    let cols = split(line, ' ')
    if cols.len != 6:
      er mt, ":", i, " - badly formatted line"
      continue
    result.add((cols[0], cols[1], cols[2]))
    devLenMx = max(devLenMx, cols[0].len)
    devNmOf[cols[1]] = cols[0]
let mtab = parseMount(getEnv("MTAB", "/proc/mounts"))

proc pct(f: float): string = fmt"{f * 100.0:5.2f} "

var didHeader = false                   # Guard to only print header once.
proc outputRow(mp: string, sf: Statvfs, unit: float, plain=false, avl=0.0): int=
  proc o(a: varargs[string, `$`]) = stdout.write(a)
  if not didHeader:
    didHeader = true                    # Output column headers (once)
    if not plain: o attrHeader
    o alignLeft("Filesystem", devLenMx + 1)
    o fmt"""{"Total":>8} {"Used":>8} {"Avail":>8} {"Use%":>5} {"IUse%":>5}"""
    o " MntOn", (if plain: "" else: textAttrOff), "\n"
  let used = float(sf.f_blocks - sf.f_bfree)    # Output disk free stats
  if not plain:
    o on(if int(sf.f_blocks)>0: used / float(sf.f_blocks) else: 0.0)
  o alignLeft(devNmOf[mp], devLenMx + 1)
  o fmt"{float(sf.f_blocks * sf.f_bsize) / unit:8.2f} "
  o fmt"{used * float(sf.f_bsize) / unit:8.2f} "
  o fmt"{float(sf.f_bavail * sf.f_bsize) / unit:8.2f} "
  if int(sf.f_blocks)>0: o pct(used / float(sf.f_blocks))
  else: o "    - "
  if int(sf.f_files)>0: o pct(float(sf.f_files - sf.f_ffree)/float(sf.f_files))
  else: o "    - "
  o mp, (if plain: "" else: textAttrOff), "\n"
  if avl == 0.0 or 100.0 * (1.0 - used / float(sf.f_blocks)) > avl: 0 else: 1

proc filter(devs: seq[string], fs: seq[string]): seq[string] =
  devLenMx = len("Filesystem")          # Shrink devLenMx based on filtration
  for e in mtab:
    if e.devNm notin devs and e.fsType notin fs:
      result.add(e.mntPt)
      devLenMx = max(devLenMx, e.devNm.len)

proc matchPrefix(path: string): string =
  var lenMax = 0
  result = ""
  for e in mtab:
    if path == e.mntPt or (path.startsWith(e.mntPt&"/") and e.mntPt.len>lenMax):
      lenMax = e.mntPt.len
      result = e.mntPt
  if result.len == 0: result = "/"

proc dfr(devs = @["cgroup_root"], fs = @["devtmpfs"], unit=float(1 shl 30),
         pseudo=false, avail=0.0, Dups=false, colors: seq[string] = @[],
         color: seq[string] = @[], plain=false, paths: seq[string]): int =
  ## Print disk free stats for paths in user-specified units (GiB by default).
  var did = initHashSet[int]()          # did,st to suppress dups/bind mts
  let plain = plain or existsEnv("NO_COLOR")
  if not plain:
    colors.textAttrRegisterAliases      # colors => registered aliases
    color.parseColor
  var st: Stat                          # NOTE: THIS LOOP IS 1-PASS (both stat/
  var sf: Statvfs                       #       statvfs can hang on NFS/etc.)
  for path in (if paths.len > 0: paths else: filter(devs, fs)):
    var rp: string                      # Fully symlink-resolved path
    try:
      rp = expandFilename(path)         # POSIX realpath
    except CatchableError:
      er "dfr: expandFilename(\"", path, "\"): ", osErrorMsg(osLastError())
      continue
    let mp = matchPrefix(rp)
    if not Dups and paths.len == 0:     # Dups mode nicer w/hung NFS mounts
      if stat(mp.cstring, st) < 0:
        er "dfr: stat(\"", mp, "\"): ", osErrorMsg(osLastError())
        continue
      if int(st.st_dev) in did:
        continue                        # Suppress duplicates from mtab
      did.incl int(st.st_dev)
    if statvfs(mp.cstring, sf) < 0:
      er "dfr: statvfs(\"", mp, "\"): ", osErrorMsg(osLastError())
      continue
    if paths.len == 0 and not pseudo and sf.f_blocks == 0:
      continue                          # Suppress pseudo FSes (unless listed)
    result += outputRow(mp, sf, unit, plain, avail)

include cligen/mergeCfgEnv
dispatch dfr, short = {"pseudo": 's', "color": 'c'},
         help = {"devs"  : "devices to EXCLUDE",
                 "fs"    : "FS types to EXCLUDE",
                 "unit"  : "unit of measure in bytes",
                 "pseudo": "list pseudo FSes",
                 "avail" : "exit N if this % is unavailable on N args",
                 "colors": "color aliases; Syntax: name = ATTR1 ATTR2..",
                 "color" : "text attrs for syntax elts; Like lc/etc.",
                 "plain" : "do not colorize",
                 "Dups"  : "skip dup-suppressing stat"}
