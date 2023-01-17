Motivation
----------
The Nim package manager nimble identifies versions by the most recent git tag.
This must match in the .nimble file and the git repository.  It is pretty easy
to forget changing it one or the other when making new releases.

Usage
-----
```
  nrel [NEED,optional-params]
Bump version in .nimble, commit, tag & push using just nim, this prog, & git.
Final optional stage uses github-cli release create prog.

  -t=, --title= string NEED  Release title
  -n=, --notes= string NEED  Path to release notes markdown
  -v=, --vsn=   string ""    New version; "": auto bump
  -b=, --bump=  VSlot  patch Version slot to bump: Major, minor, patch
  -m=, --msg=   string ""    .nimble commit; "": Bump versions pre-release
  -s=, --stage= Stage  tag   nimble, commit, tag, push, release
```

Examples
--------
```sh
cd myRepo
nrel
# Now go to github and draft a release
```
or if you have `gh` installed from github-cli
```
cd myRepo
edit /tmp/RELNOTE   # add release notes
nrel -sr -t 'This is my new release title' -n /tmp/RELNOTE
```

Future Work
-----------
It would be nice to also update all dependency versions in `requires` in
the nimble file to whatever their latest versions are since this is the most
likely testing case by far.  That is a bit more work, though.

Related Work
------------
I feel just assuming & using a command-line `git` program is a simpler approach
than done in https://github.com/disruptek/bump