#!/bin/sh
# gate-t7/cmp-cfix-repro.sh DIR: Task 7's comparison of cfix-repro outputs.
# DIR holds cfix-mirror-raw/run-all-port.sh's outputs on ob-c and ob-n
# (<x>.ob-c.txt, <x>.ob-n.txt). For every <x> it prints three verdicts:
#   c=n / C!=N  ob-c against ob-n;
#   C:same / C:DIFF  ob-c against cfix-mirror-raw/repro/<x>.vf-c-base.txt;
#   N:same / N:DIFF  ob-n against cfix-mirror-raw/repro/<x>.vf-n-base.txt.
# Normalisation: cfix-mirror-raw/cmp-repro.sh's (probe and run lines dropped,
# hex addresses, PIDs, BuildIds, runner path, prefix names and 12+-digit
# decimals replaced), with ob-c/ob-n added to the prefix names.
D=$1; B=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM/traces/llm/bench/cfix-mirror-raw/repro
T=$(mktemp -d /tmp/claude-1000/t7-cmp.XXXXXX) || exit 1
norm() { sed -e '1,2d' -e 's/0x[0-9a-f]\{4,\}/0xADDR/g' -e 's/==[0-9]\+==/==PID==/g' -e 's/BuildId: [0-9a-f]*/BuildId/g' \
  -e 's#/tmp/claude-1000/\(cfix-base\|tune-zig-prefix\)/share#RUNNER#g' -e 's/vf-[cn]-base/PREFIX/g; s/\bob-[cn]\b/PREFIX/g' -e 's/[0-9]\{12,\}/BIGNUM/g' "$1"; }
for c in "$D"/*.ob-c.txt; do
  x=$(basename "$c" .ob-c.txt); n="$D/$x.ob-n.txt"
  norm "$c" > $T/c; norm "$n" > $T/n 2>/dev/null; norm "$B/$x.vf-c-base.txt" > $T/vc 2>/dev/null; norm "$B/$x.vf-n-base.txt" > $T/vn 2>/dev/null
  if cmp -s $T/c $T/n; then cn="c=n "; else cn="C!=N"; fi
  if [ ! -f "$B/$x.vf-c-base.txt" ]; then vc="C:NONE"; elif cmp -s $T/c $T/vc; then vc="C:same"; else vc="C:DIFF"; fi
  if [ ! -f "$B/$x.vf-n-base.txt" ]; then vn="N:NONE"; elif cmp -s $T/n $T/vn; then vn="N:same"; else vn="N:DIFF"; fi
  echo "$cn $vc $vn $x"
done
rm -rf $T
