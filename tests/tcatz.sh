#!/bin/sh
set -e
if [ $# -ne 2 ]; then cat <<EOF
Run with exactly 2 args, INPUTFILE CORRECTOUTPUT (e.g. foo.gz foo), this script
tests auto-decode for many cases - with|without filename extensions, file|pipe
input|output, and recognizing|not a magic number data header.
EOF
    exit 1
fi

: ${SEEK:=8}
i="$(pwd)/$1"
o="$(pwd)/$2"
t="$(mktemp -d /dev/shm/tcatzXXX)"
cd "$t"

test1() {
    eval $4
    cmp o "$2" || echo "$3" FAIL AT "$4"
}

test6() {    # With a pathname (& *maybe* extension)
    for tst in 'catz $1>o'  'catz $1|cat>o' \
               'catz<$1>o'  'catz<$1|cat>o' 'cat<$1|catz>o' 'cat<$1|catz|cat>o'
#               iFile,oFile  iFile,oPipe     iPipe,oFile     iPipe,oPipe
    do test1 "$1" "$2" "$3" "$tst"
    done
}
ln -s "$i" noExt
test1 noExt "$o" "NO-EXTEN" 'catz $1>o'
test1 noExt "$o" "NO-EXTEN" 'catz $1|cat>o'

test6 "$i" "$o" DECODED

dd seek="$SEEK" if="$i" of=noMag 2>/dev/null
test6 noMag noMag PASS-THROUGH

printf '' > len0
test6 len0 len0 PASS-THROUGH-0

rm -rf "$t"
echo "SUCCESS"
