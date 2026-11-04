#!/bin/bash
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo; export RAKULIB=lib
O=/tmp/claude-1000/inv/stats; rm -rf $O; mkdir -p $O/head $O/preflip
for v in preflip head; do
  until awk '{exit !($1 < 2.0)}' /proc/loadavg; do sleep 10; done
  p=/tmp/claude-1000/stats-$v
  LD_LIBRARY_PATH=$p/lib MVM_HASH_STATS=$O/$v perf stat -e instructions:u -x, -o $O/$v.stat ./rakudo-m t/spec/S32-str/sprintf-f.t > /dev/null 2>&1
  echo "$v $(cut -d, -f1 $O/$v.stat | head -3 | tr '\n' ' ') files: $(ls $O/$v | wc -l)" >> $O/summary.txt
  perl /home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM/tools/bench/hash-stats.pl $O/$v --lib=$p/lib/libmoar.so > $O/$v-report.md 2>$O/$v-report.err
done
echo done >> $O/summary.txt
