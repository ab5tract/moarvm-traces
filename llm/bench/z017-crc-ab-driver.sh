#!/bin/sh
# z017-crc-ab-driver.sh OUTROOT PAIR...: zig-017 Task 5 Step 3, the crc-getter
# A/B (tools/bench/gc/ab.sh, as gc-final-crc-ab.md ran it) per pair, plain then
# --bad-packages, into OUTROOT/<setting>-<pair>.
# PAIR: new  = base g7-c-base (0.17 C collector), head g7-z-base (0.17 Zig collector)
#       tool = base gc-c-base (0.16 C collector), head g7-c-base (0.17 C collector)
#       (every prefix carries the Zig hash engine; see z017-prefixes.md)
out=$1; shift
[ -n "$out" ] && [ $# -gt 0 ] || { echo "usage: z017-crc-ab-driver.sh OUTROOT new|tool..." >&2; exit 64; }
mkdir -p "$out"
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM || exit 1
for pair in "$@"; do
  case $pair in
    new)   B=g7-c-base; H=g7-z-base ;;
    tool)  B=gc-c-base; H=g7-c-base ;;
    *) echo "unknown pair $pair" >&2; exit 64 ;;
  esac
  for set in plain bad; do
    if [ $set = bad ]; then flag=--bad-packages; else flag=; fi
    echo "$pair $set start $(date +%H:%M:%S) load $(cut -d' ' -f1-3 /proc/loadavg) moar-procs $(pgrep -a moar | wc -l) rakudo-procs $(pgrep -a rakudo | wc -l)" | tee -a "$out/runs.log"
    systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/ab.sh --base=/tmp/claude-1000/$B/lib --head=/tmp/claude-1000/$H/lib \
        --rounds=7 --runs=5 --volume=100000 $flag --out="$out/$set-$pair" > "$out/$set-$pair.stderr" 2>&1
    echo "$pair $set end $(date +%H:%M:%S) exit $?" | tee -a "$out/runs.log"
  done
done
