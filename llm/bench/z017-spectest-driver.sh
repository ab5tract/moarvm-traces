#!/bin/sh
# z017-spectest-driver.sh OUTDIR PAIR: zig-017 Task 5 Step 4 (copied from
# gc-final-spectest-driver.sh, re-pointed at the 0.17 prefixes), the spectest
# A/B, order base head head base base head.
# PAIR: new  = base g7-c-base (0.17 C collector), head g7-z-base (0.17 Zig collector)
#       tool = base gc-c-base (0.16 C collector), head g7-c-base (0.17 C collector)
#       (every prefix carries the Zig hash engine; see z017-prefixes.md)
out=$1; pair=$2
[ -n "$out" ] && [ -n "$pair" ] || { echo "usage: z017-spectest-driver.sh OUTDIR new|tool" >&2; exit 64; }
[ -e "$out" ] && { echo "$out exists" >&2; exit 64; }
case $pair in
  new)   B=g7-c-base; H=g7-z-base ;;
  tool)  B=gc-c-base; H=g7-c-base ;;
  *) echo "unknown pair $pair" >&2; exit 64 ;;
esac
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
