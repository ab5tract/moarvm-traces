#!/bin/sh
# Task 5: the plain and ASAN prefixes of areas N, E, O, D, one at a time.
E=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM/traces/llm/bench/cfix-T-raw/build/export-build.sh
for x in "normalize-array-result N" "encode-append-offset E" "procops-buf-type O" "serialization-root-array-var D"; do
  set -- $x
  sh $E $1 $2 || echo "FAILED $2"
  sh $E $1 $2-asan --asan --no-mimalloc || echo "FAILED $2-asan"
done
echo ALLDONE
