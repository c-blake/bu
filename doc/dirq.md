Motivation
----------
The idea is to use a directory as a work queue with `inotify` as a subscription
service to the queue.  Any process with write perms can drop a file into a
watched directory to trigger activity.

This can also be done with atomic rename, frequent stat(dir).st\_mtime, readdir,
but that is less efficient.  It can happen that a program you do not control
wants to just write & close, not rename into the directory.  `inotify` lets you
detect the union of both events simply for a more general facility.

As a very concrete example, you could direct your web browser to save new files
to "$HOME/dl" and leave a `dirq ~/dl got-dl` instance running.  The `got-dl`
script/program can recognize various kinds of files and do appropriate stuff.

"Stuff" may be `mv` \*.pdf files to "~/doc/" or starting a \*.torrent download,
making a simple browser click a gateway to auto-activity.  You could rename a
browser fetched file to take out spaces/other things that may need annoying
shell quoting.  You could (de)compress a file/otherwise re-encode it or even
move it to another `dirq`-watched directory after processing.  Queues have many
uses.  The only limit is your imagination. :)

There may be other interesting setups with other event classes.

Usage
-----
```
  dirq [optional-params] [cmdPrefix: string...]

chdir(dir) & wait for events to occur on it.  For each delivered event, run
cmdPrefix NAME where NAME is the filename (NOT full path) delivered.

Handleable events are:
  access    attrib  modify   open   closeWrite closeNoWrite
  movedFrom movedTo moveSelf create delete     deleteSelf

Default events closeWrite (any writable fd-close) | movedTo (renamed into dir)
usually signal that NAME is ready as an input file.

dirq can monitor & dispatch for many dirs at once with repeated --dir=A cmdPfx
for A --dir=B cmdPfx for A patterns; events & wait are global.

Options:
  -e=, --events= set(Event) closeWrite,movedTo inotify event types to use
  -w, --wait     bool       false              wait4(kid) until re-launch
  -d=, --dir=    string     "."                directory to watch
```

History/Cultural
----------------
Circa 2006, Linux added a `man 7 inotify` system that obsoleted an inefficient
& limited (*must* rename into) approach for this.  So, I did a C program (had to
use `syscall(__NR_inotify_add_watch, ..)` since it took glibc a while to wrap).
`dirq` is a Nim port of this C program.  (I pronounce `dirq` like "Dirk" myself,
but you can do as you like.)

Future Work
-----------
I don't use BSD these days, but KQueue and similar facilities could allow this
program to be a kind of portable command entry point for this limited subset of
functionality.  Maybe something like it already exists?  I believe kqueue file
monitoring pre-dates Linux inotify.  Similarly, a few events like `movedTo` can
be handled portably with a stat-loop, re-scanning directories upon mtime update.

Related Work
------------
`inotifywait` of [inotify-tools](https://github.com/inotify-tools/inotify-tools)
does allow this, but a "command wrapper" use concept makes working with general
filenames easier.  Specifically, `dirq` simply populates the last `argv[]` slot
with the filename received from the kernel & runs your program.  This eliminates
both quoting & parsing concerns.  With `inotifywait` you would have to format
things in a reliably parsable way which is yet another convention to fret about.

Bell Labs Plan 9 has a not dissimilar concept called "plumb"/"plumbers" but I
believe these require a bit more cooperation.
