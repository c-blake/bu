# Package
version     = "0.3.0"
author      = "Charles Blake"
description = "B)asic|But-For U)tility Code/Programs (Usually Nim & With Unix/POSIX/Linux Context)"
license     = "MIT/ISC"
bin         = @[
  "align",
  "cbtm",
  "dfr",
  "etr",
  "fage",
  "fsids",
  "ft",
  "jointr",
  "lncs",
  "memlat",
  "notIn",
  "okpaths",
  "ru",
  "stripe",
  "tails",
  "tattr",
  "thermctl",
  "bu/eve",
  "bu/colSort",
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
