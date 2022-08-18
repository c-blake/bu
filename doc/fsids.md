Usage:
```
  fsids [optional-params] [roots: string...]

Print a histogram of uids and/or gids used by a file tree

  -k=, --kind=    IdKind both  kind of ids to report user, group, both
  -o=, --order=   Order  id    sort order: up by id or down by count
  -r=, --recurse= int    0     recursion limit for dirs in roots; 0=unbounded
  -f, --follow    bool   false follow symbolic links to dirs in recursion
  -x, --xdev      bool   false block recursion from crossing devices
  -e, --eof0      bool   false set eof0
```

This produces a very simple filesystem id histogram.  E.g., you might run `pwck`
and get a report about misconfigured users and then have the question: should
these users just be garbage collected?  Or you might otherwise be interested in
diversity of file ownership under various sub-trees.

For example,
```
fsids -r0 /etc
```
might produce

```
#Uid    Nentry  Name
0       1845    root
23      8       www
70      5       postgres
102     2       openvpn
250     77      portage
439     4       ldap
13615   3       MISSING
#Gid    Nentry  Name
0       1833    root
7       8       lp
8       3       mem
23      8       www
70      5       postgres
110     5       fcron
250     91      portage
391     1       unbound
439     4       ldap
```
which indicates there are 3 files with archaic/obsolete UIDs (labeled
"MISSING" here).
