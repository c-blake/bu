#!/bin/sh
set -e
now=$(date +%s)          # now as epoch seconds
touch -t 01010101.01 -m p1
touch -t 01010101.02 -a p1
touch -t 01010101.03 -m p2
touch -t 01010101.04 -a p2
sec=$(stat -c%Y p1)      # mtime as seconds
echo $((now - sec)) $(fage -fm p1) should be within rounding
echo $(fage -fb p1) should be \< 1 but ultimately FS dependent
echo $(fage -R/S -ra -fm p1) should be 1.0
echo $(fage -Rp2 -rm -fm p1) should be 2.0
echo $(fage -v2 -Rp2 -ra -fm p1) Basis for 3.0
rm -f p1 p2
