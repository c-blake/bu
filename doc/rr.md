Motivation
----------

This is really just `rm -rf` but able to use `cligen/dents.forPath` to
maybe access faster OS interfaces for file tree traversal on Linux.

Usage
-----
```
  rr [optional-params] [roots: string...]

Like rm -rf but a bit faster.  Does nothing if no roots specified.

  -x, --xdev    bool false block recursion across device boundaries
  -e, --eof0    bool false set eof0
```
