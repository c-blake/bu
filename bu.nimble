# Package
version     = "0.5.9"
author      = "Charles Blake"
description = "B)asic|But-For U)tility Code/Programs (Usually Nim & With Unix/POSIX/Linux Context)"
license     = "MIT/ISC"
bin         = @[
  "ft",         # file typer {i-node type, not file(1)/libmagic(3) type}
  "only",       # file(1)/libmagic tool to emit files whose types match
  "fkindc",     # file(1)/libmagic tool to histogram file types
  "notIn",      # Helper to manage semi-mirrored file trees

  "dfr",        # d)isk fr)ee; `df` with color coding & modern defaults
  "lncs",       # analyze a file tree for hard link structure
  "du",         # Slight improvement on GNU du
  "rr",         # Mostly a short alias for rm -rf but also faster
  "dups",       # Fast finder of exact duplicate files

  "cbtm",       # Back up & restore new Linux b-time stamps (creation/birth)
  "dirt",       # Recursively set dir time stamp to oldest of members
  "fage",       # file age according to various timestamps/rules
  "newest",     # b-time supporting \`find -printf|sort|tail\`
  "since",      # b-time supporting \`find -Xnewer\`
  "saft",       # SAve&restore File Times across a command operating on them

  "memlat",     # Measure memory latency at various size scales
  "fread",      # Like `cat` but just read data (no writes)
  "ru",         # Resource Usage measurement { high-res/nicer time(1) }
  "etr",        # e)stimate t)ime r)emaining using subcommands for %done
  "tim",        # Sanity checking benchmark timer using only basic statistics
  "bu/eve",     # Extreme Value Estimator (e.g. *true* min time of an infinite

  "align",      # Align text with better ergonomics than BSD `column`
  "tails",      # Generalizes head & tail into one with all-but compliments
  "cols",       # Extract just some columns from a text file/stream
  "rp",         # A row processor program-generator maybe replacement for AWK
  "crp",        # C row processor program-generator port of `rp`
  "cfold",      # Context folding (like csplit but to wrap lines)
  "unfold",     # Oft neglected inverse-to-wrapping/folding process
  "ww",         # Dynamic programming based word wrapper
  "jointr",     # Join strace "unfinished ..." with conclusion
  "bu/colSort", # Sort *within* the columns of rows

  "fsids",      # file system user & group id histogram
  "chom",       # Enforce group owner & segregated perms in file trees
  "thermctl",   # Thermal Control for before CPU makers thermally throttled
  "pid2",       # Wrap Linux process PID table to first past target
  "sr",         # System Request Key; Rapidly act on Linux systems

  "tattr",      # Terminal attribute access (like cligen/humanUt)
  "wsz",        # Report terminal size in cells, pixels, and cell size

  "okpaths",    # Validate/trim PATH-like vars by probing the system
  "dirq",       # Kind of its own system-building atom thing
  "funnel",     # A reliable, record boundary respecting "FIFO funnel
  "stripe",     # Run jobs in parallel w/slot key vars/seqNos/shell elision
]

# Dependencies
requires "nim >= 1.6.0", "cligen >= 1.5.36"
