Motivation
----------

This is a port of `rp.nim` to a Nim-written C code generator.  The point was
(mostly) to experiment with how much noisier pure C syntax is than the Nim-Nim
`rp`, in awk 1-liner-like problem settings.  Side interest was speed of machine
code generation with `tcc` and speed of execution of said fast-generated code.

Consult [doc/rp.md](https://github.com/c-blake/bu/blob/main/doc/rp.md) for more
pontificating on the idea space which would require few words if it were more
commonly used.  Personally, I think C even aided with macros is a bit too noisy
for the ergonomics to be great.

Usage
-----

```
  crp [optional-params] C stmts to run under `where`

Gen+Run prelude,fields,begin,where,stmts,epilog row processor against input.

Defined within where & every stmt are:
  s[idx] & row => C strings, i(idx) => int64, f(idx) => double.
  nf & nr (AWK-ish), rowLen=strlen(row);  idx is 0-origin.

A generated program is left at outp.c, easily copied for "utilitizing".  If you
know AWK & C, you can learn crp PRONTO.

Examples (most need data):
  seq 0 1000000 | crp -w'rowLen<2'                    # Print short rows
  crp 'printf("%s %s\n", s[1], s[0])'                 # Swap field order
  crp -b'int t=0' t+=nf -e'printf("%d\n", t)'         # Prn total field count
  crp -b'int t=0' -w'i(0)>0' 't+=i(0)' -e'printf("%d\n", t)' # Total>0
  crp 'float x=f(0)' 'printf("%g\n", (1+x)/x)'        # cache field 0 parse
  crp -d, -fa,b,c 'printf("%s %g\n",s[a],f(b)+i(c))'  # named fields

Add niceties (eg. --prelude='#include "mystuff.h"') to ~/.config/crp.

Options:
  -p=, --prelude=  string ""            C code for prelude/include section
  -b=, --begin=    string ""            C code for begin/pre-loop section
  -w=, --where=    string "1"           C code for row inclusion
  -e=, --epilog=   string ""            C code for epilog/end loop section
  -f=, --fields=   string ""            delim-sep field names (match row0)
  -g=, --genF=     string "$1"          make field names from this fmt; eg c$1
  -c=, --comp=     string ""            "" => tcc {if run: "-run"} {args}
  -r, --run        bool   true          Run at once using tcc -run .. < input
  -a=, --args=     string ""            "" => -I$HOME/s -O
  -o=, --outp=     string "/tmp/crpXXX" output executable; .c NOT REMOVED
  -i=, --input=    string "/dev/stdin"  path to read as input
  -d=, --delim=    string " \t"         inp delim chars for strtok
  -u, --uncheck    bool   false         do not check&skip header row vs fields
  -m=, --maxSplit= int    0             max split; 0 => unbounded
```
