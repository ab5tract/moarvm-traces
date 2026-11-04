#!/bin/bash
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo
V=/tmp/claude-1000/inv
T=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM/tools/bench/timev.py
i=0
for b in base head head base; do
  i=$((i+1))
  find t/spec -name .precomp -type d -prune -exec rm -rf {} +
  until awk '{exit !($1 < 2.0)}' /proc/loadavg && ! pgrep -af "context-bench|rakudo-image|eval-serve|native-eval" | grep -qv pgrep; do sleep 20; done
  echo "$b run$i roast $(git -C t/spec rev-parse --short HEAD) start $(date +%T) load $(cat /proc/loadavg)" >> $V/load.log
  if [ $b = base ]; then export LD_LIBRARY_PATH=/tmp/claude-1000/internals-base-prefix/lib; else unset LD_LIBRARY_PATH; fi
  PERL5OPT="-I$V/perl5lib -MHarnessTimer" TEST_JOBS=24 python3 $T $V/s1-$i-$b.time make -o spectest_update spectest > $V/s1-$i-$b.log 2>&1
  echo "$b run$i exit $?" >> $V/load.log
done
echo done >> $V/load.log
