#!/bin/bash
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo
O=/tmp/claude-1000/inv/s3p; mkdir -p $O; export RAKULIB=lib
T=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM/tools/bench/timev.py
for round in 1 2 3; do
for v in base preflip head; do
  until awk '{exit !($1 < 2.0)}' /proc/loadavg; do sleep 10; done
  case $v in base) L=internals-base-prefix;; preflip) L=preflip-prefix;; head) L=tune-zig-prefix;; esac
  export LD_LIBRARY_PATH=/tmp/claude-1000/$L/lib
  for f in sprintf-f sprintf-x; do
  python3 $T $O/$f-$v-$round.time ./rakudo-m t/spec/S32-str/$f.t > /dev/null 2>&1
  echo "$f $v $round $(grep -E 'Elapsed|Maximum' $O/$f-$v-$round.time | tr -d '\t' | tr '\n' ' ')" >> $O/summary.log
  done
done; done
echo done >> $O/summary.log
