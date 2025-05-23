import std/[os, posix, parseutils]

var pid  = getpid()
var last = 0.Pid
var t    = 300  # Linux starts Process ID table @300
var cpu  = 1
var xSt: cint
if paramCount()>0 and parseInt(1.paramStr,t)!=1.paramStr.len:
  quit "Expecting integer to try to wrap PID table to", 1
if paramCount()>1 and parseInt(2.paramStr,cpu)!=2.paramStr.len:
  quit "Expecting CPU to set affinity for", 2
let tgt = t.Pid

template nextPid =
  last = pid
  pid = vfork()
  case pid      # -1 quit leaves whole program
  of -1: quit "pid2: %s " & $errno.strerror, 2
  of  0: quit 0                       # kid => die
  else : discard waitpid(pid, xSt, 0) # parent=>wait

when defined(linux):
  import cligen/osUt;setAffinity([cpu.cint]) # Alder 14X faster

while pid > tgt and last < pid: nextPid() # Get (last>=pid)
while pid < tgt: nextPid()                # 1st free past tgt
