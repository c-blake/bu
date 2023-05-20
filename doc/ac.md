Motivation
==========
An "aped file tree" is a common organizational tool ("ape" meaning "copy, but be
clearly distinct!", like the monkey-see-monkey-do adage with "different monkeys"
distinction).  One example is different file name extensions as in, "a foo.o for
each foo.c".  The idea generalizes to (at least!) other areas of a file tree.
E.g., "back/.../" for each "orig/.../", "build/.../foo.o" & "build/.../foo.deps"
for each "src/.../foo.c", etc.

Sometimes you wind up renaming / re-organizing with `mkdir`, `mv`, `mmv`, etc.
While `mkdir(2)`, `rename(2)`, .. are usually cheap, remaking aped items can be
expensive.  This can make "aping re-org ops" compelling.  Distributed systems
call this replication by operation broadcast rather than by state comparison.

*Manually* aping commands in duplicate, triplicate, or more is easy to mess up /
forget.  Such are expensive mistakes by contextual assumption.  Meanwhile, many
"aper-apee" relationships are both persistent and subtle.  E.g., with a PWD of
`build/` one may want to replace `x foo.o` with `cd ../src; y foo.c` while in
`src/` one may want to replace `z foo.c` with `cd ../build; w foo.o`.  This
motivates saving translations directly in a file system.

Design
======
Together, the above ideas suggest automating aped commands with pattern rules
over "file-like" arguments saved in config files along the path to `"/"` which
is what `ac` does.[^1]

It is hard to know "file-like" (aka how to specify rules) given that commands
only see untyped strings, not all of which are file names, but can *relate* to
file names in a way you may like translated.  E.g. `ac mkdir -p -- blah; ac
mmv -n foo.\\* blah/bar.\\#1`.  The simplest solution seems to be for rule specs
to dispatch on command names, letting users build up "rule databases" like
`make`'s builtin rules.[^2]

An `ac` command syntax question is whether to accept many arguments, prepared by
a shell, or just one fully quoted arg.  With many args, we lose the ability to
translate shell-eaten strings (excepting OS-specific hack like /proc/$$/fd/0
symlinks to recover them which can still fail for pipes).  With just one arg, we
preserve that translation ability / pipeline syntax, but lose a good deal of
auto-complete.  Also, if a user defers quoting until after editing commands,
earlier completes may have auto-quoted/escaped for a different lexical setting
than being put back into either single or double quotes (e.g. a file name with a
single quote).  Further, a lone argument means we need a full shell parser to
get a command name from which to dispatch.  Many args seems the easier road.

Usage
=====
```
  ac [optional-params] CMD WITH ARGS

Aped cmdArgs runs both model command & however many apes.  Aping rules come from
1st config file going up from PWD | wd then CL.  subs are (CMD, KIND, FROM, TO)
with FROM a regex & $1.. in TO capture groups like config rules.  (See e.g.)

KIND is in: pwd,env, cmd,arg[1-5],args, argE,argF.  pwd substitution cd's to
its TO.  env applies to values of ALL envs.  Elsewise applies sub to referenced
args.  For Unix mv: argE = apply to non-final only if NOT a directory; argF =
apply to final only if final 2 args are not directories.  One cmd can have many
rules yielding many apes split by KIND == sep.

E.g. config file (for ndup/sh/vhup setup) is (in /d/vid/.ac.cfg):
  [mv mkdir rmdir mmv]        # '@' = user-chosen delimiter
  pwd="@/d/vid@/d/.v/dig.NL" # ac X yields 1 aped,2 total cmds
which enables e.g.: ac mkdir bar; ac mv foo*.mp4 bar.mp4.

  -c=, --config= string  ".ac.cfg" basename of ini file going up to root
  -s=, --subs=   strings {}        additional from-to substitution rules
  -v, --verbose  bool    false     explain what is being done
  -n, --dry-run  bool    false     explain what would be done
  -w=, --wd=     string  ""        overrides true PWD (e.g. if a symlnk)
```

