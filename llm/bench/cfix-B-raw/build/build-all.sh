#!/bin/sh
E=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM/traces/llm/bench/cfix-T-raw/build/export-build.sh
for x in "vmarray-buf-bounds B" "vmarray-recompose R" "vmarray-mark-presize M"; do
  set -- $x
  sh $E $1 $2 || echo "FAILED $2"
  sh $E $1 $2-asan --asan --no-mimalloc || echo "FAILED $2-asan"
done
echo ALLDONE
