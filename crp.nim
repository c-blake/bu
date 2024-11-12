import std/[strutils, os, hashes, sets, terminal] # % exec* hash HashSet isatty
import cligen,cligen/[osUt, mslice, parseopt3] # mkdirOpen split optionNormalize
when not declared(stderr): import std/syncio

proc toDef(fields, delim, genF: string): string =
  result.add "char const * const rpNmFields = \"" & fields & "\";\n"
  let sep = initSep(delim)
  let row = fields.toMSlice
  var s: seq[MSlice]
  var nms: HashSet[string]
  sep.split(row, s) # No MaxCols - define every field; Could infer it from the
  for j, f in s:    #..highest referenced field with a `where` & `stmts` parse.
    let nm = optionNormalize(genF % [ $f ])   # Prevent duplicate def errors..
    if nm notin nms:                          #..and warn users about collision.
      result.add "int const " & nm & " = " & $j & ";\n"
      nms.incl nm
    else:
      stderr.write "crp: WARNING: ", nm, " collides with earlier field\n"

const es: seq[string] = @[]; proc jn(sq: seq[string]): string = sq.join("\n")
proc crp(prelude=es, begin=es, `var`=es, match="", where="1", stmts:seq[string],
    epilog=es, fields="", genF="$1", comp="", run=true, args="",
    outp="/tmp/crpXXX", input="", delim=" \t", uncheck=false, MaxCols=0): int =
  let amatch = match.len > 0            # auto-match filter
  let pre    = (if amatch: prelude & @["#include <regex.h>"] else: prelude).jn
  let begin1 = if amatch: "regex_t rpRx; regmatch_t rpRm[128];\nregcomp(&rpRx, \"" & match & "\", REG_EXTENDED)" & begin else: begin
  var vars = es; (for v in `var`: vars.add "double " & v & ";")
  let begin  = vars & begin1
  let stmts  = if stmts.len > 0: stmts
    else: @["fwrite(row, rowLen, 1, stdout); fputc('\\n', stdout)"]
  let null   = when defined(windows): "NUL:" else: "/dev/null"
  let input  = if input.len==0 and stdin.isatty: null else: input
  let inIni  = if input.len > 0: """fopen("$1", "r"); // {input} from stdio
  if (!rpNmFile) {
    fprintf(stderr, "cannot open \"$1\"\n");
    exit(2);
  }""" % [input] else: " stdin;"
  let fields = if fields.len == 0: fields else: toDef(fields, delim, genF)
  let check  = (if fields.len == 0: "    " elif not uncheck: """
    if (nr == 0) {
      if (strcmp(row, rpNmFields) == 0) {
        nr++; continue; // {fields} {!uncheck}
      } else {
        fprintf(stderr, "row0 \"%s\" != \"%s\"\n", row, rpNmFields); exit(1);
      }
    }
    """else: "    ")&(if amatch:"if (regexec(&rpRx,row,128,rpRm,0)!=0) {nr++; continue;}\n    "else:"")
  var program = """#include <stdio.h>
#include <string.h>
#include <stdlib.h>
ssize_t write(int, char const*, size_t);
void _exit(int);
$1 // {prelude}

// Putting below in Ahead-Of-Time optimized .so can be ~2X lower overhead.
char **rpNmSplit(char **toks, size_t *nAlloc,
                 char *str, const char *dlm, long maxSplit, size_t *nSeen) {
  size_t n = 0; /* num used (including NULL term) */
  char  *p;
  if (!toks) {  /* Number of columns should rapidly achieve a steady-state. */
    *nAlloc = 8;
    toks = (char **)malloc(*nAlloc * sizeof *toks);
  }
  if (maxSplit < 0) {
    if ((n=2) > *nAlloc && !(toks=realloc(toks, (*nAlloc=n) * sizeof*toks))) {
      write(2, "out of memory\n", 14);
      _exit(3); /* gen-time maxSplit<0 *could* skip this or rpNmSplit(), but..*/
    }           /*..instead we keep it so user-code referencing s[0] is ok. */
    toks[0] = str; toks[1] = NULL; *nSeen = 1;
    return toks;
  }
  for (toks[n]=strtok_r(str, dlm, &p); toks[n] && (maxSplit==0 || n < maxSplit);
       toks[++n]=strtok_r(0, dlm, &p))
    if (n+2 > *nAlloc && !(toks=realloc(toks, (*nAlloc *= 2) * sizeof*toks))) {
      write(2, "out of memory\n", 14);
      _exit(3);
    }
  *nSeen = n;
  return toks;
}

// {fields}
$2
int main(int ac, char **av) {
  char  **s = NULL, *row = NULL; // CREATE TERSE NOTATION: row/s/i/f/nr/nf
  ssize_t rowLen;
  size_t  rpNmAlloc = 0, nr = 0, nf = 0;
  #define i(j) atoi(s[j])
  #define f(j) atof(s[j])
$4; // {begin}
  FILE *rpNmFile = $5
  while ((rowLen = getline(&row, &rpNmAlloc, rpNmFile)) > 0) {
    row[--rowLen] = '\0';       // chop newline
${6}s = rpNmSplit(s, &rpNmAlloc, row, "$3", $7, &nf); // {delim,maxSplit}
    if ($8) { // {where} auto ()s?
""" % [pre, fields, delim, indent(begin.jn, 2), inIni, check, $MaxCols, where]
  for i, stmt in stmts:
    program.add "      " & stmt & "; // {stmt" & $i & "}\n"
  program.add "    }\n    nr++;\n  }\n"
  program.add indent(epilog.jn, 2)
  program.add "; // {epilogue}\n}\n"
  let mode = if run: "-run" else: ""
  let args = if args.len > 0: args else: "-I$HOME/s -O"
  let digs = count(outp, 'X')
  let hsh  = toHex(program.hash and ((1 shl 16*digs) - 1), digs)
  let outp = if digs > 0: outp[0 ..< ^digs] & hsh else: outp
  let comp = if comp.len > 0: comp else: "tcc $1 $2 -o$3 $4" % [
                                         mode, args, outp, outp & ".c"]
  let f = mkdirOpen(outp & ".c", fmWrite)
  f.write program
  f.close
  let inp = if input.len > 0: " < " & input else: ""
  execShellCmd(comp & (if run: inp else: ""))

