#!/bin/sh
# va-spectest-driver.sh OUTDIR: the VMArray campaign's spectest A/B (Task 8,
# Step 4; ngc-spectest-driver.sh re-pointed): base va-c-base (C array,
# -Dzig-reprs=false), head va-n-base (Zig array), order base head head base
# base head. runs.log records each run's exit status. As the ngc driver,
# each run is under MemoryMax=24G: 24 test jobs together need more than 8G.
# The caller's MVM_*, RAKUDO_*, NQP_*, RAKU_*, PERL6* variables and RAKULIB are
# removed (as diff.sh); before each run a probe through ./rakudo-m records the
# libmoar.so it maps in runs.log, and one outside the side's prefix stops it.
out=$1
[ -n "$out" ] || { echo "usage: va-spectest-driver.sh OUTDIR" >&2; exit 64; }
[ -e "$out" ] && { echo "$out exists" >&2; exit 64; }
B=va-c-base; H=va-n-base
mkdir -p "$out"
M=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo || exit 1
scrub=$(env | sed -n 's/^\(\(MVM_\|RAKUDO_\|NQP_\|RAKU_\|PERL6\)[A-Za-z0-9_]*\|RAKULIB\)=.*/-u \1/p')
n=0
for side in base head head base base head; do
  n=$((n + 1))
  case $side in base) lib=/tmp/claude-1000/$B/lib ;; head) lib=/tmp/claude-1000/$H/lib ;; esac
  until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 60; done
  roast=$(git -C t/spec rev-parse --short HEAD)
  if [ "$roast" != fb1d87214 ]; then echo "run $n: roast at $roast, not fb1d87214" | tee -a "$out/runs.log"; exit 1; fi
  find t/spec -type d -name .precomp -prune -exec rm -rf {} +
  # shellcheck disable=SC2086
  mapped=$(env $scrub LD_LIBRARY_PATH=$lib ./rakudo-m -e 'say "/proc/self/maps".IO.lines.first(*.contains("libmoar")).words[*-1]' 2>&1)
  [ "$mapped" = "$lib/libmoar.so" ] || { echo "run $n: ./rakudo-m maps $mapped, not $lib/libmoar.so" | tee -a "$out/runs.log"; exit 4; }
  moars=$(pgrep -x moar | wc -l); rakus=$(pgrep -x raku | wc -l)
  echo "run $n $side start $(date '+%F %T') load $(cut -d' ' -f1-3 /proc/loadavg) roast $roast moar-procs-before $moars raku-procs-before $rakus lib $lib maps $mapped" | tee -a "$out/runs.log"
  # shellcheck disable=SC2086
  env $scrub LD_LIBRARY_PATH=$lib TEST_JOBS=24 systemd-run --user --scope -q -p MemoryMax=24G python3 $M/tools/bench/timev.py "$out/run$n-$side.time" make -o spectest_update spectest > "$out/run$n-$side.log" 2>&1
  rc=$?
  echo "run $n $side end $(date '+%F %T') exit $rc" | tee -a "$out/runs.log"
done
