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

proc nimbleUp(vsn: string, bump=patch, dryRun=false): string =
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
  echo "Edit ", pknm, ".nimble version from ", curV.strip, " to ", result
  if not dryRun:
    let newNb = nb.replace("\"" & curV.strip & "\"", "\"" & result & "\"")
    let f = open(nbPath, fmWrite)       # Could add an optional `reqs` stage to
    f.write newNb                       #..autoupdate `requires` to each latest.
    f.close

proc run(cmd, failMsg: string; failCode: int, dryRun=false) =
  if dryRun: echo cmd
  elif execShellCmd(cmd) != 0: quit failMsg, failCode

proc nrel(vsn="", bump=patch, msg="", stage=push, title="", rNotes="",
          dryRun=false) =
  ## Bump version in `.nimble`, commit, tag & push using just `nim`, this prog
  ## & `git`.  Final optional stage uses github-cli's ``gh release`` creation.
  if stage == release and (title.len == 0 or rNotes.len == 0):
    quit "Need non-empty `title` and `rNotes` for release stage", 1
  let msg = if msg.len != 0: msg else: "Bump versions pre-release"
  let newV = nimbleUp(vsn, bump, dryRun)
  if stage == nimble: quit()
  run "git commit -am \'" & msg & "\'", "error committing version bump",5,dryRun
  if stage == commit: quit()
  run "git tag " & newV, "error adding " & newV & " tag", 6, dryRun
  if stage == tag: quit()
  run "git push; git push --tags", "error pushing to main GH branch", 7, dryRun
  if stage == push: quit()
  run "gh release create \'"&newV&"\' -t '"&title&"' -F '"&rNotes&"'",
      "Error running gh release create; Manually do it on github", 8, dryRun

when isMainModule: import cligen; dispatch nrel, help={
  "vsn"   : "New version; \"\": auto bump",
  "bump"  : "Version slot to bump: Major, minor, patch",
  "msg"   : ".nimble commit; \"\": Bump versions pre-release",
  "stage" : "nimble, commit, tag, push, release",
  "title" : "Release title",
  "rNotes": "Path to release notes markdown",
  "dryRun": "Do not act; Print what would happen"}, short={"dryRun": 'n'}