Examples
========
# 1: Small
A little example is just the `.o` for `.c` of [the motivation](#motivation).
Specifically,
```sh
ac -s,=,mv,args,.c\$,.o mv foo.c bar.c
```
will run both `mv foo.c bar.c` and `mv foo.o bar.o`, a somewhat verbose form of
`mmv foo.* bar.#1` (but also more specific to *only* `.c` extensions).  You can
"double up" rules so that it does not matter if you are renaming object or
source files - either gets mirrored to the other:
```sh
ac -s,=,mv,args,.c\$,.o -s,=,mv,args,.o\$,.c mv foo.o bar.o
```
`ac` lets you record such rules in config files to not have to re-enter them.

# 2: Bigger
A bigger example is already in the doc string above that comes from the [ndup](
https://github.com/c-blake/ndup)'s `sh/vhup`.  There we have primary video files
(in `/d/vid` for the example), frame digests in `/d/.v/dig.nL` and
derived set files `/d/.v/dig.nL`.

Any re-org would ordinarily mean doing so "in triplicate" to avoid re-compute,
and re-compute can mean hours, days, or even weeks.  `ac` instead makes it easy.
Just `ac mkdir z; ac mv x y z www` and done.  This problem setting requires only
`pwd` aping since the common [nio](https://github.com/c-blake/nio) type is in
the directory name.  Were inputs large with a live FS rsync back up, 3-way might
become 6-way -- if you prefer saving on back up IO over safety.

# 3: Using more `ac` features.
This comes from `ndup`'s `sh/ndup` where Content-Defined Chunking digests are in
`/tmp/nd.rfc/digs` and derived set files are in `/tmp/nd.rfc/sets`.  Here the
`nio` `.Nx` extension is on every file separately as some may prefer.  To
support `mv` renaming existing dirs, moving files into subdirs, or renaming
files we need an rfc/.ac.cfg like:[^3]
```ini
[mkdir rmdir]   # Each cmd yields 2 aped,3 total cmds
pwd   = "@/d/rfc@/tmp/nd.rfc/digs"
sep   = "@@"
pwd   = "@/d/rfc@/tmp/nd.rfc/sets"

[mv]            # Probably also want rm if want rmdir..
pwd   = "@/d/rfc@/tmp/nd.rfc/digs"
argE = "@$@.Nq" # only add ext to Early if NOT dirs
argF = "@$@.Nq" # only add ext to Final if ^[12] NOT dirs
sep   = "@@"
pwd   = "@/d/rfc@/tmp/nd.rfc/sets"
argE = "@$@.Nq" # only add ext to Early if NOT dirs
argF = "@$@.Nq" # only add ext to Final if ^[12] NOT dirs
```

# NOTES
Both config eg.s are written as if `ac X` will run from the master / source file
tree.  You may like *also* having a `.ac.cfg` in each of the 2 aped trees, but
with rules changed to replicate commands to what are, locally, "the others".
Then it won't matter which tree you are in -- when you run `ac X`, all will be
updated.  Commands may need relative paths (eg. `ac mkdir ../blah/foo`), though.

Depending upon your level of trust, you can either always `ac -n mv foo bar` and
copy-paste or go all the way to `alias mv='ac -- mv'`.

Related
=======
mmv zmv etc.  Nothing I could find supports aped file trees as described here,
but it would be unsurprising if there are scripts floating around, esp. with a
subset of `ac` functionality.  Happy to reference that when so informed.

[^1]: This is not the only possible design.  Copy-paste from other terminals
with different PWDs is workaround, but awkward with arbitrary filenames.  Shell
completion of paths can help, but then works relative to PWD - so is unavailable
in, e.g. `for root in x y z; (cd $root; ...)` usage.

[^2]: While adding some `[include__*]` syntax to configs to share rules is easy,
my feeling is that specificity of rules to file tree location makes this not so
useful.

[^3]: Note that this is not perfectly general since `mv src -v dst` is legal,
but I consider such `mv` usage both bad style & very rare & ^[12] very simple.
