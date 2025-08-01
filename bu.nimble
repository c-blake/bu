# Package
version     = "0.18.11"
author      = "Charles Blake"
description = "B)asic|But-For U)tility Code/Programs (Usually Nim & With Unix/POSIX/Linux Context)"
license     = "MIT/ISC"

when defined(Windows):
 bin         = @[
# "catz",       # Generalize `zcat` to many encodings, not merely `gzip`
# "ft",         # file typer {i-node type, not file(1)/libmagic(3) type}
# "only",       # file(1)/libmagic tool to emit files whose types match
# "fkindc",     # file(1)/libmagic tool to histogram file types
  "notIn",      # Helper to manage semi-mirrored file trees

# "dfr",        # d)isk fr)ee; `df` with color coding & modern defaults
# "lncs",       # analyze a file tree for hard link structure
# "du",         # Slight improvement on GNU du
# "rr",         # Mostly a short alias for rm -rf but also faster
# "dups",       # Fast finder of exact duplicate files
  "fpr",        # File Pages Resident reporting utility like fincore

# "cbtm",       # Back up & restore new Linux b-time stamps (creation/birth)
# "dirt",       # Recursively set dir time stamp to oldest of members
  "fage",       # file age according to various timestamps/rules
# "newest",     # b-time supporting \`find -printf|sort|tail\`
# "since",      # b-time supporting \`find -Xnewer\`
# "saft",       # SAve&restore File Times across a command operating on them
  "bu/tmath",   # Convert/do arithmetic directly upon date & time formats
  "mk1",        # Very fast `make` for many 1-to-1 input-output mappings

  "memlat",     # Measure memory latency at various size scales
  "fread",      # Like `cat` but just read data (no writes)
# "ru",         # Resource Usage measurement { high-res/nicer time(1) }
  "etr",        # e)stimate t)ime r)emaining using subcommands for %done
  "bu/eve",     # Extreme Value Estimator (*true* max|min of infinite sample)
  "tim",        # Uncertain time comparison via repeated sampling & `eve`
  "edplot",     # Generate EDF & its confidence bands files & plot scripts
  "keydowns",   # Assess string complexity in terms of a human cost

  "align",      # Align text with better ergonomics than BSD `column`
  "flow",       # Flow text lines into as many columns as fit with aligned output
  "tails",      # Terminal-friendly & generalized head & tail
  "cols",       # Extract just some columns from a text file/stream
  "adorn",      # Add prefix &| suffix to various text file/stream columns
  "rp",         # A row processor program-generator maybe replacement for AWK
  "crp",        # C row processor program-generator port of `rp`
  "bu/colSort", # Sort *within* the columns of rows
  "cstats",     # Preserve Context/Compute Column stats filter

  "cfold",      # Context folding (like csplit but to wrap lines)
  "unfold",     # Oft neglected inverse-to-wrapping/folding process
  "ww",         # Dynamic programming based word wrapper
  "widths",     # Compute & emit line widths/lengths | distro
# "jointr",     # Join strace "unfinished ..." with conclusion
  "ndelta",     # Numerical difference between two reports utility
  "tmpls",      # A fast string template interpolater

  "topn",       # Fast, streaming 1-pass top-N over M columns
  "oft",        # Approximately most often items via a low-memory algorithm
  "uce",        # Unique/distinct Count Estimate via a low-memory algorithm

# "holes",      # Show maps of data & in-FS-allocation holes
# "fsids",      # file system user & group id histogram
# "chom",       # Enforce group owner & segregated perms in file trees
# "thermctl",   # Thermal Control for before CPU makers thermally throttled
# "pid2",       # Wrap Linux process PID table to first past target
# "sr",         # System Request Key; Rapidly act on Linux systems

# "vip",        # Visual Interactive Pick; `percol`/`fzf`-like filter
  "noc",        # stdin-out filter to strip ANSI CSI/OSC/SGR color escape seqs
  "tw",         # terminal-width clip/cropper with m-row bounding capability
  "tslice",     # UTF8-ANSI SGR aware text slicer with Python-like ':'
  "tattr",      # Terminal attribute access (like cligen/humanUt)
# "wsz",        # Report terminal size in cells, pixels, and cell size

  "noa",        # "--"-aware Python-like indexing of non-option arguments
  "okpaths",    # Validate/trim PATH-like vars by probing the system
  "nrel",       # Edit .nimble version, commit, tag, push & maybe release
  "dirq",       # Kind of its own system-building atom thing
# "funnel",     # A reliable, record boundary respecting "FIFO funnel"
# "stripe",     # Run jobs in parallel w/slot key vars/seqNos/shell elision
  "bu/rs",      # Reservoir Subset/Sampler Of Lines In A File/[T] library
  "wgt",        # Weighted random sampler with fancy weighting
  "bu/zipf",    # Random samples according to Zipf distribution
  "niom",       # nio moments w/hard dep on adix efficient histogram/quantiles
  "ac",         # aped commands with aping rules stored in local file tree
 ]
