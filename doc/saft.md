Motivation
==========
Almost all the time you want to let the system update file times, but once in a
while you would like to "wrap" a command in something instead preserving them.
This could be work-consequential (e.g. not rebuilding from source based on
changes in comments) or might relate to time-sorted file listings or any number
of other things.  Enter `saft`.

As a concrete follow-up, `saft -fA -fB -- sed -si s/,2018/,2018,2019/g --` can
add a copyright year in files A,B without causing file time-based rebuilds
(assuming no space between the ',' and the year & an existing sequence).

Usage
=====
```
  saft [optional-params] [--] `cmd` opts/args.. [--]

Runs cmd on a set of files with save & restore [amc]time of said files.
NOTE: cinode on many files causes "time storms".

Options:
  -f=, --files= strings {}    paths to files to preserve the file times of
  -a, --access  bool    false preserve atime
  -m, --modify  bool    true  preserve mtime
  -c, --cInode  bool    false preserve ctime (need CAP_SYS_TIME/root; Sets &
                              Restores clock!)
  -l, --link    bool    false save times of symLink not target if OS supports
  -v, --verb    bool    false emit various activities to stderr
```

A Big Example:
--------------
A script like this (`sudo` & group id `0` in chgrp may differ on your system):
```sh
rm -rf j; mkdir j; cd j
touch foo
ln -s foo bar; sync
echo "AccessTime ModifyTime CinodeTime PATH"
find -not -type d -printf '%As %Ts %Cs %p\n'; echo
sleep 1
saft -va -ffoo touch; sync
echo "same AM on foo in spite of touch (edits both):"
find -name foo -printf '%As %Ts %Cs %p\n'; echo
sleep 1
sudo saft -vac -ffoo touch; sync
echo "same AMC on foo in spite of touch:"
find -name foo -printf '%As %Ts %Cs %p\n'; echo
sleep 1
saft -vla -fbar -- touch -h; sync
echo "same AM on bar in spite of \`touch -h\`:"
find -name bar -printf '%As %Ts %Cs %p\n'; echo
sleep 1
saft -vla -fbar readlink >/dev/null; sync
echo "same AM on bar in spite of readlink (edits A):"
find -name bar -printf '%As %Ts %Cs %p\n'; echo
sleep 1
sudo saft -vlmc -fbar -- chgrp -h 0; sync
echo "same C on bar in spite of \`chgrp -h\`:"
find -name bar -printf '%As %Ts %Cs %p\n'
```
should produce output roughly like this (but with more current times):
```
AccessTime ModifyTime CinodeTime PATH
1671052591 1671052591 1671052591 ./foo
1671052591 1671052591 1671052591 ./bar

utimensat("foo", [1671052591.303841667, 1671052591.303841667], 0)
same AM on foo in spite of touch (edits both):
1671052591 1671052591 1671052592 ./foo

utimensat("foo", [1671052591.303841667, 1671052591.303841667], 0)
ctimeNsAt("foo", 1671052592.313970049, 0)
same AMC on foo in spite of touch:
1671052591 1671052591 1671052592 ./foo

utimensat("bar", [1671052591.304841794, 1671052591.304841794], SYMLINK_NOFOLLOW)
same AM on bar in spite of `touch -h`:
1671052591 1671052591 1671052594 ./bar

utimensat("bar", [1671052591.304841794, 1671052591.304841794], SYMLINK_NOFOLLOW)
same AM on bar in spite of readlink (edits A):
1671052591 1671052591 1671052595 ./bar

ctimeNsAt("bar", 1671052595.334556184, SYMLINK_NOFOLLOW)
same C on bar in spite of `chgrp -h`:
1671052591 1671052591 1671052595 ./bar
```

Side Note:
----------
ctime setting tricks bothers some people.  Feel free to not use it.  Others
appreciate the ability to preserve the data, e.g. in a restore from backup
situation.  Disk-to-disk copy/other "under the FS" backup strategies already
represent a fully alternate no-clock manipulation way to violate perfection of
no-time-travel ctime assumptions.

Related Work
============
`touch` has a concept of a reference file, but not "the file itself" (which yes
for AM times can be synthesized with `touch -rOrig X; cmd; touch -rX Orig`.) One
can also (probably) synthesize all the rest with the `stat` (1), `touch` (1),
and `date` (1) commands.  That requires a bunch of shell quoting hassle as well
as figuring translating various time formats across the 3 tools and when to use
`-L` & `-h` flags to avoid accidental `readlink` disturbance of symlink `atime`,
etc.  The Nim program is probably no longer and also pretty ergonomic.
