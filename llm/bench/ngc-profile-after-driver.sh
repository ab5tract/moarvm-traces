#!/bin/sh
# ngc Task 9 Step 6: the after-profile, ngc-profile-driver.sh (Task 2) with the
# native ng-n-syms / ng-n-nlto in place of the faithful ng-f-* (the c side is
# Task 2's ng-c-syms / ng-c-nlto, unchanged). Per setting the rounds c n, n c,
# c n (five perf stat runs per invocation, perf record in round 1); then the
# -nlto attribution pass (plain, --record only, c then n), then spec 7's .text
# fallback: a three-round crc-getter A/B of each -syms build against its -base
# sibling. Serial; profile.sh and ab.sh wait for load < 2.0 before every run.
M=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
O=/tmp/claude-1000/ngc/acc/profile
mkdir -p $O/plain $O/bad $O/nlto || exit 1
cd $M || exit 1
run() { # dir, then profile.sh arguments
  d=$1; shift
  echo "$(date +%T) start $d" >> $O/driver.log
  systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/profile.sh --out=$O/$d "$@" 2> $O/$d.stderr
  rc=$?
  echo "$(date +%T) end $d exit $rc" >> $O/driver.log
  [ $rc = 0 ] || exit 1
}
for setting in plain bad; do
  b=; [ $setting = bad ] && b=--bad-packages
  run $setting/c-r1 --lib=/tmp/claude-1000/ng-c-syms/lib --stat-runs=5 --record $b
  run $setting/n-r1 --lib=/tmp/claude-1000/ng-n-syms/lib --stat-runs=5 --record $b
  run $setting/n-r2 --lib=/tmp/claude-1000/ng-n-syms/lib --stat-runs=5 $b
  run $setting/c-r2 --lib=/tmp/claude-1000/ng-c-syms/lib --stat-runs=5 $b
  run $setting/c-r3 --lib=/tmp/claude-1000/ng-c-syms/lib --stat-runs=5 $b
  run $setting/n-r3 --lib=/tmp/claude-1000/ng-n-syms/lib --stat-runs=5 $b
done
run nlto/c --lib=/tmp/claude-1000/ng-c-nlto/lib --stat-runs=0 --record
run nlto/n --lib=/tmp/claude-1000/ng-n-nlto/lib --stat-runs=0 --record
for s in c n; do
  echo "$(date +%T) start textab-$s" >> $O/driver.log
  systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/ab.sh --base=/tmp/claude-1000/ng-$s-base/lib \
      --head=/tmp/claude-1000/ng-$s-syms/lib --rounds=3 --runs=5 --volume=100000 --out=$O/textab-$s 2> $O/textab-$s.stderr
  rc=$?
  echo "$(date +%T) end textab-$s exit $rc" >> $O/driver.log
  [ $rc = 0 ] || exit 1
done
echo "$(date +%T) done" >> $O/driver.log
