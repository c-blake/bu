when not declared(stderr): import std/syncio
import std/[os, osproc, strutils, parseutils, tempfiles]

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
  if (let v = curV.strip.split('.'); v.len == 3): # Compute requested bump
    case bump
    of patch: return "$1.$2.$3" % [v[0], v[1], $(s2num(v[2]) + 1)]
    of minor: return "$1.$2.$3" % [v[0], $(s2num(v[1]) + 1), "0" ]
    of Major: return "$1.$2.$3" % [$(s2num(v[0]) + 1), "0" , "0" ]
  else:
    raise newException(ValueError, "non-tripartite version")

proc nimbleUp(vsn: string, bump=patch): string =
  let nbPath = nimblePath()
  let (_, pknm, _) = nbPath.splitFile
  if nbPath.len == 0: quit "could not find nimble file", 2
  let nb = if nbPath.len > 0: nbPath.readFile else: ""
  let (dvF, dvPath) = createTempFile("dumpVsn", ".nims")
  dvF.write nb, "\necho version\n"      #  For full generality, add `echo`
  dvF.close                             #..to end of .nimble & then nim e
  let (curV, xs) = execCmdEx("nim e " & dvPath)
  if xs != 0: quit "could not find nim or run nim e " & dvPath, 3
  try: removeFile dvPath
  except CatchableError: quit "could not clean-up " & dvPath, 4
  result = if vsn.len == 0: curV.newVsn(bump) else: vsn
  echo "Moving ", pknm, " from version ", curV.strip, " to ", result
  let newNb = nb.replace("\"" & curV.strip & "\"", "\"" & result & "\"")
  let f = open(nbPath, fmWrite)         # Could add an optional `reqs` stage to
  f.write newNb                         #..autoupdate `requires` to each latest.
  f.close

proc nrel(vsn="", bump=patch, msg="", stage=push, title="", notes="") =
  ## Bump version in `.nimble`, commit, tag & push using just `nim`, this prog,
  ## & `git`.  Final optional stage uses github-cli release create prog.
  if stage == release and title.len == 0 or notes.len == 0:
    quit "Need non-empty `title` and `notes` for release stage", 1
  let msg = if msg.len != 0: msg else: "Bump versions pre-release"
  let newV = nimbleUp(vsn, bump)
  if stage == nimble: quit()
  if execShellCmd("git commit -am \"" & msg & "\"") != 0:
    quit "error committing version bump", 5
  if stage == commit: quit()
  if execShellCmd("git tag "&newV) != 0: quit "error adding "&newV&" tag", 6
  if stage == tag: quit()
  if execShellCmd("git push; git push --tags") != 0:
    quit "error pushing to main GH branch", 7
  if stage == push: quit()
  if execShellCmd("gh release create \"" & newV & "\" -t \""&title&"\" -F \"" &
                  notes & "\"") != 0:
    quit "Error running gh release create; Manually do it on github", 8

when isMainModule: import cligen; dispatch nrel, help={
  "vsn"  : "New version; \"\": auto bump",
  "bump" : "Version slot to bump: Major, minor, patch",
  "msg"  : ".nimble commit; \"\": Bump versions pre-release",
  "stage": "nimble, commit, tag, push, release",
  "title": "Release title",
  "notes": "Path to release notes markdown"}
