import std/[sets, os, strutils], cligen/osUt
when not declared(stdin): import std/syncio

proc doNotIn*(file="", delim='\0', term='\0', pattern="$1", invert=false,
              roots: seq[string]) =
  ## Find files under `roots` NOT matching `pattern` applied to any `file` entry.
  ## E.g.:
  ##   `(cd D1; find . -print0) | notIn D2 D3 | xargs -0 echo`
  ## echoes every entry under *D2* or *D3* not also under *D1*.  Input paths are
  ## normalized to nix empty path components (e.g. 1st & 3rd in "./foo/./bar").
  ## `find -path A -o -path B ..` can do this, but is hard for many paths.
  if "$1" notin pattern:
    raise newException(ValueError, "`pattern` must contain \"$1\" somewhere")
  var pats = initHashSet[string]()      # Build up a big HashSet[string]
  let file = if file.len == 0: stdin else: open(file)
  for pat in getDelim(file, delim):
    if (let pat = pat.normalizedPath; pat.len > 0):
      pats.incl pattern % [ pat ]
  let filter = {pcFile, pcLinkToFile, pcDir, pcLinkToDir}
  for root in roots:                    # Now walk roots listing (mis)matches
    let root = if root.endsWith("/"): root[0..^2] else: root
    try:
      for path in walkDirRec(root, filter):
        let pat = path[root.len+1..^1]
        if (invert and pat in pats) or pat notin pats:
          stdout.write path, term
    except Ce:
      erru "could not recurse into ",root,"\n"

when isMainModule:
  import cligen
  dispatch doNotIn, cmdName="notIn", short={"invert": 'v'}, help={
    "file"   : "delimited input ( `\"\"` => ``stdin`` )",
    "delim"  : "input path delimiter",
    "term"   : "output path terminator",
    "pattern": "a \\$1-containing under `roots` pattern",
    "invert" : "find files that *do* match a `file` entry"}
