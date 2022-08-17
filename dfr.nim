import os, posix, tables, sets, strformat, strutils, cligen, cligen/humanUt
proc o(a: varargs[string, `$`]) = stdout.write(a)         #short aliases
proc er(a: varargs[string, `$`]) = stderr.write(a); stderr.write("\n")

#TODO: These levels should user config'd, but best of all would be an option for
#  a true-color HSV scale w/Hue tracking PercentFull & SV being LC_THEME-driven.
var highlights = { "pct0"  : "purple",  # rainbow/spectrum order violet->red
                   "pct5"  : "blue",
                   "pct25" : "cyan",
                   "pct50" : "green",
                   "pct75" : "yellow",
                   "pct85" : "bold",    # orange on my hacked `st` terminal
                   "pct95" : "bold red",
                   "pct100": "BLACK", "header" : "inverse" }.toTable
var attr: Table[string, string]

proc parseColor(color: seq[string], plain=false) =
  for spec in color:
    let cols = spec.strip.splitWhitespace(1)
    if cols.len < 2:
      raise newException(ValueError, "bad color line: \"" & spec & "\"")
    let key = cols[0].optionNormalize
    if key notin highlights:
      raise newException(ValueError, "unknown color key: \"" & spec & "\"")
    highlights[key] = cols[1]
  for k, v in highlights:
    attr[k] = textAttrOn(v.split, plain)

var devNmOf = initTable[string, string]()
var devLenMx = len("Filesystem")  #max over ALL MOUNTED, no matter what printed
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
let mtabLoc = getEnv("MTAB")
let mtab = parseMount(if mtabLoc.len > 0: mtabLoc else: "/proc/mounts")

proc on(f: float): string =
  if   f < 0.05: attr["pct0"]
  elif f < 0.25: attr["pct5"]
  elif f < 0.50: attr["pct25"]
  elif f < 0.75: attr["pct50"]
  elif f < 0.85: attr["pct75"]
  elif f < 0.95: attr["pct85"]
  elif f < 1.00: attr["pct95"]
  else: attr["pct100"]

proc pct(f: float): string = fmt"{f * 100.0:5.2f} "

var didHeader = false                   #guard to only print header once.
proc outputRow(mp: string, sf: Statvfs, unit: float, plain=false, avl=0.0): int=
  if not didHeader:
    didHeader = true                    #output column headers (once)
    if not plain: o attr["header"]
    o alignLeft("Filesystem", devLenMx + 1)
    o fmt"""{"Total":>8} {"Used":>8} {"Avail":>8} {"Use%":>5} {"IUse%":>5}"""
    o " MntOn", (if plain: "" else: textAttrOff), "\n"
  let used = float(sf.f_blocks - sf.f_bfree)    #output disk free stats
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
  for e in mtab:
    if e.devNm notin devs and e.fsType notin fs:
      result.add(e.mntPt)

proc matchPrefix(path: string): string =
  var lenMax = 0
  result = ""
  for e in mtab:
    if path == e.mntPt or (path.startsWith(e.mntPt&"/") and e.mntPt.len>lenMax):
      lenMax = e.mntPt.len
      result = e.mntPt
  if result.len == 0: result = "/"

proc dfr(devs = @[ "cgroup_root" ], fs = @[ "devtmpfs" ], unit = 1073741824.0,
         pseudo=false, avail=0.0, Dups=false, colors: seq[string] = @[],
         color: seq[string] = @[], plain=false, paths: seq[string]): int =
  ## Print disk free stats for paths in user-specified units (GiB by default).
  var did = initHashSet[int]()        #did,st to suppress dups/bind mts
  let plain = plain or existsEnv("NO_COLOR")
  if not plain:
    colors.textAttrRegisterAliases      # colors => registered aliases
    color.parseColor
  var st: Stat
  var sf: Statvfs
  for path in (if paths.len > 0: paths else: filter(devs, fs)):
    var rp: string                      #fully symlink-resolved path
    try:
      rp = expandFilename(path)         #POSIX realpath
    except:
      er "dfr: expandFilename(\"", path, "\"): ", osErrorMsg(osLastError())
      continue
    let mp = matchPrefix(rp)
    if not Dups and paths.len == 0:     #Dups mode nicer w/hung NFS mounts
      if stat(mp.cstring, st) < 0:
        er "dfr: stat(\"", mp, "\"): ", osErrorMsg(osLastError())
        continue
      if int(st.st_dev) in did:
        continue                        #suppress duplicates from mtab
      did.incl int(st.st_dev)
    if statvfs(mp.cstring, sf) < 0:
      er "dfr: statvfs(\"", mp, "\"): ", osErrorMsg(osLastError())
      continue
    if paths.len == 0 and not pseudo and sf.f_blocks == 0:
      continue                          #suppress pseudo FSes (unless listed)
    result += outputRow(mp, sf, unit, plain, avail)

include cligen/mergeCfgEnv
dispatch dfr, short = {"pseudo": 's', "color": 'c'},
         help = {"devs"  : "devices to EXCLUDE",
                 "fs"    : "FS types to EXCLUDE",
                 "unit"  : "unit of measure",
                 "pseudo": "list pseudo FSes",
                 "avail" : "exit N if this % is unavailable on N args",
                 "colors": "color aliases; Syntax: name = ATTR1 ATTR2..",
                 "color" : "text attrs for syntax elts; Like lc/etc.",
                 "plain" : "do not colorize",
                 "Dups"  : "skip dup-suppressing stat"}
