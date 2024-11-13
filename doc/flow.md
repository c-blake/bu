## Motivation

This is a row-optimizer "columnizer" program that can reduce output terminal
scrolling by several dozen times.  (E.g., 40..80 per row for 1 byte columns.)

## Example With 28X Improvement

```sh
$ seq 1 84|flow     # Run on an 80-column terminal
1 4 7 10 13 16 19 22 25 28 31 34 37 40 43 46 49 52 55 58 61 64 67 70 73 76 79 82
2 5 8 11 14 17 20 23 26 29 32 35 38 41 44 47 50 53 56 59 62 65 68 71 74 77 80 83
3 6 9 12 15 18 21 24 27 30 33 36 39 42 45 48 51 54 57 60 63 66 69 72 75 78 81 84
```

3 rows instead of 84.  84/3 = 28.0.

## Usage
```
  flow [optional-params] 

Read maybe utf8 & colored lines from input & then flow them into shortest height
table of top-to-bottom, left-to-right columns & write to output.

Options:
  -i=, --input=  string ""    use this input file; ""=>stdin
  -o=, --output= string ""    use this output file; ""=>stdout
  -p=, --pfx=    string ""    pre-line prefix (e.g. indent)
  -w=, --width=  int    0     rendered width; 0: auto; <0: auto+THAT
  -g=, --gap=    int    1     max inter-column gap; <0: 1-column
  -b, --byLen    bool   false sort by printed-length of row
  -m=, --maxPad= int    99    max per-column padding
```
## Related Work

GNU/BSD `column` does something similar but does not support a concept of
printed/rendered length (i.e. utf8/ANSI SGR color escape sequences).
