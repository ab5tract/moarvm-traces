#!/bin/sh
B=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM/traces/llm/bench
for a in N E O D; do
  for p in cfix-$a cfix-$a-asan; do
    until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 20; done
    echo "$p start $(date '+%T')"
    sh $B/cfix-repro/run-all.sh -p $p -o $B/cfix-$a-raw/repro
  done
done
echo ALLDONE
