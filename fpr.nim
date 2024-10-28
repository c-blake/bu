when not declared(stderr): import std/syncio
import cligen, cligen/[mfile, osUt], std/strutils

iterator fprs(paths: (iterator(): string)):
    tuple[pages: tuple[resident, total: int], path: string, err: int] =
  var empty: tuple[resident, total: int]
  for path in paths():
    when defined(windows):
      yield (pages: empty, path: path, err: 1)
    else:
      if (let mf = mopen(path); mf != nil):
        yield (pages: mf.inCore, path: path, err: 0)
        mf.close
      else:
        yield (pages: empty, path: path, err: 1)

type Emit = enum summary, detail, errors

proc fpr(file="", delim='\n', emit={summary}, paths: seq[string]): int =
  ## File Pages Resident. Examine UNION of `paths` & optional `delim`-delimited
  ## input `file` (stdin if "-"|"" & stdin not a tty). Eg., `find -print0 | fpr
  ## -d\\0`.  Like util-linux `fincore`, but more Unix-portable & summarizing.
  var nErr, r, t, nFile: int            # Track numErr, resid, total pages
  for y in fprs(both(paths, fileStrings(file, delim))):
    nFile.inc                           # Update number of files & stats for
    r.inc    y.pages.resident           # y)ielded tuples
    t.inc    y.pages.total
    nErr.inc y.err
    if errors in emit and y.err != 0:   # Ignore errors from zero length files?
      stderr.write "fpr: error: \"", y, "\" (zero length/special file?)\n"
    if detail in emit:
      echo y.pages.resident," of ",y.pages.total," pages resident in ",y.path
  if summary in emit and nFile > 0:
    echo r," of ",t," pages ", formatFloat(r.float/t.float*100.0, ffDecimal, 2),
         "% resident in ",nFile," files ",nErr," errors"
  min(nErr, 127)                        # Exit with appropriate status

include cligen/mergeCfgEnv
dispatch fpr, help={"file" : "optional input (\"-\"|!tty=stdin)",
                    "delim": "input file delimiter (\\0->NUL)",
                    "emit" : "Stuff to emit: *summary* *detail*"}
