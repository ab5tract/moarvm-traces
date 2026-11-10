#!/bin/sh
# ngc-crc-ab-driver.sh OUTROOT: the Zig-native GC campaign's acceptance crc-getter
# A/B (Task 9, Step 3; z017-crc-ab-driver.sh re-pointed at the ng-* prefixes and
# made three-sided): tools/bench/gc/ab.sh --base=ng-c-base --head=ng-f-base
# --head2=ng-n-base --rounds=7 --runs=5 --volume=100000, plain then
# --bad-packages, into OUTROOT/<setting>. runs.log records ab.sh's exit status
# (the z017 driver's "exit" column printed date's).
out=$1
[ -n "$out" ] || { echo "usage: ngc-crc-ab-driver.sh OUTROOT" >&2; exit 64; }
mkdir -p "$out"
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM || exit 1
for set in plain bad; do
  if [ $set = bad ]; then flag=--bad-packages; else flag=; fi
  echo "$set start $(date +%H:%M:%S) load $(cut -d' ' -f1-3 /proc/loadavg) moar-procs $(pgrep -a moar | wc -l) rakudo-procs $(pgrep -a rakudo | wc -l)" | tee -a "$out/runs.log"
  systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/ab.sh --base=/tmp/claude-1000/ng-c-base/lib \
      --head=/tmp/claude-1000/ng-f-base/lib --head2=/tmp/claude-1000/ng-n-base/lib \
      --rounds=7 --runs=5 --volume=100000 $flag --out="$out/$set" > "$out/$set.stderr" 2>&1
  rc=$?
  echo "$set end $(date +%H:%M:%S) exit $rc" | tee -a "$out/runs.log"
done
