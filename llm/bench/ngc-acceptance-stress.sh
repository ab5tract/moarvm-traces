#!/bin/sh
# ngc Task 9, spec 9's threaded evidence at acceptance: the full crc-getter
# (--volume=100000 --runs=5) under ng-c-stress and ng-n-stress, five runs each,
# alternating c n c n ..., load < 2.0 before each (Task 8's stage2.sh loop, two sides).
M=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
R=/home/longwalker/code/raku/x.core/zmoarz/rakudo
O=/tmp/claude-1000/ngc/acc/stress
mkdir -p $O
cd $M || exit 1
for i in 1 2 3 4 5; do
  for s in c n; do
    until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 60; done
    l=$(cut -d' ' -f1 /proc/loadavg)
    LD_LIBRARY_PATH=/tmp/claude-1000/ng-$s-stress/lib RAKULIB="$M/tools/bench/gc/lib,$R/lib" systemd-run --user --scope -q -p MemoryMax=8G \
      python3 $M/tools/bench/timev.py $O/$s-run-$i.time $R/rakudo-m tools/bench/gc/crc-getter.raku --volume=100000 --runs=5 > $O/$s-run-$i.out 2>&1
    rc=$?
    printf 'ng-%s-stress run %s\texit %s\tload %s\t%s\n' $s $i $rc $l "$(grep -E 'Elapsed|Maximum resident|Exit status' $O/$s-run-$i.time | tr '\n' ' ')" | tee -a $O/runs.tsv
  done
done
