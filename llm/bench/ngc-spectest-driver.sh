#!/bin/sh
# ngc-spectest-driver.sh OUTDIR: the Zig-native GC campaign's spectest A/B
# (Task 9, Step 4; z017-spectest-driver.sh re-pointed): base ng-c-base (C
# collector, -Dzig-gc=false), head ng-n-base (native collector), order base
# head head base base head. runs.log records each run's exit status.
out=$1
[ -n "$out" ] || { echo "usage: ngc-spectest-driver.sh OUTDIR" >&2; exit 64; }
[ -e "$out" ] && { echo "$out exists" >&2; exit 64; }
B=ng-c-base; H=ng-n-base
mkdir -p "$out"
M=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo || exit 1
n=0
for side in base head head base base head; do
  n=$((n + 1))
  case $side in base) lib=/tmp/claude-1000/$B/lib ;; head) lib=/tmp/claude-1000/$H/lib ;; esac
  until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 60; done
  roast=$(git -C t/spec rev-parse --short HEAD)
  if [ "$roast" != fb1d87214 ]; then echo "run $n: roast at $roast, not fb1d87214" | tee -a "$out/runs.log"; exit 1; fi
  find t/spec -type d -name .precomp -prune -exec rm -rf {} +
  moars=$(pgrep -a moar | wc -l); rakudos=$(pgrep -a rakudo | wc -l)
  echo "run $n $side start $(date +%H:%M:%S) load $(cut -d' ' -f1-3 /proc/loadavg) roast $roast moar-procs-before $moars rakudo-procs-before $rakudos lib $lib" | tee -a "$out/runs.log"
  LD_LIBRARY_PATH=$lib TEST_JOBS=24 systemd-run --user --scope -q -p MemoryMax=24G python3 $M/tools/bench/timev.py "$out/run$n-$side.time" make -o spectest_update spectest > "$out/run$n-$side.log" 2>&1
  rc=$?
  echo "run $n $side end $(date +%H:%M:%S) exit $rc" | tee -a "$out/runs.log"
done
