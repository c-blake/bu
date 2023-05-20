import std/[os, osproc, re, strutils, strtabs, parsecfg, streams, strformat],
       std/private/ospaths2     # parentDirs
type
  AcKind* = enum acCmd="cmd", acArg1="arg1", acArg2="arg2", acArg3="arg3",
    acArg4="arg4", acArg5="arg5", acArgs="args", acArgE="argE", acArgF="argF",
    acPWD="pwd", acEnv="env", acSep="sep" ## Kinds of Substitutions
  ApeRule* = (AcKind, Regex, string)      ## Substitution Rule

var pwd = getCurrentDir()       # For both `findUp` & `acPWD` substitution

proc wholeEnv(): StringTableRef =
  result = newStringTable()
  for (k, v) in envPairs(): result[k] = v
let envs = wholeEnv()           # Initial environment

proc mkNoD(cmd: seq[string], rules: seq[ApeRule]): seq[bool] =
  for (kind, _, _) in rules:    # Could dirExists(wd&cmd[i]) in rule eval which
    if kind in {acArgs,acArgE}: #.. IS more autonomous BUT using model lessens
      result.setLen cmd.len     #.. rule order dependence, ie. pwd before argE.
      for i in 1 ..< cmd.len: result[i] = not cmd[i].dirExists
      break

proc apedCmds*(verbose=false, dryRun=false, rules: seq[ApeRule],
               args: seq[string]): int = ## `bu/doc/ac.md` has usage details.
  var opts = {poUsePath}; if verbose: opts.incl poEchoCmd
  var cmd  = args               # Aped command being built
  var eP   = envs               # Environ Passed to command
  var wd   = pwd                # workingDir used for startProcess
  var noD  = mkNoD(cmd, rules)  # .dirExists from PRE-exec(model command)
  for i, (kind, frm, to) in rules:
    case kind
    of {acCmd .. acArg5}: cmd[kind.int] = cmd[kind.int].replacef(frm, to)
    of acArgs: (for i in 1 ..< cmd.len: cmd[i] = cmd[i].replacef(frm, to))
    of acArgE: (for i in 1 ..< cmd.len - 1:
                  if noD[i]: cmd[i] = cmd[i].replacef(frm, to))
    of acArgF: (if noD[^2] and noD[^1]: cmd[^1] = cmd[^1].replacef(frm, to))
    of acPWD:
      wd = wd.replacef(frm, to)
      if dryRun or verbose: stderr.write &"cd {wd}\n"
    of acEnv:
      var n = eP; for (k, v) in eP.pairs: n[k] = v.replacef(frm, to); eP = n
    of acSep: discard           # Maybe many subst sets giving mult. aped cmds
    if i == rules.len - 1 or kind == acSep: # Order matters; `acSep` separates
      if dryRun: (if not verbose: stderr.write cmd.join(" "), "\n") #shellQuote?
      elif(let x=startProcess(cmd[0], wd, cmd[1..^1],eP,opts).waitForExit;x!=0):
        return x                # Stop at the first failed command
      if i != rules.len - 1:    # Revert to initial states
        cmd = args; eP = envs; wd = pwd

proc fop(wd, name: string): (string, File) =  # Find & open FIRST `name`
  for dir in parentDirs(wd, inclusive=true):  #.. going up to the root.
    try   : result[0] = dir/name; result[1] = open(result[0]); return
    except: discard

proc parseRules(pf: (string, File), cmd: string): seq[ApeRule] =
  result.add (acSep, "".re, "") # Early so that model command is always run
  if pf[1].isNil: return
  var f = newFileStream(pf[1])
  var p: CfgParser; open(p, f, pf[0])
  var doing = false
  while true:
    var e = p.next
    case e.kind
    of cfgEof: break
    of cfgSectionStart: doing = cmd in e.section.split
    of cfgKeyValuePair, cfgOption:
      if doing:
        let byte = e.value[0]
        let cols = e.value[1..^1].split(byte)
        result.add (parseEnum[AcKind](e.key), cols[0].re, cols[1])
    of cfgError: echo e.msg
  p.close

when isMainModule:
  import cligen; include cligen/mergeCfgEnv

  proc ac(config=".ac.cfg", subs: seq[string] = @[], verbose=false,
          dryRun=false, wd="", cmdArgs: seq[string]): int =
    ## Aped `cmdArgs` runs both model command & however many apes.  Aping rules
    ## come from *1st* `config` file going up from PWD | `wd` then CL.  `subs`
    ## are (*CMD*, *KIND*, *FROM*, *TO*) with *FROM* a regex & *$1*.. in *TO*
    ## capture groups like `config` rules.  (See e.g.)
    ##
    ## *KIND* is in: `pwd`,`env`, `cmd`,`arg[1-5]`,`args`, `argE`,`argF`.  `pwd`
    ## substitution cd's to its *TO*.  `env` applies to *values* of *ALL* envs.
    ## Elsewise applies sub to referenced args.  For Unix `mv`: `argE` = apply
    ## to non-final only if *NOT* a directory; `argF` = apply to final only if
    ## final 2 args are not directories.  One cmd can have many rules yielding
    ## many apes split by *KIND* == `sep`.
    ##
    ## E.g. config file (for `ndup/sh/vhup` setup) is (in `/d/vid/.ac.cfg`):
    ##   [mv mkdir rmdir mmv]        # '@' = user-chosen delimiter
    ##   pwd="@/d/vid@/d/.v/dig.NL"  # `ac X` yields 1 aped,2 total cmds
    ## which enables e.g.: `ac mkdir bar; ac mv foo\*.mp4 bar.mp4`.
    if cmdArgs.len < 1:
      raise newException(HelpError, "No command given\n\nFull ${HELP}")
    if subs.len mod 4 != 0:
      raise newException(HelpError, "`subs` must be 4-tuples\n\nFull ${HELP}")
    if wd.len > 0:                      # Only override if *same* dir
      if wd.getFileInfo.id == pwd.getFileInfo.id: pwd = wd
      else: stderr.write &"warning: `{wd}` not same (dev,inode) as `{pwd}`\n"
    var rules = parseRules(fop(pwd, config), cmdArgs[0])
    for i in countup(0, subs.len-1, 4): # Add CL subs on top of above cf subs
      if subs[i+0] == cmdArgs[0]:       # Filter relevant rules for this launch
        rules.add (parseEnum[AcKind](subs[i+1]), subs[i+2].re, subs[i+3])
    apedCmds verbose, dryRun, rules, cmdArgs

  dispatch ac, short={"dryRun": 'n'}, help={"cmdArgs": "CMD WITH ARGS",
    "config" : "*basename* of ini file going up to root",
    "subs"   : "additional from-to substitution rules",
    "verbose": "explain what is being done",
    "dry-run": "explain what would be done",
    "wd"     : "overrides true PWD (e.g. if a symlnk)"}
