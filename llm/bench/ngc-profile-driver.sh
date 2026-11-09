#!/bin/sh
# ngc Task 2 Step 3: the caller of tools/bench/gc/profile.sh. One side per
# invocation, interleaved per setting as rounds with the side order rotated
# (c f, f c, c f); five perf stat runs per invocation; perf record once per
# side and setting (in round 1). Then the -nlto attribution pass (plain,
# --record only, c then f), then spec 7's .text fallback: a three-round
# crc-getter A/B of each -syms build against its -base sibling. Serial;
# profile.sh and ab.sh wait for load < 2.0 before every run and log it.
M=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
O=/tmp/claude-1000/ngc/profile
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
  run $setting/f-r1 --lib=/tmp/claude-1000/ng-f-syms/lib --stat-runs=5 --record $b
  run $setting/f-r2 --lib=/tmp/claude-1000/ng-f-syms/lib --stat-runs=5 $b
  run $setting/c-r2 --lib=/tmp/claude-1000/ng-c-syms/lib --stat-runs=5 $b
  run $setting/c-r3 --lib=/tmp/claude-1000/ng-c-syms/lib --stat-runs=5 $b
  run $setting/f-r3 --lib=/tmp/claude-1000/ng-f-syms/lib --stat-runs=5 $b
done
run nlto/c --lib=/tmp/claude-1000/ng-c-nlto/lib --stat-runs=0 --record
run nlto/f --lib=/tmp/claude-1000/ng-f-nlto/lib --stat-runs=0 --record
for s in c f; do
  echo "$(date +%T) start textab-$s" >> $O/driver.log
  systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/ab.sh --base=/tmp/claude-1000/ng-$s-base/lib \
      --head=/tmp/claude-1000/ng-$s-syms/lib --rounds=3 --runs=5 --volume=100000 --out=$O/textab-$s 2> $O/textab-$s.stderr
  rc=$?
  echo "$(date +%T) end textab-$s exit $rc" >> $O/driver.log
  [ $rc = 0 ] || exit 1
done
echo "$(date +%T) done" >> $O/driver.log
