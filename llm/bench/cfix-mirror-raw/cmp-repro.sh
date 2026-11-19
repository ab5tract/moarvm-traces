#!/bin/sh
# cmp-repro.sh DIR: Task 6's reproducer comparison. DIR holds run-all-port.sh's
# outputs on the port's two gate prefixes (<x>.vf-c-base.txt, the C array,
# and <x>.vf-n-base.txt, the Zig array). For every program and case <x> it
# prints three verdicts:
#   c=n      the C array's and the Zig array's outputs, normalised, are equal;
#   fixed    the C array's output equals the output the program's own area's
#            fix branch gave (cfix-<A>-raw/**/<x>.cfix-<A>.txt, A from the
#            file name: S G P T B R N E O; T3 -> S, its area; X1 -> R),
#            normalised;
#   (or NOFIX when that branch has no output for <x>.)
# Normalisation, as the area records' cmp-repro.sh: the probe and run lines
# dropped, hex addresses, PIDs, BuildIds, prefix names and 12+-digit
# decimals replaced; also the runner's install path in backtraces
# (/tmp/claude-1000/cfix-base/share or tune-zig-prefix/share: RUNNER).
D=$1; B=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM/traces/llm/bench
T=/tmp/claude-1000/vf/cmp.$$; mkdir -p $T
norm() { sed -e '1,2d' -e 's/0x[0-9a-f]\{4,\}/0xADDR/g' -e 's/==[0-9]\+==/==PID==/g' -e 's/BuildId: [0-9a-f]*/BuildId/g' \
  -e 's#/tmp/claude-1000/\(cfix-base\|tune-zig-prefix\)/share#RUNNER#g' -e 's/vf-[cn]-base/PREFIX/g; s/cfix-base\b/PREFIX/g; s/cfix-[SGPTBRMNEOD]\b/PREFIX/g' -e 's/[0-9]\{12,\}/BIGNUM/g' "$1"; }
for c in "$D"/*.vf-c-base.txt; do
  x=$(basename "$c" .vf-c-base.txt); n="$D/$x.vf-n-base.txt"
  norm "$c" > $T/c; norm "$n" > $T/n 2>/dev/null
  if cmp -s $T/c $T/n; then cn="c=n "; else cn="C!=N"; fi
  a=$(echo "$x" | cut -c1); [ "$a" = X ] && a=R; case $x in T3-*) a=S ;; esac
  f=$(find $B/cfix-$a-raw -name "$x.cfix-$a.txt" 2>/dev/null | sort | head -1)
  if [ -z "$f" ]; then fx="NOFIX "; else norm "$f" > $T/f; if cmp -s $T/c $T/f; then fx="fixed "; else fx="DIFFER"; fi; fi
  echo "$cn $fx $x${f:+ (vs ${f#$B/})}"
done
rm -rf $T
