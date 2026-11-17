#!/bin/sh
# va-crc-ab-driver.sh OUTROOT [plain|bad ...]: the VMArray campaign's crc-getter
# A/B (Task 8, Step 5; ngc-crc-ab-driver.sh re-pointed at the va-* prefixes, two
# sides): tools/bench/gc/ab.sh --base=va-c-base --head=va-n-base --rounds=7
# --runs=5 --volume=100000, plain then --bad-packages (or the settings named),
# into OUTROOT/<setting>. runs.log records ab.sh's exit status.
out=$1; [ $# -gt 0 ] && shift
sets=${*:-plain bad}
[ -n "$out" ] || { echo "usage: va-crc-ab-driver.sh OUTROOT [plain|bad ...]" >&2; exit 64; }
mkdir -p "$out"
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM || exit 1
for set in $sets; do
  [ -e "$out/$set" ] && { echo "$out/$set exists" >&2; exit 64; }
  if [ $set = bad ]; then flag=--bad-packages; else flag=; fi
  echo "$set start $(date '+%F %T') load $(cut -d' ' -f1-3 /proc/loadavg) moar-procs $(pgrep -x moar | wc -l) raku-procs $(pgrep -x raku | wc -l)" | tee -a "$out/runs.log"
  systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/ab.sh --base=/tmp/claude-1000/va-c-base/lib \
      --head=/tmp/claude-1000/va-n-base/lib \
      --rounds=7 --runs=5 --volume=100000 $flag --out="$out/$set" > "$out/$set.stderr" 2>&1
  rc=$?
  echo "$set end $(date '+%F %T') exit $rc" | tee -a "$out/runs.log"
done
