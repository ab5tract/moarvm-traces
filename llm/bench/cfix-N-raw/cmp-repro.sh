#!/bin/sh
# cmp-repro.sh FIXDIR AREA: compares every reproducer output of a fix
# branch's run-all (FIXDIR/<x>.cfix-AREA{,-asan}.txt) with the unmodified
# upstream builds' output of the same program, after normalising what varies
# run to run (as cfix-G-raw/cmp-repro.sh: the probe and run lines, hex
# addresses, ASAN's ==PID==, BuildIds, prefix names, 12+-digit decimals,
# ASAN's shadow-byte dump). The upstream outputs come from:
#   cfix-baseline-raw/repro/<x>.{base,asan}.txt      (Task 1's programs)
#   cfix-S-raw/round1/<x>.cfix-{base,asan}.txt       (S1-self-splice-vs-clone,
#                                                     T3-self-splice-overcount)
#   cfix-P-raw/repro/<x>.{base,asan}.txt,
#   cfix-T-raw/repro/<x>.{base,asan}.txt             (the programs added with
#                                                     areas P and T)
#   cfix-B-raw/repro/<x>.{base,asan}.txt,
#   cfix-R-raw/repro/<x>.{base,asan}.txt             (the programs added with
#                                                     areas B and R)
#   cfix-N-raw/repro/<x>.{base,asan}.txt,
#   cfix-E-raw/repro/<x>.{base,asan}.txt,
#   cfix-O-raw/repro/<x>.{base,asan}.txt             (the programs added with
#                                                     areas N, E and O)
# (Task 4's copy of cfix-T-raw/cmp-repro.sh: these two sources and the
# prefix names B, R, M added; Task 5's copy: three more sources and the
# prefix names N, E, O, D.)
# Prints "same", "DIFFERS" or "MISSING" per file.
F=$1; A=$2; B=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM/traces/llm/bench
norm() { sed -e '1,2d' -e '/^=>0x[0-9a-f]*:/d' -e '/^  0x[0-9a-f]*:/d' -e 's/0x[0-9a-f]\{4,\}/0xADDR/g' -e 's/==[0-9]\+==/==PID==/g' -e 's/BuildId: [0-9a-f]*/BuildId/g' \
  -e 's/cfix-[A-Za-z]*-asan\|cfix-asan/PREFIX-ASAN/g' -e 's/cfix-base\b/PREFIX/g; s/cfix-[SGPTBRMNEOD]\b/PREFIX/g' -e 's/[0-9]\{12,\}/BIGNUM/g' \
  -e 's/+0x[0-9a-f]*)/+OFF)/g' "$1"; }
one() { # upstream-file stem kind(base|asan)
  case $3 in base) t=cfix-$A ;; *) t=cfix-$A-asan ;; esac
  f=$F/$2.$t.txt
  if [ ! -f "$f" ]; then echo "MISSING $2.$t"; return; fi
  norm "$1" > /tmp/claude-1000/cmp-a.$$; norm "$f" > /tmp/claude-1000/cmp-b.$$
  if cmp -s /tmp/claude-1000/cmp-a.$$ /tmp/claude-1000/cmp-b.$$; then echo "same    $2.$t"; else echo "DIFFERS $2.$t"; fi
}
for b in $B/cfix-baseline-raw/repro/*.txt $B/cfix-P-raw/repro/*.base.txt $B/cfix-P-raw/repro/*.asan.txt \
         $B/cfix-T-raw/repro/*.base.txt $B/cfix-T-raw/repro/*.asan.txt \
         $B/cfix-B-raw/repro/*.base.txt $B/cfix-B-raw/repro/*.asan.txt \
         $B/cfix-R-raw/repro/*.base.txt $B/cfix-R-raw/repro/*.asan.txt \
         $B/cfix-N-raw/repro/*.base.txt $B/cfix-N-raw/repro/*.asan.txt \
         $B/cfix-E-raw/repro/*.base.txt $B/cfix-E-raw/repro/*.asan.txt \
         $B/cfix-O-raw/repro/*.base.txt $B/cfix-O-raw/repro/*.asan.txt; do
  x=$(basename "$b")
  case $x in *.cfix-*) continue ;; *.base.txt) one "$b" "${x%.base.txt}" base ;; *.asan.txt) one "$b" "${x%.asan.txt}" asan ;; esac
done
for b in $B/cfix-S-raw/round1/*.cfix-base.txt $B/cfix-S-raw/round1/*.cfix-asan.txt; do
  x=$(basename "$b")
  case $x in *.cfix-base.txt) one "$b" "${x%.cfix-base.txt}" base ;; *) one "$b" "${x%.cfix-asan.txt}" asan ;; esac
done
rm -f /tmp/claude-1000/cmp-a.$$ /tmp/claude-1000/cmp-b.$$
