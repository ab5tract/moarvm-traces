#!/bin/bash
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo; export RAKULIB=lib
O=/tmp/claude-1000/inv/stat; mkdir -p $O
for r in 1 2; do for v in internals-base-prefix preflip-prefix tune-zig-prefix; do
 LD_LIBRARY_PATH=/tmp/claude-1000/$v/lib perf stat -e cycles:u,instructions:u,branch-misses:u,cache-misses:u,L1-dcache-load-misses:u,dTLB-load-misses:u,task-clock -x, -o $O/$v-$r.csv ./rakudo-m t/spec/S32-str/sprintf-f.t >/dev/null 2>&1
done; done
for f in $O/*.csv; do echo "# $(basename $f)"; grep -v '^#' $f | awk -F, '{printf "%s=%s ", $3, $1} END{print ""}'; done
