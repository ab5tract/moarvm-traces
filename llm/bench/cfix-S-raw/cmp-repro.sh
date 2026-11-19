#!/bin/sh
# cmp-repro.sh FIXDIR AREA: compares every baseline reproducer output
# (cfix-baseline-raw/repro/<x>.{base,asan}.txt) with the fix branch's
# (FIXDIR/<x>.cfix-AREA{,-asan}.txt) after normalising what varies run to run:
# the probe and run lines (they name the prefix), hex addresses, ASAN's
# ==PID==, BuildIds, prefix names, and large decimal numbers printed as
# object addresses (P3 obj-into-int), and the shadow-byte dump of an ASAN
# report (its layout follows the address). Prints "same" or "DIFFERS" per file.
F=$1; A=$2; BL=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM/traces/llm/bench/cfix-baseline-raw/repro
norm() { sed -e '1,2d' -e '/^=>0x[0-9a-f]*:/d' -e '/^  0x[0-9a-f]*:/d' -e 's/0x[0-9a-f]\{4,\}/0xADDR/g' -e 's/==[0-9]\+==/==PID==/g' -e 's/BuildId: [0-9a-f]*/BuildId/g' \
  -e 's/cfix-[A-Za-z]*-asan\|cfix-asan/PREFIX-ASAN/g' -e 's/cfix-base\b/PREFIX/g; s/cfix-[SG]\b/PREFIX/g' -e 's/[0-9]\{12,\}/BIGNUM/g' \
  -e 's/+0x[0-9a-f]*)/+OFF)/g' "$1"; }
for b in $BL/*.base.txt $BL/*.asan.txt; do
  x=$(basename "$b"); case $x in *.base.txt) t=cfix-$A; s=${x%.base.txt} ;; *) t=cfix-$A-asan; s=${x%.asan.txt} ;; esac
  f=$F/$s.$t.txt
  if [ ! -f "$f" ]; then echo "MISSING $s.$t"; continue; fi
  norm "$b" > /tmp/claude-1000/cmp-a.$$; norm "$f" > /tmp/claude-1000/cmp-b.$$
  if cmp -s /tmp/claude-1000/cmp-a.$$ /tmp/claude-1000/cmp-b.$$; then echo "same    $s.$t"; else echo "DIFFERS $s.$t"; fi
done
rm -f /tmp/claude-1000/cmp-a.$$ /tmp/claude-1000/cmp-b.$$
