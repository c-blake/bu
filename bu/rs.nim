import std/random # For weighted versions of this, see work of Yves Tillé with
type              #..keywords "unequal probability sampling without replacement"
  Reservoir*[T] = object    ## A Reservoir Random Subset Generator
    seen, size: int
    res*: seq[T]            ## Accumulated fair subset/sample
  Dup[T] = proc(x: T): T
  Del[T] = proc(x: T)

proc init*[T](r: var Reservoir[T], size=0) = r.size = size      ## Initialize
proc initReservoir*[T](size=0): Reservoir[T] = result.init size ## Factory

proc add*[T](r: var Reservoir[T], item: T, dup: Dup[T]=nil, del: Del[T]=nil) =
  ## Add an item to reservoir `r`
  inc r.seen
  template nix(j: int) = (if not del.isNil: del r.res[j])
  template set(j: int, it: T) =
    if not dup.isNil: r.res[j] = dup it
    else: r.res[j] = it
  if r.size > 0:                        # Subset mode (No Replacement)
    if r.res.len < r.size:              #   Just populating reservoir
      r.res.setLen r.res.len + 1        # `setLenUninit` needs {.nodestroy.}=>..
      set r.res.len - 1, item           #..need `=dup`=>No Faster for T=string.
    else:                               #   Random replacement in reservoir
      if (let j = rand(0..<r.seen); j < r.size):
        nix j; set j, item
  elif r.size < 0:                      # Sample mode (Replacement)
    if r.seen == 1:                     #   First time: fill with item
      r.res.setLen -r.size
      for j in 0 ..< -r.size: set(j, item)
    else:
      for j in 0 ..< -r.size:           #   For each slot independently:
        if rand(0..<r.seen) == 0:       #     replace w/P(U < 1/seen) = 1/seen
          nix j; set j, item

when isMainModule:      # Instantiate above generics as a simple CLI utility
  import cligen, cligen/[mfile, mslice, osUt], std/[os, syncio]
  proc rs(input="", flush=false, prefixNs: seq[string]) =
    ## Write ranSubsets|Samples of rows of `input`->prefix^`ns`; O(`Σns`) space.
    ## If `n>0` do random subsets else sample with replacement.  E.g.:
    ##   ``seq 1 100 | rs 10 .-5`` or
    ##   ``wkOn fifo1 & wkOn fifo2 & seq 1 1000|rs -f fifo1.10 fifo2.-20``
    var rs: seq[Reservoir[MSlice]]; var os: seq[File]; var mf: MFile; var e: int
    for pn in prefixNs:
      var (dir, name, ext) = pn.splitPathName(shortestExt=true)
      if ext.len > 0: ext = ext[1..^1]
      var n = parseInt(ext.toMSlice, e)
      if (e==ext.len and ext.len!=0) and dir.len==0 and n!=0: # integral `ext`
        rs.add initReservoir[MSlice](n)
        let p = dir/name; os.add if name.len>0: open(p, fmWrite) else: stdout
      else:
        n = parseInt(name.toMSlice, e)
        if e != name.len or name.len == 0 or dir.len != 0:
          raise newException(HelpError,"Non-integral! Full ${HELP}")
        rs.add initReservoir[MSlice](n); os.add stdout
    for line in mSlices(input, mf=mf):
      proc dup(x: MSlice): MSlice =     # Program does not know until here..
        if mf.mem.isNil:                #..if read-only memory map succeeded.
          result = MSlice(mem: alloc x.len, len: x.len)
          copyMem result.mem, x.mem, x.len  # Need a copy only if it failed.
        else: result = x
      proc del(x: MSlice) = (if mf.mem.isNil: dealloc x.mem else: discard)
      for r in mitems rs: r.add line, dup, del  # PROCESS INPUT
    var n = rs.len
    while n > 0:        # Looping gives round-robin work to ||readers of os
      for j, r in mpairs rs:
        if r.res.len > 0:
          os[j].urite r.res[^1]; os[j].urite '\n'
          r.res.setLen r.res.len - 1
          if flush: flushFile os[j]
          if r.res.len == 0: dec n
  dispatch rs, help={"prefixNs": "[pfx.][-]`n`.. output paths; NoPfx=stdout",
    "input": "\"\" => stdin", "flush": "write to outs immediately"}
