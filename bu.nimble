# Package
version     = "0.3.1"
author      = "Charles Blake"
description = "B)asic|But-For U)tility Code/Programs (Usually Nim & With Unix/POSIX/Linux Context)"
license     = "MIT/ISC"
bin         = @[
  "dfr",        # d)isk fr)ee; `df` but more color-coded & with modern defaults
  "fsids",      # file system user & group id histogram
  "cbtm",       # Back up & restore new Linux b-time stamps (creation/birth)
  "thermctl",   # Thermal Control for before CPU makers thermally throttled
  "lncs",       # Links mapper for hard-links.
  "okpaths",    # Helper to validate PATH-like variables by probing the system
  "align",      # Align text with better ergonomics than BSD `column`
  "tails",      # Generalizes head & tail into one with all-but compliments
  "jointr",     # join trace; helper to join "unfinished ..." with conclusion
  "stripe",     # Run commands in parallel, possibly with shell elision
  "tattr",      # Text Attribute helper using cligen/humanUt machinery
  "notIn",      # Helper to manage semi-mirrored file trees
  "ft",         # file typer {i-node type, not file(1)/libmagic(3) type}
  "fage",       # file age according to various timestamps/rules
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
  "ww",         # Dynamic programming based word wrapper
  "cfold",      # Context folding (like csplit but wrap lines)
  "unfold",     # An oft neglected inverse-to-wrapping process
  "memlat",     # Memory latency benchmark
  "ru",         # Resource Usage measurement { high-res/nicer time(1) }
  "etr",        # e)stimate t)ime r)emaining using subcommands for %done
  "bu/eve",     # Extreme Value Estimator; Estimate "true" min/max from a sample
]

# Dependencies
requires "nim >= 1.6.0", "cligen >= 1.5.29"
