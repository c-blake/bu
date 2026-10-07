when not declared stdin: import std/syncio
import std/[os, strutils] # Below needs path="$lib/.." in a .nims/.nim.cfg/etc.
import compiler/[lexer, llstream, idents, options, pathutils, nimlexbase]

type Tk = object
  typ: TokType
  line, col, endLine, endCol, indent: int
  name: string

const 
  strs   = {tkStrLit, tkRStrLit, tkTripleStrLit, tkGStrLit, tkGTripleStrLit}
  opens  = {tkParLe, tkBracketLe, tkCurlyLe, tkParDotLe, tkBracketDotLe,
            tkCurlyDotLe, tkBracketLeColon}
  closes = {tkParRi, tkBracketRi, tkCurlyRi, tkParDotRi, tkBracketDotRi,
            tkCurlyDotRi}

proc lex(nm, src: string): seq[Tk] =
  var L: Lexer
  var t: Token
  let cache = newIdentCache()
  let conf = newConfigRef()
  L.openLexer nm.AbsoluteFile, src.llStreamOpen, cache, conf
  while true:
    L.rawGetTok t
    if t.tokType == tkEof: break
    result.add Tk(typ: t.tokType, line: t.line,col:t.col, endLine: L.lineNumber,
                  endCol: L.getColNumber(L.bufpos), indent: t.indent,
                  name: (if t.tokType == tkSymbol: t.ident.s else: ""))
  L.closeLexer

proc norm(nm, src: string): seq[string] = # Returns 1 string/counted line with..
  let ts = nm.lex(src)                    #..No comments & emptied string lits.
  var starts = @[0]             # Byte offset of each line start
  for i, c in src:
    if c == '\n' or (c == '\r' and (i + 1 >= src.len or src[i + 1] != '\n')):
      starts.add i + 1
  var i, lineIndent, pEndLine, pEndCol = 0
  while i < ts.len:
    let t = ts[i]
    if t.indent >= 0: lineIndent = t.indent
    if t.typ == tkWhen and i + 1 < ts.len and ts[i + 1].name == "isMainModule":
      var depth = 0             # Skip stmt; Indent ignored inside []s => ..
      var j = i + 1             #..lines like `2,3,4]` @col0 don't stop early.
      while j < ts.len:
        let u = ts[j]
        if depth == 0 and u.indent >= 0 and u.indent <= lineIndent:
          if u.typ in {tkElse, tkElif} and u.indent == lineIndent: discard
          else: break
        if   u.typ in opens: inc depth
        elif u.typ in closes and depth > 0: dec depth
        inc j
      i = j
      continue
    inc i
    if t.typ == tkComment: continue
    let s = src[starts[t.line - 1] + t.col ..< starts[t.endLine - 1] + t.endCol]
    let txt = if t.typ in strs: s[0 ..< s.find('"')] & "\"\"" else: s
    if t.line > pEndLine: result.add ' '.repeat(t.col) & txt  # new counted line
    else: result[^1].add (if t.col > pEndCol: " " else: "") & txt
    pEndLine = t.endLine; pEndCol = t.endCol

proc nLoc(showSrc=false, files: seq[string]) =
  ## Count "normalized" Nim code lines: not blank, not any comment (#, ##, #[
  ## ]#, ##[ ]#, nested), not interiors of multi-line string literals, and not
  ## `when isMainModule...` statements (or their elif/else chains).  Since it
  ## uses Nim compiler as a lib, string/char/raw/triple-quote/nested-comment
  ## lexing matches the compiler exactly.
  var total = 0
  for f in (if files.len == 0: @[""] else: files):
    let si = f.len == 0 # This was always a better idea than legal filename "-"
    let n = norm((if si:"stdin" else:f), (if si:stdin.readAll else:f.readFile))
    if showSrc: (for l in n: echo l)
    else: echo n.len, '\t', f
    total += n.len
  if files.len > 1: echo total, "\ttotal"

when isMainModule: import cligen;include cligen/mergeCfgEnv;dispatch nLoc,help={
  "files"  : "files to measure; Empty string arg => stdin",
  "showSrc": "emit normalized source, not line count"}
