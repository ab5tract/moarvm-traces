#!/bin/sh
# cb Task 3 Step 3: cleanup.sh on cb-n-base (plain programs) and cb-n-stress
# (--stress variants), 20 runs each, after the 1-minute load is under 2.0;
# writes O/cleanup-<prefix>.txt (load line, the script's table and total, exit).
M=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
O=${1:-/tmp/claude-1000/cb/cleanup}
mkdir -p $O || exit 1
cd $M || exit 1
for spec in cb-n-base: cb-n-stress:--stress; do
  p=${spec%%:*}; flag=${spec#*:}
  until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 60; done
  { echo "load $(cut -d' ' -f1 /proc/loadavg) $(date +%T)"
    systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/cleanup.sh --prefix=/tmp/claude-1000/$p --runs=20 $flag
    echo "exit $?"; echo "end $(date +%T)"; } > $O/cleanup-$p.txt 2>&1
done
