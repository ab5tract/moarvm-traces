#!/bin/sh
# z017-oracle-matrix-driver.sh OUTROOT: zig-017 Task 5 Step 2 (copied from
# gc-final-oracle-matrix.sh, re-pointed at the 0.17 prefixes).
# Groups: a = g7-c-oracle vs g7-z-oracle (0.17 C vs 0.17 Zig),
#         b = gc-c-oracle vs g7-c-oracle (0.16 C vs 0.17 C, the toolchain),
#         c = gc-z-oracle vs g7-z-oracle (0.16 Zig vs 0.17 Zig, supplementary),
#         d = gc-c-oracle vs g7-z-oracle (Campaign 4's C side, Zig hash engine + C
#             collector on 0.16, vs the 0.17 Zig side; supplementary).
# VOLUMES (environment, default "10000 100000") narrows the volumes.
# Each: volumes 10000 and 100000 x {plain, --bad-packages} x tier {1,2}.
# One line per cell to OUTROOT/matrix.tsv: group volume set tier exit seconds load_before lines.
# Stops after the first group (b) cell that is not exit 0 (a toolchain finding).
out=$1; shift
groups=${*:-a b c}
[ -n "$out" ] || { echo "usage: z017-oracle-matrix-driver.sh OUTROOT [groups]" >&2; exit 64; }
[ -e "$out" ] && { echo "$out exists" >&2; exit 64; }
mkdir -p "$out"
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
for g in $groups; do
  case $g in
    a) B=/tmp/claude-1000/g7-c-oracle; H=/tmp/claude-1000/g7-z-oracle ;;
    b) B=/tmp/claude-1000/gc-c-oracle; H=/tmp/claude-1000/g7-c-oracle ;;
    c) B=/tmp/claude-1000/gc-z-oracle; H=/tmp/claude-1000/g7-z-oracle ;;
    d) B=/tmp/claude-1000/gc-c-oracle; H=/tmp/claude-1000/g7-z-oracle ;;
    *) echo "unknown group $g" >&2; exit 64 ;;
  esac
  for v in ${VOLUMES:-10000 100000}; do
    for b in plain bad; do
      for t in 1 2; do
        until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 60; done
        l=$(cut -d' ' -f1 /proc/loadavg)
        if [ $b = bad ]; then flag=--bad-packages; else flag=; fi
        c=$g-v$v-$b-t$t
        s0=$(date +%s)
        systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/oracle.sh --base=$B --head=$H --volume=$v $flag --tier=$t --out="$out/$c" > "$out/$c.stderr" 2>&1
        rc=$?
        s1=$(date +%s)
        n=$(wc -l < "$out/$c/base-1.log" 2>/dev/null || echo 0)
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' $g $v $b $t $rc $((s1 - s0)) $l $n | tee -a "$out/matrix.tsv"
        if [ $g = b ] && [ $rc != 0 ]; then echo "group b cell $c exit $rc: stopping" | tee -a "$out/matrix.tsv"; exit 1; fi
      done
    done
  done
done
