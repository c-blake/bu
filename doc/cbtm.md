WARNING
-------
Use at your own risk as with any tool that uses `xfs_db` | `debugfs`.  No
warranty, express or implied.

Motivation
----------

Hardware hosting filesystems can change.  It can be nice to save & restore ctime
& btime rather than always wiping file life cycle history.

There is no OS/FS-portable way to do this.  (settimeofday can do ctime, but with
system-disruptive time storms.)  This utility fills the gap for XFS/ext4
on Linux.

Basic usage for an XFS on DEV mounted at MNT
--------------------------------------------
```
cbtm save /MNT >MNT.stDat
```
This basically just saves all the statx data (which tends to compress very
well if you want).

Then, sometime later, on e.g. a brand new device:
```
cbtm filt -qr/MNT <MNT.stDat | cbtm resto >CMDS
umount /MNT
xfs_db -x DEV <CMDS >CMDS.log 2>&1
```
Here, `xfs_db` does the hard work.  NOTE: Does not yet work for `ext4`.

WARNING AGAIN
-------------
Note that until you become comfortable with this tool, you should look over
generated `CMDS` and perhaps manually run just the first few against a (backed
up!) FS.  { While `xfs_db` does have a `path` command as well as `inode` and
even has escape/quote-sensitive tokenization code, unfortunately it does not
de-escape or de-quote things before internal use.  So, one must use inode to get
pathname generality.  Well, or patch `xfsprogs`.  But `stat(1)` does report
inodes for you. }

More details
------------
```
Usage:
  cbtm {SUBCMD}  [sub-command options & parameters]
where {SUBCMD} is one of:
  help     print comprehensive or per-cmd help
  save     Save all statx metadata for all paths under roots to output.
  print    Print metadata stored in input in a human-readable format.
  filter   Remove input records if source & target differ|same [bc]time.
  restore  Generate commands to restore [cb]time input

save [optional-params] [roots: string...]
  Save all statx metadata for all paths under roots to output.
  
  Output format is back-to-back (statx, 2B-pathLen, NUL-term path) records.
  To be more selective than full recursion on roots, you can use the output of
  find -print[0] if you like (& file=/dev/stdin to avoid temp files).
    -f=, --file=   string ""            optional input ("-"|!tty=stdin)
    -d=, --delim=  char   '\n'          input file record delimiter
    -o=, --output= string "/dev/stdout" output file
    -q, --quiet    bool   false         suppress most OS error messages

print [optional-params] 
  Print metadata stored in input in a human-readable format.
    -i=, --input= string "/dev/stdin" metadata archive/backup path
    -d=, --delim= string "\t"         set delim

filter [optional-params] PCRE path patterns to *INCLUDE*
  Remove input records if source & target differ|same [bc]time.
    -i=, --input=  string     "/dev/stdin"  metadata archive/backup path
    -o=, --output= string     "/dev/stdout" output file
    -r=, --root=   string     ""            target FS root
    -q, --quiet    bool       false         do not stderr.emit mismatches
    -m=, --match=  set(Match) {}            {}=>all else: name, size,perm,
                                            owner,links,mtime,timeSame, re
    -d=, --drop=   string     ""            PCRE path pattern to EXCLUDE

restore [optional-params] 
  Generate commands to restore [cb]time input
    -i=, --input= string "/dev/stdin" metadata archive/backup path
    -k=, --kind=  FSKind xfs          xfs: gen for xfs_db -x myImage
                                      ext4: gen for debugfs -w myImage
```
