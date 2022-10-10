# Package
version     = "0.3.0"
author      = "Charles Blake"
description = "B)asic|But-For U)tility Code/Programs (Usually Nim & With Unix/POSIX/Linux Context)"
license     = "MIT/ISC"
bin         = @[
  "align",      # Align text with better ergonomics than BSD `column`
  "cbtm",       # Back up & restore new Linux b-time stamps (creation/birth)
  "dfr",        # d)isk fr)ee; `df` but more color-coded & with modern defaults
  "etr",        # e)stimate t)ime r)emaining using subcommands for %done
  "fage",       # file age according to various timestamps/rules
  "fsids",      # file system user & group id histogram
  "ft",         # file typer {i-node type, not file(1)/libmagic(3) type}
  "jointr",     # join trace; helper to join "unfinished ..." with conclusion
  "lncs",       # Links mapper for hard-links.
  "memlat",     # Memory latency benchmark
  "notIn",      # Helper to manage parallel file trees
  "okpaths",    # Helper to validate PATH-like variables by probing the system
  "ru",         # Resource Usage measurement { high-res/nicer time(1) }
  "stripe",     # Run commands in parallel, possibly with shell elision
  "tails",      # Generalizes head & tail into one with all-but compliments
  "tattr",      # Text Attribute helper using cligen/humanUt machinery
  "thermctl",   # Thermal Control for before CPU makers thermally throttled
  "bu/eve",     # Extreme Value Estimator; Estimate "true" min/max from a sample
  "bu/colSort", # Sort *within* the columns of rows
  "chom",       # Enforce group owner & segregated perms in file trees
  "du",         # Slight improvement on GNU du
  "rr",         # Mostly a short alias for rm -rf but also faster
  "dups",       # Fast finder of exact duplicate files
  "only",       # file(1)/libmagic tool to emit files whose types match
  "fkindc",     # file(1)/libmagic tool to histogram file types
  "dirq",       # Kind of its own system-building atom thing
  "dirt",       # Recursively set dir time stamp to oldest of members
  "newest",     # b-time supporting `find -printf|sort|tail`
  "since",      # b-time supporting `find -Xnewer`
  "cols",       # extract just some columns from a text file/stream
  "rp",         # A row processor program-generator
  "crp",        # C row processor program-generator
]

# Dependencies
requires "nim >= 1.6.0", "cligen >= 1.5.29"
