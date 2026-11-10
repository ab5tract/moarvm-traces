#!/bin/sh
# Task 8 stage 2: suites, cleanup, five full crc-getter runs under ng-n-stress.
M=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
R=/home/longwalker/code/raku/x.core/zmoarz/rakudo
O=/tmp/claude-1000/ngc/t8
echo "stage2 start $(date '+%F %T %Z')"
sh $M/traces/llm/bench/ngc-maketest-driver.sh $O/suites nqp:n-base nqp:n-stress rakudo:n-base rakudo:n-stress > $O/suites-driver.out 2>&1
echo "suites driver exit $? $(date '+%F %T %Z')"
cat $O/suites/summary.tsv
for p in ng-n-base ng-n-stress; do
  until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 60; done
  { echo "load $(cut -d' ' -f1 /proc/loadavg) $(date +%T)"; sh $M/tools/bench/gc/cleanup.sh --prefix=/tmp/claude-1000/$p --runs=20; echo "exit $?"; } > $O/cleanup-$p.txt 2>&1
  echo "cleanup $p: $(grep '^passed' $O/cleanup-$p.txt) $(tail -1 $O/cleanup-$p.txt)"
done
mkdir -p $O/stress
cd $M || exit 1
for i in 1 2 3 4 5; do
  until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 60; done
  l=$(cut -d' ' -f1 /proc/loadavg)
  LD_LIBRARY_PATH=/tmp/claude-1000/ng-n-stress/lib RAKULIB="$M/tools/bench/gc/lib,$R/lib" systemd-run --user --scope -q -p MemoryMax=8G \
    python3 $M/tools/bench/timev.py $O/stress/run-$i.time $R/rakudo-m tools/bench/gc/crc-getter.raku --volume=100000 --runs=5 > $O/stress/run-$i.out 2>&1
  rc=$?
  printf 'stress run %s\texit %s\tload %s\t%s\n' $i $rc $l "$(tr '\n' ' ' < $O/stress/run-$i.time)" | tee -a $O/stress/runs.tsv
done
echo "stage2 end $(date '+%F %T %Z')"
