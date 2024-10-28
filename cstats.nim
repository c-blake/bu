import std/[math, strutils, algorithm, heapqueue], cligen/strUt,
       adix/mvstat, fitl/qtl, bu/labFloats
when not declared(stdin): import std/[syncio, formatfloat]

proc needToSort(stats: seq[string]): bool =
  for ex in stats: (if ex.startsWith("q"): return true)

proc valueSpace(ex: string): bool = ex.startsWith("q") or ex.startsWith("m")

proc most(x: seq[float]; sign, n: int): seq[float] =
  var q: HeapQueue[float]
  let s = sign.float
  for e in x:
    let e = s * e
    if q.len < n : q.push e
    elif e > q[0]: discard q.replace(e)
  while q.len > 0: result.add s*q.pop

proc filter(x: seq[float]; didSort: bool; min, max: int): seq[float] =
  if   min > 0: (if didSort: x[0..min-1] else: x.most(-1, min))
  elif max > 0: (if didSort: x[max..^1]  else: x.most(+1, max))
  else: x # Unneeded copy, but eh..This is not for "big" data.

proc cstats*(delim="white", table="", hsep="strip", pm=" +- ", exp = -2..4,
             nd=2, unity="$val0${pm}$err0", sci="($valMan $pm $errV)$valExp",
             join=",", min=0, max=0, stats: seq[string]) =
  ## This consumes any stdin looking like regular intercalary text with embedded
  ## floats & prints a summary with the LAST such text & requested `stats` for
  ## any varying float column. If `table!=""`, context is joined via `hsep` into
  ## headers for associated reduced numbers, with columns separated by `table`
  ## (eg. ',').  Available stats (ms if none given)..
  ##   mn: mean      sd: sdev      se: stderr(mean) (i.e. sdev/n.sqrt)
  ##   sk: skewness  kt: kurtosis  ms: mn +- se via `pm exp nd unity sci` params
  ##   iq: interQuartileRange      sq: semi-interQuartileRange   n: len(nums)
  ##   qP: General Parzen interpolated quantile P (0<=P<=1 float; 0=min; 1=max)
  ## ..print as separate rows in the `table` mode or else joined by `join`.
  let stats = if stats.len == 0: @["ms"] else: stats
  let doSort = stats.needToSort
  var (labs, nums) = labFloats(stdin, initSep(delim))
  strUt.pmDfl = pm

  proc toStr(ex, con: string, bs: BasicStats[float], x: seq[float]): string =
    if bs.min == bs.max:                # Numeric but non-varying
      if ex.valueSpace: con else: "0"   # value space=>unparsed; variation=>"0"
    elif ex.startsWith("q") and(let q=parseFloat(ex[1..^1]); 0.0<=q and q<=1.0):
      $x.quantile(q)                    # TODO precision/format controls?
    else: # Could pre-parse expressions, but many columns seem unlikely
      let se = bs.sdev/bs.n.float.sqrt  # en.wikipedia.org/wiki/Standard_error
      case ex
      of "mn": fmtUncertain(bs.mean, se, "$val0", "$valMan$valExp", exp, nd)
      of "sd": $bs.sdev                 # TODO should do only nd digits
      of "se": fmtUncertain(bs.mean, se, "$err0", "$errV$valExp", exp, nd)
      of "ms": fmtUncertain(bs.mean, se,  unity, sci, exp, nd)
      of "sk": $x.skewness              # TODO should do only nd digits
      of "kt": $x.kurtosis              # TODO should do only nd digits
      of "iq": $(x.quantile(0.75) - x.quantile(0.25))
      of "sq": $((x.quantile(0.75) - x.quantile(0.25))*0.5)
      of "n" : $x.len
      else: "unknownOp"

  if table.len > 0:                     # Multi-row format for data reduction
    var hdr: string
    var hdrs: seq[string]
    var rows = newSeq[seq[string]](stats.len)
    let doStrip = hsep == "strip"
    let hsep = if doStrip: "" else: hsep
    for j, con in labs:
      if nums[j].len > 0:               # Numeric
        if hdr.len > 0:
          hdrs.add if doStrip: hdr.strip else: hdr
          hdr.setLen 0
        if doSort: nums[j].sort
        let bs = nums[j].filter(doSort, min, max).basicStats
        for i, ex in stats: rows[i].add ex.toStr(con, bs, nums[j])
      else:                             # Non-Numeric
        if hdr.len > 0: hdr.add hsep
        hdr.add con
    if hdr.len > 0:                     # Last header may be empty
      hdrs.add if doStrip: hdr.strip else: hdr
    stdout.write join(hdrs, table), "\n"
    for r in rows: stdout.write r.join(table), "\n"
  else:                                 # Single row format for data reduction
    for j, con in labs:
      if nums[j].len > 0:               # Numeric
        if doSort: nums[j].sort
        let bs = nums[j].filter(doSort, min, max).basicStats
        for i, ex in stats:
          if i > 0: stdout.write join
          stdout.write ex.toStr(con, bs, nums[j])
      else: stdout.write con            # Non-Numeric
    stdout.write "\n"

when isMainModule:import cligen;include cligen/mergeCfgEnv;dispatch cstats,help={
  "help"       : "print cligen-erated help",    # narrower than
  "help-syntax": "prepend, plurals..",          #..the defaults
  "delim"      : "inp delims; Repeats=>fold",
  "table"     :"""labels -> header of a
`table`-separated table""",
  "hsep"       : "header sep|strip if=strip",
  "join"       : "intern st-delim for 1-row",
  "pm"         : "plus|minus string",
  "unity"      : "near unity format",
  "sci"        : "scientific format",
  "nd"         : "n)um sig d)igits of sigma",
  "exp"        : "pow10 range for 'unity'",
  "min"        : "use `min`-most numbers",
  "max"        : "use `max`-most numbers"}, short={"max": 'M'}
