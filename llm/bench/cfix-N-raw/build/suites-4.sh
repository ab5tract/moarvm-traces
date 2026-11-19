#!/bin/sh
B=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM/traces/llm/bench
for a in N E O D; do
  echo "$a start $(date '+%T')"
  sh $B/cfix-maketest-driver.sh $B/cfix-$a-raw/suites cfix-$a
done
echo ALLDONE
