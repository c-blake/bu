# This is like `nio moments`, but has `adix` as a hard dep for histo & qs.
when not declared(addFloat): import std/formatFloat
import std/math, nio, adix/[stat, lghisto], cligen/osUt

type MomKind = enum mkN="n", mkMin="min", mkMax="max", mkSum="sum", mkAvg="avg",
                    mkSdev="sdev", mkSkew="skew", mkKurt="kurt", mkHisto="histo"

proc fmtStat(ms: MovingStat, mk: MomKind, fmt: string): string =
  case mk
  of mkN:     ms.n.float64        .formatFloat(fmt)
  of mkMin:   ms.min              .formatFloat(fmt)
  of mkMax:   ms.max              .formatFloat(fmt)
  of mkSum:   ms.sum              .formatFloat(fmt)
  of mkAvg:   ms.mean             .formatFloat(fmt)
  of mkSdev:  ms.standardDeviation.formatFloat(fmt)
  of mkSkew:  ms.skewness         .formatFloat(fmt)
  of mkKurt:  ms.kurtosis         .formatFloat(fmt)
  else: ""

proc niom(fmt=".4g", stats={mkMin, mkMax}, qs: seq[float] = @[],
          a=1e-16, b=1e20, n=8300, paths: Strings): int =
  ## Print selected statistics over all columns of all `paths`.
  let opt = if mkHisto in stats or qs.len > 0: {OrderStats} else: {}
  for path in paths:
    var inp = nOpen(path)
    var sts: seq[MovingStat[float64,uint32]]
    for c in inp.rowFmt.cols:
      sts.add initMovingStat[float64,uint32](a, b, n, opt)
    var num: float
    block fileLoop:
      while true:
        for j in 0 ..< sts.len:
          if not inp.read(num): break fileLoop
          if not num.isNaN: sts[j].push num
    for j in 0 ..< sts.len:
      outu path, ":", j
      for mk in [mkN, mkMin, mkMax, mkSum, mkAvg, mkSdev, mkSkew, mkKurt]:
        if mk in stats: outu " ", $mk, ": ", fmtStat(sts[j], mk, fmt)
      for i, q in qs: outu (if i>0: " " else: ""), sts[j].quantile(q)
      if mkHisto in stats: outu " ", $sts[j].lgHisto
      outu "\n"
    inp.close

when isMainModule:
  import cligen; dispatch niom, help={
    "paths": "[paths: 1|more paths to NIO files]",
    "fmt"  : "Nim floating point output format",
    "stats": "*n* *min* *max* *sum* *avg* *sdev* *skew* *kurt* *histo*",
    "a"    : "min absolute value histo-bin edge",
    "b"    : "max absolute value histo-bin edge",
    "n"    : "number of lg-spaced histo bins",
    "qs"   : "desired quantiles"}