else:
 bin         = @[
  "catz",       # Generalize `zcat` to many encodings, not merely `gzip`
  "ft",         # file typer {i-node type, not file(1)/libmagic(3) type}
  "only",       # file(1)/libmagic tool to emit files whose types match
  "fkindc",     # file(1)/libmagic tool to histogram file types
  "notIn",      # Helper to manage semi-mirrored file trees

  "dfr",        # d)isk fr)ee; `df` with color coding & modern defaults
  "lncs",       # analyze a file tree for hard link structure
  "du",         # Slight improvement on GNU du
  "rr",         # Mostly a short alias for rm -rf but also faster
  "dups",       # Fast finder of exact duplicate files
  "fpr",        # File Pages Resident reporting utility like fincore

  "cbtm",       # Back up & restore new Linux b-time stamps (creation/birth)
  "dirt",       # Recursively set dir time stamp to oldest of members
  "fage",       # file age according to various timestamps/rules
  "newest",     # b-time supporting \`find -printf|sort|tail\`
  "since",      # b-time supporting \`find -Xnewer\`
  "saft",       # SAve&restore File Times across a command operating on them
  "bu/tmath",   # Convert/do arithmetic directly upon date & time formats
  "mk1",        # Very fast `make` for many 1-to-1 input-output mappings

  "memlat",     # Measure memory latency at various size scales
  "fread",      # Like `cat` but just read data (no writes)
  "ru",         # Resource Usage measurement { high-res/nicer time(1) }
  "etr",        # e)stimate t)ime r)emaining using subcommands for %done
  "bu/eve",     # Extreme Value Estimator (*true* max|min of infinite sample)
  "tim",        # Uncertain time comparison via repeated sampling & `eve`
  "edplot",     # Generate EDF & its confidence bands files & plot scripts
  "keydowns",   # Assess string complexity in terms of a human cost

  "align",      # Align text with better ergonomics than BSD `column`
  "flow",       # Flow text lines into as many columns as fit with aligned output
  "tails",      # Terminal-friendly & generalized head & tail
  "cols",       # Extract just some columns from a text file/stream
  "adorn",      # Add prefix &| suffix to various text file/stream columns
  "rp",         # A row processor program-generator maybe replacement for AWK
  "crp",        # C row processor program-generator port of `rp`
  "bu/colSort", # Sort *within* the columns of rows
  "cstats",     # Preserve Context/Compute Column stats filter

  "cfold",      # Context folding (like csplit but to wrap lines)
  "unfold",     # Oft neglected inverse-to-wrapping/folding process
  "ww",         # Dynamic programming based word wrapper
  "widths",     # Compute & emit line widths/lengths | distro
  "jointr",     # Join strace "unfinished ..." with conclusion
  "ndelta",     # Numerical difference between two reports utility
  "tmpls",      # A fast string template interpolater

  "topn",       # Fast, streaming 1-pass top-N over M columns
  "oft",        # Approximately most often items via a low-memory algorithm
  "uce",        # Unique/distinct Count Estimate via a low-memory algorithm

  "holes",      # Show maps of data & in-FS-allocation holes
  "fsids",      # file system user & group id histogram
  "chom",       # Enforce group owner & segregated perms in file trees
  "thermctl",   # Thermal Control for before CPU makers thermally throttled
  "pid2",       # Wrap Linux process PID table to first past target
  "sr",         # System Request Key; Rapidly act on Linux systems

  "vip",        # Visual Interactive Pick; `percol`/`fzf`-like filter
  "noc",        # stdin-out filter to strip ANSI CSI/OSC/SGR color escape seqs
  "tw",         # terminal-width clip/cropper with m-row bounding capability
  "tslice",     # UTF8-ANSI SGR aware text slicer with Python-like ':'
  "tattr",      # Terminal attribute access (like cligen/humanUt)
  "wsz",        # Report terminal size in cells, pixels, and cell size

  "noa",        # "--"-aware Python-like indexing of non-option arguments
  "okpaths",    # Validate/trim PATH-like vars by probing the system
  "nrel",       # Edit .nimble version, commit, tag, push & maybe release
  "dirq",       # Kind of its own system-building atom thing
  "funnel",     # A reliable, record boundary respecting "FIFO funnel"
  "stripe",     # Run jobs in parallel w/slot key vars/seqNos/shell elision
  "bu/rs",      # Reservoir Subset/Sampler Of Lines In A File/[T] library
  "wgt",        # Weighted random sampler with fancy weighting
  "bu/zipf",    # Random samples according to Zipf distribution
  "niom",       # nio moments w/hard dep on adix efficient histogram/quantiles
  "ac",         # aped commands with aping rules stored in local file tree
 ]

# Dependencies
requires "nim >= 2.0.0", "cligen >= 1.8.9",
         "adix >= 0.6.6", "nio >= 0.7.9", "fitl >= 0.6.3", "spfun >= 0.7.4"