when isMainModule: include cligen/mergeCfgEnv; dispatch crp, help={
  "prelude": "C code for prelude/include section",
  "begin"  : "C code for begin/pre-loop section",
  "var"    : "preface begin with `double` var decl",
  "match"  : "row must match this regex",
  "where"  : "C code for row inclusion",
  "stmts"  : "C stmts to run (guarded by `where`); none => echo row",
  "epilog" : "C code for epilog/end loop section",
  "fields" : "`delim`-sep field names (match row0)",
  "genF"   : "make Field names from this Fmt;Eg c_$1",
  "comp"   : "\"\" => tcc {if run: \"-run\"} {args}",
  "run"    : "Run at once using tcc -run .. < input",
  "args"   : "\"\" => -I$HOME/s -O",
  "outp"   : "output executable; .c NOT REMOVED",
  "input"  : "path to read as input; \"\"=stdin",
  "delim"  : "inp delim chars for strtok",
  "uncheck": "do not check&skip header row vs fields",
  "MaxCols": "max split optimization; 0 => unbounded"}, doc="""
Gen+Run *prelude*,*fields*,*begin*,*where*,*stmts*,*epilog* row processor
against *input*.  Defined within *where* & every *stmt* are:
  *s[idx]* & *row* => C strings, *i(idx)* => int64, *f(idx)* => double.
  *nf* & *nr* (*AWK*-ish), *rowLen*=strlen(row);  *idx* is **0-origin**.
A generated program is left at *outp*.c, easily copied for "utilitizing".
If you know *AWK* & *C*, you can learn *crp* FAST.  Examples (most need data):
  **seq 0 1000000|crp -w'rowLen<2'**                # Print short rows
  **crp 'printf("%s %s\\n", s[1], s[0])'**           # Swap field order
  **crp -vt=0 t+=nf -e'printf("%g\\n", t)'**         # Prn total field count
  **crp -vt=0 -w'i(0)>0' 't+=i(0)' -e'printf("%g\\n", t)'** # Total>0
  **crp 'float x=f(0)' 'printf("%g\\n", (1+x)/x)'**  # cache field 0 parse
  **crp -d, -fa,b,c 'printf("%s %g\\n",s[a],f(b)+i(c))'**   # named fields
  **crp -mfoo 'printf("%s\\n", s[2])'**              # column if row matches
Add niceties (eg. prelude="#include <mystuff.h>") to ~/.config/crp."""
