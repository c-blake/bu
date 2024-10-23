import std/[strutils, os, hashes, sets, terminal] # % exec* hash HashSet isatty
import cligen,cligen/[osUt, mslice, parseopt3] # mkdirOpen split optionNormalize
when not declared(stderr): import std/syncio

proc toDef(fields, delim, genF: string): string =
  result.add "const rpNmFieldB {.used.} = \"" & fields & "\"\n"
  result.add "let   rpNmFields {.used.} = rpNmFieldB.toMSlice\n"
  let sep = initSep(delim)
  let row = fields.toMSlice
  var s: seq[MSlice]
  var nms: HashSet[string]
  sep.split(row, s) # No MaxCols - define every field; Could infer it from the
  for j, f in s:    #..highest referenced field with a `where` & `stmts` parse.
    let nm = optionNormalize(genF % [ $f ])   # Prevent duplicate def errors..
    if nm notin nms:                          #..and warn users about collision.
      result.add "const " & nm & " {.used.} = " & $j & "\n" #TODO strop, too?
      nms.incl nm
    else: stderr.write "rp: WARNING: ", nm, " collides with earlier field\n"

proc orD(s, default: string): string =  # little helper for accumulating params
  if s.startsWith("+"): default & s[1..^1] elif s.len > 0: s else: default

const es: seq[string] = @[]; proc jn(sq: seq[string]): string = sq.join("\n")
proc rp(prelude=es, begin=es, where="true",match="",stmts:seq[string],epilog=es,
        fields="", genF="$1", nim="nim", run=true, args="", cache="", verbose=0,
        outp="/tmp/rpXXX", src=false, input="", delim="white",
        uncheck=false, MaxCols=0, Warn=""): int =
  ## Gen+Run *prelude*,*fields*,*begin*,*where*,*stmts*,*epilog* row processor
  ## against *input*.  Defined within *where* & every *stmt* are:
  ##   *s[fieldIdx]* & *row* give `MSlice` (*$* to get a Nim *string*)
  ##   *fieldIdx.i* gives a Nim *int*, *fieldIdx.f* a Nim *float*.
  ##   *nf* & *nr* (like *AWK*);  NOTE: *fieldIdx* is **0-origin**.
  ## A generated program is left at *outp*.nim, easily copied for "utilitizing".
  ## If you know AWK & Nim, you can learn *rp* FAST.  Examples (most need data):
  ##   **seq 0 1000000|rp -w'row.len<2'**              # Print short rows
  ##   **rp 'echo s[1]," ",s[0]'**                     # Swap field order
  ##   **rp -b'var t=0' t+=nf -e'echo t'**             # Print total field count
  ##   **rp -b'var t=0' -w'0.i>0' t+=0.i -e'echo t'**  # Total >0 field0 ints
  ##   **rp 'let x=0.f' 'echo (1+x)/x'**               # cache field 0 parse
  ##   **rp -d, -fa,b,c 'echo s[a],b.f+c.i.float'**    # named fields (CSV)
  ##   **rp -mfoo echo\\ s[2]**                         # column of row matches
  ##   **rp -p'import stats' -b'var r:RunningStat' 'r.push 0.f' -e'echo r'**
  ## Add niceties (eg. `import lenientops`) to *prelude* in ~/.config/rp.
  let amatch = where == "true" and match.len > 0      # auto-match filter
  let pre    = (if amatch: prelude & @["import std/re"] else: prelude).jn
  let begin  = if amatch: "let rpRx = re\"" & match & "\"" & begin else: begin
  let stmts  = if stmts.len > 0: stmts
    else: @["discard stdout.writeBuffer(row.mem, row.len); stdout.write '\\n'"]
  let null   = when defined(windows): "NUL:" else: "/dev/null"
  let input  = if input=="/dev/stdin" and stdin.isatty: null else: input
  let fields = if fields.len == 0: fields else: toDef(fields, delim, genF)
  let check  = (if fields.len == 0: "    " elif not uncheck: """
    if nr == 0:
      if row == rpNmFields: inc nr; continue # {fields} {!uncheck}
      else: stderr.write "row0 \"",row,"\" != \"",rpNmFields,"\"\n"; quit 1
    """else:"    ")&(if amatch:"if row !=~ rpRx: inc nr; continue\n    "else:"")
  var program = """when not declared(stdout): import std/syncio
when not declared(addFloat): import std/formatFloat
import cligen/[mfile, mslice]
$1 # {pre}
when declared Regex:
  proc `=~`*(s: MSlice, p: Regex): bool = # Match Op for MSlice
    findBounds(cast[cstring](s.mem), p, 0, s.len)[0] > -1
  proc `!=~`*(s: MSlice, p: Regex): bool = not(s =~ p) # No Match Op
$2 # end of {fields}
proc main() =
  var s: seq[MSlice] # CREATE TERSE NOTATION: row/s/i/f/nr/nf
  proc i(j: int): int   {.used.} = parseInt(s[j])
  proc f(j: int): float {.used.} = parseFloat(s[j])
  var nr = 0
  let rpNmSepOb = initSep("$3") # {delim}
$4 # {begin}
  for row in mSlices("$5", eat='\0'): # {input} mmap|slices from stdio
${6}rpNmSepOb.split(row, s, $7) # {MaxCols}
    let nf {.used.} = s.len
    if $8: # {where} auto ()s?
""" % [pre, fields, delim, indent(begin.jn, 2), input, check, $MaxCols, where]
  for i, stmt in stmts:
    program.add "      " & stmt & " # {stmt" & $i & "}\n"
  if stmts.len == 0:
    program.add "      discard\n"
  program.add   "    inc nr\n"
  program.add   indent(epilog.jn, 2)
  program.add   " # {epilogue}\n\nmain()\n"
  program.add   "block:\n let o{.used.}=stdout\n let d{.used.}= $1.0\n"
  let bke  = if run: "r" else: "c"  # (b)ac(k) (e)nd; TODO cpp as well?
  let args = args.orD("-d:danger ") & " " & cache.orD("--nimcache:/tmp/rp ") &
             " " & Warn.orD("--warning[CannotOpenFile]=off ")
  let verb = "--verbosity:" & $verbose
  let digs = count(outp, 'X')       # temp file rigamarole
  let hsh  = toHex(program.hash and ((1 shl 16*digs) - 1), digs)
  let outp = if digs > 0: outp[0 ..< ^digs] & hsh else: outp
  let nim  = "$1 $2 $3 $4 -o:$5 $6" % [nim, bke, args, verb, outp, outp]
  let f = mkdirOpen(outp & ".nim", fmWrite); f.write program; f.close
  if src: stderr.write program
  execShellCmd nim

