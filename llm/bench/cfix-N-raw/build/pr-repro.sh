#!/bin/sh
B=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM/traces/llm/bench
R=$B/cfix-repro/run.sh
for p in cfix-base cfix-asan cfix-N cfix-N-asan; do sh $R -p $p -t 120 -m 2G -o $B/cfix-N-raw/pr-repro $B/cfix-N-raw/pr-repro/n.nqp > /dev/null 2>&1; done
for p in cfix-base cfix-asan cfix-E cfix-E-asan; do sh $R -p $p -t 60 -o $B/cfix-E-raw/pr-repro $B/cfix-E-raw/pr-repro/e.nqp > /dev/null 2>&1; done
for p in cfix-base cfix-asan cfix-O cfix-O-asan; do for c in int64 missing rebind; do sh $R -p $p -t 60 -o $B/cfix-O-raw/pr-repro $B/cfix-O-raw/pr-repro/o.nqp $c > /dev/null 2>&1; done; done
echo ALLDONE
