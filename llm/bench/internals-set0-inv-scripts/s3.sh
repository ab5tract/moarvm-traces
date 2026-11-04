#!/bin/bash
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo
O=/tmp/claude-1000/inv/s3; mkdir -p $O
T=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM/tools/bench/timev.py
P=/tmp/claude-1000
export RAKULIB=lib
for f in S32-str/sprintf-f S32-str/sprintf-b S32-str/sprintf-x; do
 n=$(basename $f)
 for v in base head head base; do
  until awk '{exit !($1 < 2.0)}' /proc/loadavg && ! pgrep -af "context-bench|rakudo-image|eval-serve|native-eval" | grep -qv pgrep; do sleep 20; done
  if [ $v = base ]; then export LD_LIBRARY_PATH=$P/internals-base-prefix/lib; else unset LD_LIBRARY_PATH; fi
  k=$((k+1))
  python3 $T $O/$n-$v-$k.time ./rakudo-m t/spec/$f.t > $O/$n-$v-$k.out 2>&1
  echo "$n $v $k load $(cut -d' ' -f1 /proc/loadavg) $(grep -E 'Elapsed|Maximum' $O/$n-$v-$k.time | tr -d '\t' | tr '\n' ' ')" >> $O/summary.log
 done
 for v in base head; do
  if [ $v = base ]; then export LD_LIBRARY_PATH=$P/internals-base-prefix/lib; else unset LD_LIBRARY_PATH; fi
  perf record -F 499 -g -o $O/$n-$v.data -- ./rakudo-m t/spec/$f.t > $O/$n-$v.perfout 2>&1
  perf report -i $O/$n-$v.data --no-children --sort symbol --stdio -g none 2>/dev/null | grep -v '^#' | grep -v '^$' > $O/$n-$v.syms
  rm -f $O/$n-$v.data
 done
done
echo done >> $O/summary.log
