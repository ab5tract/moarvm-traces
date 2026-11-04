#!/bin/bash
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo; export RAKULIB=lib
O=/tmp/claude-1000/inv/stat2; mkdir -p $O
run() { # name prefix envvar...
  n=$1; p=$2; shift 2
  env LD_LIBRARY_PATH=/tmp/claude-1000/$p/lib "$@" perf stat -e instructions:u,cycles:u -x, -o $O/$n.csv ./rakudo-m t/spec/S32-str/sprintf-f.t >/dev/null 2>&1
  echo "$n $(grep -v '^#' $O/$n.csv | awk -F, '{printf "%s=%.2fG ", $3, $1/1e9}')" | tee -a $O/summary.txt
}
until awk '{exit !($1 < 2.0)}' /proc/loadavg; do sleep 10; done
run preflip-s1 preflip-prefix MVM_HASH_STRATEGY=1
run head-s1 tune-zig-prefix MVM_HASH_STRATEGY=1
run preflip-s2 preflip-prefix MVM_HASH_STRATEGY=2
run head-s2 tune-zig-prefix MVM_HASH_STRATEGY=2
run preflip-nospesh preflip-prefix MVM_SPESH_DISABLE=1
run head-nospesh tune-zig-prefix MVM_SPESH_DISABLE=1
echo done >> $O/summary.txt
