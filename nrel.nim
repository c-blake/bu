when not declared(stderr): import std/syncio
import std/[os, osproc, strutils, parseutils, tempfiles, json, tables, strscans]

proc nimblePath(): string =             # nicked from nimp.nim
  for k, path in ".".walkDir(true):
    if k == pcFile and path.endsWith(".nimble"): return path

type
  VSlot = enum Major, minor, patch
  Stage = enum nimble, commit, tag, push, release

proc s2num(s: string): int =
  if parseInt(s, result) == 0 or result < 0:
    stderr.write "not a positive number: \"", s, "\"; Using zero\n"

proc newVsn(curV: string, bump=patch): string =
  for line in curV.split('\n'):
    if line.len > 0 and line[0] in {'0'..'9'}:
      if (let v = line.strip.split('.'); v.len == 3): # Compute requested bump
        case bump
        of patch: return "$1.$2.$3" % [v[0], v[1], $(s2num(v[2]) + 1)]
        of minor: return "$1.$2.$3" % [v[0], $(s2num(v[1]) + 1), "0" ]
        of Major: return "$1.$2.$3" % [$(s2num(v[0]) + 1), "0" , "0" ]
      else:
        raise newException(ValueError, "non-tripartite version: " & line.repr)
  raise newException(ValueError, "No output line looking like a version")

proc latestVersion(repoURI: string): string =   # Get tags for some git repo
  let cmd = "git ls-remote --tags \"" & repoURI & "\""
  let (outp, xs) = cmd.execCmdEx; if xs != 0: quit "could not run: " & cmd, 5
  var vmax: (int, int, int)                     # Max version seen
  for row in outp.splitLines:
    var row = row
    if row.endsWith("^{}"): row.setLen row.len - 3
    if (let ix = row.find("refs/tags/"); ix != -1):
      row = row[ix+10 .. ^1]
      if row.startsWith("v"): row = row[1 .. ^1]
      var res: (int, int, int)                  # Build a version; missing => 0
      if row.scanf("$i.$i.$i", res[0], res[1], res[2]) or
         row.scanf("$i.$i", res[0], res[1]) or  # Also allow "1.2"
         row.scanf("$i", res[0]):               # and even "17"
        if res > vmax: vmax = res; result = row

proc getNm2URI(): Table[string, string] =       # pkgNm -> repo URI
  proc n(x: string): string = x.toLower.multiReplace(("_", ""))
  const u = "raw.githubusercontent.com/nim-lang/packages/master/packages.json"
  const cmd = "curl -s https://" & u            # Cache this for "a while"?
  let (pks, xs) = execCmdEx(cmd); if xs != 0: quit "could not run: " & cmd, 6
  var alt: Table[string, string]
  for p in parseJson(pks):
    try: result[($p["name"]).n[1..^2]] = ($p["url"])[1..^2]
    except CatchableError:                      # [1..^2] slice kills '"'s
      try: alt[($p["name"]).n[1..^2]] = ($p["alias"]).n[1..^2]
      except CatchableError: stderr.write "problem with: ", p, "\n"
  for k, v in alt: result[k] = result[v][0..^1] # COPY apply aliases

proc depsUp(reqs: seq[string]): seq[(string, string)] =
  let uris = getNm2URI()
  for req in reqs:
    let cols = req.split()
    if cols[0] != "nim" and cols[1] == ">=":    # Only edit non-Nim >= rules
      let latest = latestVersion(uris[cols[0]])
      if cols[2] != latest: result.add (req, cols[0] & " >= " & latest)

proc apply(s: string, rs: seq[(string, string)]): string =
  result = s
  for pair in rs: result = result.replace(pair[0], pair[1])

proc nimbleUp(vsn: string, bump=patch, upDeps=false, dryRun=false): string =
  let nbPath = nimblePath()
  let (_, pknm, _) = nbPath.splitFile
  if nbPath.len == 0: quit "could not find nimble file", 2
  let nb = if nbPath.len > 0: nbPath.readFile else: ""   # Generality=>add echos
  let (dvF, dvPath) = createTempFile("dumpVsn", ".nims") #..to .nimble & nim e.
  dvF.write """template after(action: untyped, body: untyped): untyped = discard
template before(action: untyped, body: untyped): untyped = discard
template task(name:untyped; description:string; body:untyped): untyped = discard
proc getPkgDir(): string = getCurrentDir()
proc thisDir(): string = getPkgDir()
import strutils""", "\n", nb, """echo version
for d in requiresData: (for dd in d.split(","): echo dd.strip)
"""; dvF.close
  let (outp, xs) = execCmdEx("nim e " & dvPath)
  let outps = outp.splitLines
  let curV = outps[0]
  if xs != 0: quit "could not find nim or run nim e " & dvPath, 3
  try: removeFile dvPath
  except CatchableError: quit "could not clean-up " & dvPath, 4
  result = if vsn.len == 0: curV.newVsn(bump) else: vsn
  echo "Edit ", pknm, ".nimble version from ", curV.strip, " to ", result
  var rs: seq[(string, string)] = if upDeps: outps[1..^1].depsUp else: @[]
  for r in rs: echo "replace: ", r[0], " with: ", r[1]
  if not dryRun: writeFile nbPath,
    nb.replace("\"" & curV.strip & "\"", "\"" & result & "\"").apply(rs)

proc run(cmd, failMsg: string; failCode: int, dryRun=false) =
  if dryRun: echo cmd
  elif execShellCmd(cmd) != 0: quit failMsg, failCode

proc nrel(vsn="", bump=patch, upDeps=false, msg="", stage=push, title="",
          rNotes="", dryRun=false) =
  ## Bump version in `.nimble`, commit, tag & push using just `nim`, this prog
  ## & `git`.  Final optional stage uses github-cli's ``gh release`` creation.
  if stage == release and (title.len == 0 or rNotes.len == 0):
    quit "Need non-empty `title` and `rNotes` for release stage", 1
  let msg = if msg.len != 0: msg else: "Bump versions pre-release"
  let newV = nimbleUp(vsn, bump, upDeps, dryRun)
  if stage == nimble: quit()
  run "git commit -m \'" & msg & "\' " & nimblePath(),
      "Error committing version bump",5,dryRun
  if stage == commit: quit()
  run "git tag " & newV, "Error adding " & newV & " tag", 6, dryRun
  if stage == tag: quit()
  run "git push; git push --tags", "Error pushing to main GH branch", 7, dryRun
  if stage == push: quit()
  run "gh release create \'"&newV&"\' -t '"&title&"' -F '"&rNotes&"'",
      "Error running gh release create; Manually do it on github", 8, dryRun

when isMainModule: import cligen;include cligen/mergeCfgEnv;dispatch nrel,help={
  "vsn"   : "New version; \"\": auto bump",
  "bump"  : "Version slot to bump: Major, minor, patch",
  "upDeps": "Also auto-update >= version deps in .nimble",
  "msg"   : ".nimble commit; \"\": Bump versions pre-release",
  "stage" : "nimble, commit, tag, push, release",
  "title" : "Release title",
  "rNotes": "Path to release notes markdown",
  "dryRun": "Do not act; Print what would happen"}, short={"dryRun": 'n'}
