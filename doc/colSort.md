Motivation
----------

Sometimes you have some calculation with an indeterminate order of columns that
you would like to make deterministic.  A concrete example is in the comment at
the end of [`ndup/`](https://github.com/c-blake/ndup/blob/main/sh/ndup).

That is where `colSort` comes in.  The `--skip` facility lets you skip over
an initial block of in-row header text you do not want to sort.

Usage
-----
colSort [optional-params]

Copy input->output lines, sorting columns [skip:] within each row.

  -p=, --pi=    string ""   path to input ; "" => stdin
  --po=         string ""   path to output; "" => stdout
  -i=, --iDlm=  string "\t" input delimiter; w => repeated whitespace
  -o=, --oDlm=  char   '\t' output delimiter byte
  -s=, --skip=  int    0    initial columns to NOT sort within rows
