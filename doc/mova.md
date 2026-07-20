# Motivation / Background

Atomic mv to place output is a common idiom.  Same dir/FS is not always natural.
To me this means OS mv's SHOULD have grown `--atomic` DECADES ago.  While my
motivating use-case was the rather ornate example, it is *far* from unique.
Opt-in vs. opt-out is debatable, but it has always been the case that `ENOSPC`
may be preferred to `EXDEV`.  Either is catchable by outer logic.

# Usage

```
mova SRC DST | mova -h
```

Like `mv` (1), try `rename` (2) first - already atomic on same FS mount.  On
`EXDEV`, `mova` falls back to copy to a tmp file in DST's dir + atomic rename +
`fsync` + unlink `SRC` where `ENOSPC` is a possible failure.  Preserves `SRC`
owner, perm bits & [am]time (usually all that's needed for placement idioms).

# Example: Edit a file w/\0 rather than \n row termination

This assumes GNU sed & *no actual* "↲" in rows. (A native \0-capable $EDITOR can
do without the no-special-string-in rows requirement):

```zsh
e0() {  # Edit 0-term                       # vim: set ft=zsh sw=2:
# Needs bu/mova for cross-FS-place safety, but maybe YOUR $1 & /tmp share mount?
  type mova >/dev/null >&2 && mv=mova || mv=mv
  local p="${TMPDIR:-/tmp}/h${UID}_"    # One per-UID name=~non-colliding enough
  [[ -e "${p}0" || -e "${p}1" || -e "${p}2" || -e "${p}3" ]] && {
    print -u2 "e0: stale ${p}[0-3]"; return 1 # Abort if files are left over..
  }                                           #..probably for manual clean-up.
  cp "$e0" "${p}0"||return 1  # Warn mostly to train users => small races are ok
  0n < "$e0" | tee "${p}1" > "${p}2"        # Transform for edit & later cmp
  ${=EDITOR:-vi} "${p}2"      # MAIN USER ACTION - MANUAL EDIT; Minimal wd-split
  if cmp "${p}1" "${p}2" >/dev/null         # Check if anything changed
  then print -u2 "e0: did not alter $e0"    # If not, do not cause a ruckus.
  else n0 < "${p}2" > "${p}3" && {          # Transform back
    cmp "${p}0" "$e0" >/dev/null ||print -u2 "e0: Lost newly completed commands"
    $mv "${p}3" "$e0"||print -u2 "e0: replace failed" } # Cross-mount atomic plc
  fi
  zf_rm -f "${p}"[0-3]                      # Clean-up
}
0n() { sed -z 's/\n/↲/g' | tr \\0 \\n }     # \0-term -> \n-term for edit
n0() { tr \\n \\0 | sed -z 's/↲/\n/g' }     # \n-term -> \0-term for posterity
```

For me, `/tmp` or `$TMPDIR` are typically a `/dev/shm` RAM filesystem.  So, the
cross mount point/FS case is the common case.
