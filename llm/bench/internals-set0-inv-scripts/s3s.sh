#!/bin/bash
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo
O=/tmp/claude-1000/inv/s3s; mkdir -p $O; export RAKULIB=lib
T=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM/tools/bench/timev.py
for round in 1 2; do
for v in base head; do
  until awk '{exit !($1 < 2.0)}' /proc/loadavg; do sleep 10; done
  export LD_LIBRARY_PATH=/tmp/claude-1000/sym-$v/lib
  python3 $T $O/f-$v-$round.time ./rakudo-m t/spec/S32-str/sprintf-f.t > /dev/null 2>&1
  echo "$v $round $(grep Elapsed $O/f-$v-$round.time | tr -d '\t')" >> $O/summary.log
  if [ $round = 1 ]; then
  perf record -F 999 -g -o $O/f-$v.data -- ./rakudo-m t/spec/S32-str/sprintf-f.t > /dev/null 2>&1
  perf report -i $O/f-$v.data --no-children --sort symbol --stdio -g none -n 2>/dev/null | grep -v '^#' | grep -v '^$' > $O/f-$v.syms
  perf report -i $O/f-$v.data --no-children --sort dso --stdio -g none -n 2>/dev/null | grep -v '^#' | grep -v '^$' > $O/f-$v.dso
  fi
done; done
echo done >> $O/summary.log
