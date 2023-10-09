#!/bin/sh
: ${idx:="-1"}
n='
'
T() {
  d=""                      # Only Zsh needs this to avoid appending to $d
  n='
'                           # read -rd works in Bash|Zsh, but not POSIX.  So,
  while IFS= read -r line   #..loop which works for all text but input with no
  do d="$d${line}$n"        #..final newline where we add one "erroneously".
  done; d=${d%?}            # Chop extra newline
  echo "$d"                 # This adds \n back here for test output.
}
noa "$idx" -- cp -a F -f "/x/maybe/mis${n}sing" | T
noa "$idx" cp -- -a F -f "/x/maybe/mis${n}sing" | T
noa "$idx" cp -a -- F -f "/x/maybe/mis${n}sing" | T
noa "$idx" cp -a F -- -f "/x/maybe/mis${n}sing" | T
noa "$idx" cp -a F -f -- "/x/maybe/mis${n}sing" | T
noa "$idx" cp -a F -f "/x/maybe/mis${n}sing" -- | T
echo ----
noa "$idx" cp -a F -f "${n}/x/maybe/m${n}issing${n}${n}" -- | T
