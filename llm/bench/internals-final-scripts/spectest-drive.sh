#!/bin/bash
# usage: drive.sh [dry]
M=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
R=/home/longwalker/code/raku/x.core/zmoarz/rakudo
O=/tmp/claude-1000/final-st
B=/tmp/claude-1000/internals-base-prefix
cd $R
n=0
for v in base head head base base head; do
  n=$((n+1)); k=$(echo $n)
  while :; do
    l=$(cut -d' ' -f1 /proc/loadavg)
    busy=$(pgrep -af "context-bench|rakudo-image|eval-serve|native-eval" | grep -v "pgrep\|drive.sh\|zsh" | wc -l)
    if [ "$busy" = 0 ] && awk "BEGIN{exit !($l<2.0)}"; then break; fi
    [ "$1" = dry ] && break
    sleep 300
  done
  echo "run $n $v start $(date +%T) load $(cat /proc/loadavg | cut -d' ' -f1-3)" >> $O/runs.log
  find t/spec -name .precomp -type d -prune -exec rm -rf {} + 
  if [ "$1" = dry ]; then cmd=(true); else cmd=(make -o spectest_update spectest); fi
  if [ $v = base ]; then export LD_LIBRARY_PATH=$B/lib; else unset LD_LIBRARY_PATH; fi
  TEST_JOBS=24 python3 $M/tools/bench/timev.py $O/run$n-$v.time "${cmd[@]}" > $O/run$n-$v.log 2>&1
  echo "run $n $v exit $(grep 'Exit status' $O/run$n-$v.time)" >> $O/runs.log
  [ "$1" = dry ] && [ $n = 2 ] && break
done
