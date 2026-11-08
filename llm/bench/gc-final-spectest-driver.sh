#!/bin/sh
# final-spectest.sh OUTDIR: Task 10 Step 3, the spectest A/B, order base head head base base head.
out=$1
[ -n "$out" ] || { echo "usage: final-spectest.sh OUTDIR" >&2; exit 64; }
[ -e "$out" ] && { echo "$out exists" >&2; exit 64; }
mkdir -p "$out"
M=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo || exit 1
n=0
for side in base head head base base head; do
  n=$((n + 1))
  case $side in base) lib=/tmp/claude-1000/gc-c-base/lib ;; head) lib=/tmp/claude-1000/gc-z-base/lib ;; esac
  until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 120; done
  roast=$(git -C t/spec rev-parse --short HEAD)
  if [ "$roast" != fb1d87214 ]; then echo "run $n: roast at $roast, not fb1d87214" | tee -a "$out/runs.log"; exit 1; fi
  find t/spec -type d -name .precomp -prune -exec rm -rf {} +
  moars=$(pgrep -a moar | wc -l)
  echo "run $n $side start $(date +%H:%M:%S) load $(cut -d' ' -f1-3 /proc/loadavg) roast $roast moar-procs-before $moars lib $lib" | tee -a "$out/runs.log"
  LD_LIBRARY_PATH=$lib TEST_JOBS=24 python3 $M/tools/bench/timev.py "$out/run$n-$side.time" make -o spectest_update spectest > "$out/run$n-$side.log" 2>&1
  rc=$?
  echo "run $n $side end $(date +%H:%M:%S) exit $rc" | tee -a "$out/runs.log"
done
