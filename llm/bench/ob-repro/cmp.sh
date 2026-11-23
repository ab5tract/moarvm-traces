#!/bin/sh
# ob-repro/cmp.sh DIR PREFIX_A PREFIX_B: for every output <x>.PREFIX_A.txt in
# DIR (run.sh's files; <x> includes a ".nojit" part), prints "c=n " when it
# equals <x>.PREFIX_B.txt after normalisation, "C!=N" when not, "MISSING"
# when PREFIX_B has no output for <x>. Adapted from
# cfix-mirror-raw/cmp-repro.sh (its first verdict only; there is no fix branch
# to compare with). Normalisation as there: the probe and run lines dropped,
# hex addresses, PIDs, BuildIds, the two prefix names and the runner's
# install path in backtraces replaced. Unlike cmp-repro.sh, 12+-digit
# decimals are kept: these programs print large numbers on purpose (OB18's
# count, OB16's and OB3's values) and print no addresses as decimals.
D=$1; A=$2; B=$3
[ -d "$D" ] && [ -n "$A" ] && [ -n "$B" ] || { echo "usage: cmp.sh DIR PREFIX_A PREFIX_B" >&2; exit 64; }
T=$(mktemp -d /tmp/claude-1000/ob-cmp.XXXXXX) || exit 1
norm() { sed -e '1,2d' -e 's/0x[0-9a-f]\{4,\}/0xADDR/g' -e 's/==[0-9]\+==/==PID==/g' -e 's/BuildId: [0-9a-f]*/BuildId/g' \
  -e 's#/tmp/claude-1000/tune-zig-prefix/share#RUNNER#g' -e "s#$A#PREFIX#g; s#$B#PREFIX#g" "$1"; }
for a in "$D"/*."$A".txt; do
  x=$(basename "$a" ".$A.txt"); b="$D/$x.$B.txt"
  if [ ! -f "$b" ]; then echo "MISSING $x"; continue; fi
  norm "$a" > "$T/a"; norm "$b" > "$T/b"
  if cmp -s "$T/a" "$T/b"; then echo "c=n  $x"; else echo "C!=N $x"; fi
done
rm -rf "$T"
