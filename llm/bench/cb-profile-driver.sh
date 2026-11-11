#!/bin/sh
# cb Task 3 Step 2: the after-profile, ngc-profile-after-driver.sh re-pointed: the
# c side is ng-c-syms (Campaign 6 Task 2's build, unchanged), the n side cb-n-syms
# (this branch, -Dstrip=false). Per setting the rounds c n, n c, c n (five perf
# stat runs per invocation, perf record in round 1). The -nlto attribution pass is
# dropped (there is no cb nlto prefix). Spec 7's .text fallback: a three-round
# crc-getter A/B of cb-n-syms against cb-n-base only; ng-c-syms against ng-c-base
# was measured at Campaign 6 (ngc-profile-after.md) and is cited, not re-run.
# Serial; profile.sh and ab.sh wait for load < 2.0 before every run.
M=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
O=/tmp/claude-1000/cb/profile
mkdir -p $O/plain $O/bad || exit 1
cd $M || exit 1
run() { # dir, then profile.sh arguments
  d=$1; shift
  echo "$(date +%T) start $d load $(cut -d' ' -f1 /proc/loadavg)" >> $O/driver.log
  systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/profile.sh --out=$O/$d "$@" 2> $O/$d.stderr
  rc=$?
  echo "$(date +%T) end $d exit $rc" >> $O/driver.log
  [ $rc = 0 ] || exit 1
}
for setting in plain bad; do
  b=; [ $setting = bad ] && b=--bad-packages
  run $setting/c-r1 --lib=/tmp/claude-1000/ng-c-syms/lib --stat-runs=5 --record $b
  run $setting/n-r1 --lib=/tmp/claude-1000/cb-n-syms/lib --stat-runs=5 --record $b
  run $setting/n-r2 --lib=/tmp/claude-1000/cb-n-syms/lib --stat-runs=5 $b
  run $setting/c-r2 --lib=/tmp/claude-1000/ng-c-syms/lib --stat-runs=5 $b
  run $setting/c-r3 --lib=/tmp/claude-1000/ng-c-syms/lib --stat-runs=5 $b
  run $setting/n-r3 --lib=/tmp/claude-1000/cb-n-syms/lib --stat-runs=5 $b
done
echo "$(date +%T) start textab-n load $(cut -d' ' -f1 /proc/loadavg)" >> $O/driver.log
systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/ab.sh --base=/tmp/claude-1000/cb-n-base/lib \
    --head=/tmp/claude-1000/cb-n-syms/lib --rounds=3 --runs=5 --volume=100000 --out=$O/textab-n 2> $O/textab-n.stderr
rc=$?
echo "$(date +%T) end textab-n exit $rc" >> $O/driver.log
[ $rc = 0 ] || exit 1
echo "$(date +%T) done" >> $O/driver.log
