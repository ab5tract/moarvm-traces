#!/bin/sh
# cb-crc-ab-driver.sh OUTROOT: the GC call-boundary campaign's acceptance crc-getter
# A/B (Task 3, Step 1; ngc-crc-ab-driver.sh re-pointed): first
# tools/bench/gc/call-boundary.sh /tmp/claude-1000/cb-n-syms/lib, refusing to start
# on a non-zero exit; then tools/bench/gc/ab.sh --base=ng-c-base --head=ng-n-base
# --head2=cb-n-base --rounds=7 --runs=5 --volume=100000, plain then
# --bad-packages, into OUTROOT/<setting>. runs.log records ab.sh's exit status
# (captured as $? of the systemd-run scope, which returns its command's status;
# the z017 driver's "exit" column printed date's).
out=$1
[ -n "$out" ] || { echo "usage: cb-crc-ab-driver.sh OUTROOT" >&2; exit 64; }
mkdir -p "$out"
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM || exit 1
sh tools/bench/gc/call-boundary.sh /tmp/claude-1000/cb-n-syms/lib > "$out/call-boundary.out" 2>&1
cbrc=$?
echo "call-boundary $(date +%H:%M:%S) exit $cbrc" | tee -a "$out/runs.log"
[ $cbrc -eq 0 ] || { echo "call-boundary.sh failed; not starting the A/B" >&2; exit 1; }
for set in plain bad; do
  if [ $set = bad ]; then flag=--bad-packages; else flag=; fi
  echo "$set start $(date +%H:%M:%S) load $(cut -d' ' -f1-3 /proc/loadavg) moar-procs $(pgrep -a moar | wc -l) rakudo-procs $(pgrep -a rakudo | wc -l)" | tee -a "$out/runs.log"
  systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/ab.sh --base=/tmp/claude-1000/ng-c-base/lib \
      --head=/tmp/claude-1000/ng-n-base/lib --head2=/tmp/claude-1000/cb-n-base/lib \
      --rounds=7 --runs=5 --volume=100000 $flag --out="$out/$set" > "$out/$set.stderr" 2>&1
  rc=$?
  echo "$set end $(date +%H:%M:%S) exit $rc" | tee -a "$out/runs.log"
done
