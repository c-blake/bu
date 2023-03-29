Motivation
----------
Programs will often dump out numbers with varying amounts of context in rows.
This might be resource usage information, like [ru](ru.md) or various results
or really a great many things.  It is very simple/natural to go from one report
to many for various parameters/input files and so on in a shell loop, but with
such data either collected or at the start of a pipeline, at other stages of
inquiry it can be nice to have summary statistics.

Usage
-----
```
  cstats [optional-params] [stats: string...]

This consumes any stdin looking like regular intercalary text with embedded
floats & prints a summary with the LAST such text & requested stats for any
varying float column. If table!="", context is joined via hsep into headers
for associated reduced numbers, with columns separated by table (eg. ',').
Available stats (ms if none given)..

  mn: mean      sd: sdev      se: stderr(mean) (i.e. sdev/n.sqrt)
  sk: skewness  kt: kurtosis  ms: mn +- se via pm exp nd unity sci params
  iq: interQuartileRange      sq: semi-interQuartileRange   n: len(nums)
  qP: General Parzen interpolated quantile P (0<=P<=1 float; 0=min; 1=max)

..print as separate rows in the table mode or else joined by join.

  -d=, --delim= string "white"                      inp delims; Repeats=>fold
  -t=, --table= string ""                           labels -> header of a
                                                    table-separated table
  --hsep=       string "strip"                      header sep|strip if=strip
  -p=, --pm=    string " +- "                       plus|minus string
  -e=, --exp=   Slice  -2..4                        pow10 range for 'unity'
  -n=, --nd=    int    2                            n)um sig d)igits of sigma
  -u=, --unity= string "$val0${pm}$err0"            near unity format
  -s=, --sci=   string "($valMan $pm $errV)$valExp" scientific format
  -j=, --join=  string ","                          intern st-delim for 1-row
  -m=, --min=   int    0                            use min-most numbers
  -M=, --max=   int    0                            use max-most numbers
```
