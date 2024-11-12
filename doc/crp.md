Motivation
----------

This is a port of `rp.nim` to a Nim-written C code generator.  The point was
(mostly) to experiment with how much noisier pure C syntax is than the Nim-Nim
`rp`, in awk 1-liner-like problem settings.  Side interest was speed of machine
code generation with `tcc` and speed of execution of said fast-generated code.

Consult [doc/rp.md](rp.md) for more pontificating on the idea space which would
require few words if it were more commonly used.  Personally, I think C even
aided with macros is a bit too noisy for the ergonomics to be great.

Usage
-----

```
  crp [optional-params] C stmts to run (guarded by where); none => echo row

Gen+Run prelude,fields,begin,where,stmts,epilog row processor against input.

Defined within where & every stmt are:
  s[idx] & row => C strings, i(idx) => int64, f(idx) => double.
  nf & nr (AWK-ish), rowLen=strlen(row);  idx is 0-origin.

A generated program is left at outp.c, easily copied for "utilitizing".  If you
know AWK & C, you can learn crp FAST.

Examples (most need data):
  seq 0 1000000 | crp -w'rowLen<2'              # Print short rows
  crp 'printf("%s %s\n", s[1], s[0])'           # Swap field order
  crp -vt=0 t+=nf -e'printf("%g\n", t)'         # Prn total field count
  crp -vt=0 -w'i(0)>0' 't+=i(0)' -e'printf("%g\n", t)' # Total>0
  crp 'float x=f(0)' 'printf("%g\n", (1+x)/x)'  # cache field 0 parse
  crp -d, -fa,b,c 'printf("%s %g\n",s[a],f(b)+i(c))'   # named fields
  crp -mfoo 'printf("%s\n", s[2])'              # column if row matches

Add niceties (eg. prelude="#include <mystuff.h>") to ~/.config/crp.

Options:
  -p=, --prelude= strings {}          C code for prelude/include section
  -b=, --begin=   strings {}          C code for begin/pre-loop section
  -v=, --var=     strings {}          preface begin with double var decl
  -m=, --match=   string  ""          row must match this regex
  -w=, --where=   string  1           C code for row inclusion
  -e=, --epilog=  strings {}          C code for epilog/end loop section
  -f=, --fields=  string  ""          delim-sep field names (match row0)
  -g=, --genF=    string  "$1"        make Field names from this Fmt;Eg c_$1
  -c=, --comp=    string  ""          "" => tcc {if run: "-run"} {args}
  -r, --run       bool    true        Run at once using tcc -run .. < input
  -a=, --args=    string  ""          "" => -I$HOME/s -O
  -o=, --outp=    string  /tmp/crpXXX output executable; .c NOT REMOVED
  -i=, --input=   string  ""          path to read as input; ""=stdin
  -d=, --delim=   string  " \t"       inp delim chars for strtok
  -u, --uncheck   bool    false       do not check&skip header row vs fields
  -M=, --MaxCols= int     0           max split optimization; 0 => unbounded
```
