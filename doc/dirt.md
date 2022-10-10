Motivation
----------

File times on directories are funny things.  On the one hand, it can be nice
to see when you last renamed something inside or deleted an entry.  On the
other hand, you may prefer after several to many such edits, that the hierarchy
of directories "represent" what it contains and maybe only the ctime reflects
the last edit.  This latter conceptual mode is what motivates `dirt`.

Maybe a simpler way to describe it is operationally: it makes `ls -lt` show
things in the order of what is "most recently modified below", recursively.

This can be a divisive transformation.  Some will decry it as ruining the
utility of `ls -lt`.  Others will praise it as making it much more useful.
The right response varies with use case-specific, but without this tool it's
not easy to even have a choice.  Only "never useful" hardliners can truly
object to its existence.

Usage
------
```
  dirt [optional-params] [roots: string...]

Set mtimes of dirs under roots to mtime of its newest kid.

This makes directory mtimes "represent" content age at the expense of erasing
evidence of change which can be nice for time-sorted ls in some archival file
areas.

  -v, --verbose bool    false print utimes calls as they happen
  -q, --quiet   bool    false suppress most OS error messages
  -n, --dry-run bool    false only print what system calls are needed
  -p=, --prune= strings {}    prune exactly matching paths from recursion
  -x, --xdev    bool    false block recursion across device boundaries
```
