#!/bin/sh
# ngc Task 4 tripwire: ng-n-base against ng-c-base, plain, 3 rounds x 5 runs (or ROUNDS from env).
M=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
out=$1; rounds=${2:-3}
cd $M || exit 1
until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 60; done
echo "start $(date '+%F %T %Z') load $(cut -d' ' -f1 /proc/loadavg)"
systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/ab.sh --base=/tmp/claude-1000/ng-c-base/lib \
  --head=/tmp/claude-1000/ng-n-base/lib --rounds=$rounds --runs=5 --volume=100000 --out="$out" > "$out.stderr" 2>&1
rc=$?
echo "end $(date '+%F %T %Z') ab.sh exit $rc"
