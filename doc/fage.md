This program will be unneeded if coreutils `stat` ever grows an option to make
%[WXYZ] emit full precision and/or Bash/Dash grow floating point arithmetic.
(I would not hold your breath about either.)

```
Usage:
  fage [optional-params] [paths: string...]
Print max resolution age (`fileTime(Ref|self,rT) - fileTime(path,fT)`) for
paths.  "now" =~ program start-up.  Examples:
  `fage x y`           v-age of *x* & *y* relative to "now"
  `fage -fb x`         b-age of *x* relative to "now"
  `fage -Rlog logDir`  v-age of *log* rel.to its *logDir*
  `fage -srm -fb x y`  **mtime - btime** for both *x* & *y*
  `fage -ra -R/ ''`    Like `stat -c%X /`, but high-res
Last works since missing files are given time stamps of 0 (start of 1970).
Options:
  -h, --help                     print this cligen-erated help
  --help-syntax                  advanced: prepend,plurals,..
  -R=, --Ref=     string  ""     path to ref file
  -r=, --refTm=   char    'v'    ref file stamp [bamcv]
  -f=, --fileTm=  char    'v'    file time stamp [bamcv]
  -s, --self      bool    false  take ref time from file itself
  -v=, --verb=    int     0      0: Deltas; 1: Also paths; 2: diff-ends (ns)
```