when isMainModule: include cligen/mergeCfgEnv; dispatch rp, help={
  "prelude": "Nim code for prelude/imports section",
  "begin"  : "Nim code for begin/pre-loop section",
  "where"  : "Nim code for row inclusion",
  "match"  : "`row` must match regex (IF -w=\"true\")",
  "stmts"  : "Nim stmts to run (guarded by `where`); none => echo row",
  "epilog" : "Nim code for epilog/end loop section",
  "fields" : "`delim`-sep field names (match row0)",
  "genF"   : "make field names from this fmt; eg c$1",
  "nim"    : "path to a nim compiler (>=v1.4)",
  "run"    : "Run at once using nim r .. < input",
  "args"   : "\"\": -d:danger; '+' prefix appends",
  "cache"  : "\"\": --nimcache:/tmp/rp (--incr:on?)",
  "verbose": "Nim compile verbosity level",
  "outp"   : "output executable; .nim NOT REMOVED",
  "src"    : "show generated Nim source on stderr",
  "input"  : "path to mmap|read; \"\"=stdin",
  "delim"  : "inp delim chars; Any repeats => fold",
  "uncheck": "do not check&skip header row vs fields",
  "MaxCols": "max split optimization; 0 => unbounded",
  "Warn"   : "\"\": --warning[CannotOpenFile]=off"}
