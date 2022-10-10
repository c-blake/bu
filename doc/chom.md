Motivation
----------

On multi-user systems and servers filesystem permissions can matter.  Often one
wants a restrictive umask (e.g. 077) for file/directory creation as a "safe
default".  Then sometimes you want to "open up" perms on some entire file
sub-tree..say to collaborate with some other user.

While you can do `chown -R` there is no "only directories" filter or handle
user-executable files differently option.  One can do wrapper scripts with
`find`, but using `chom` is more efficient for both users and the system.
One can also do fancy Zsh recursive globbing like `**(.x)`, but at least to
me the ergonomics of `chom` are better than either of these options.

Usage
-----
```
  chom [optional-params] [paths: string...]

This enforces {owner, group owner, permissions} for {dirs, non-executable other
files, and user-executable files}.  This only makes chown/chmod syscalls when
needed, both for speed & not to touch ctime unnecessarily.  It does not handle
ACLs, network FS defined access, etc.  Return zero if no calls are needed.

Options:
  -v, --verbose    bool   false print chown and chmod calls as they happen
  -q, --quiet      bool   false suppress most OS error messages
  -n, --dry-run    bool   false only print what system calls are needed
  -r=, --recurse=  int    0     max recursion depth for any dir in paths
  -c, --chase      bool   false follow symbolic links to dirs in recursion
  -x, --xdev       bool   false block recursion across device boundaries
  -o=, --owner=    string ""    owner to set; may need root; defl=self
  -g=, --group=    string ""    group owner to set; defl=primaryGid(self)
  -d=, --dirPerm=  Perm   2755  permission mask for dirs
  -f=, --filePerm= Perm   664   permission mask for files
  -e=, --execPerm= Perm   775   permission mask for u=x files
