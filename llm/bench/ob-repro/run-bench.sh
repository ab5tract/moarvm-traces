#!/bin/sh
# ob-repro/run-bench.sh [-n RUNS] -o OUTDIR PREFIX_NAME...: the VMArray push
# benchmark (tools/bench/repr/vmarray-push-bench.nqp, plan Task 1 Step 6 and
# Task 5 Step 6) RUNS times (default 7) per prefix, the prefixes alternating
# within each round (round 1: A B, round 2: A B, ...) so that a drift of the
# machine hits both alike. Each run: the 1-minute load below 2.0 first
# (waits otherwise), MVM_SPESH_BLOCKING=1 and nothing else of the caller's
# MVM_* / NQP_* environment, LD_LIBRARY_PATH=/tmp/claude-1000/<prefix>/lib,
# nqp-m of /tmp/claude-1000/tune-zig-prefix, ulimit -c 0, a 300 s timeout,
# systemd-run --user --scope -p MemoryMax=4G.
# Writes OUTDIR/bench-<prefix>.txt: per run a header line
# "# run <k> <date> load <1-min load> libmoar <path the run mapped>" and the
# program's lines "<case> <seconds>"; then OUTDIR/bench-medians.txt: per
# prefix and case the values in run order, their median and their 25th and
# 75th percentiles (p25, p75: the sorted values at rank (runs + 1) / 4 and
# 3 (runs + 1) / 4, interpolated between neighbours; for 15 runs the 4th and
# the 12th value; added in Task 5).
N=7; O=
while getopts n:o: f; do case $f in n) N=$OPTARG ;; o) O=$OPTARG ;; *) exit 64 ;; esac; done
shift $((OPTIND - 1))
[ -n "$O" ] && [ $# -gt 0 ] || { echo "usage: run-bench.sh [-n RUNS] -o OUTDIR PREFIX_NAME..." >&2; exit 64; }
M=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
BENCH=$M/tools/bench/repr/vmarray-push-bench.nqp; NQP=/tmp/claude-1000/tune-zig-prefix/bin/nqp-m
mkdir -p "$O"
for p in "$@"; do [ -d "/tmp/claude-1000/$p/lib" ] || { echo "no /tmp/claude-1000/$p/lib" >&2; exit 64; }; : > "$O/bench-$p.txt"; done
scrub="-u LD_LIBRARY_PATH -u LD_PRELOAD"
for v in $(env | sed -n 's/^\(MVM_[A-Za-z0-9_]*\|NQP_[A-Za-z0-9_]*\)=.*/\1/p'); do scrub="$scrub -u $v"; done
probe='for nqp::split("\n", slurp("/proc/self/maps")) { if nqp::index($_, "libmoar") >= 0 { say(nqp::substr($_, nqp::index($_, "/"))); last } }'
k=1
while [ $k -le "$N" ]; do
  for p in "$@"; do
    until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 30; done
    l=$(cut -d' ' -f1 /proc/loadavg)
    # shellcheck disable=SC2086
    lib=$(env $scrub LD_LIBRARY_PATH=/tmp/claude-1000/$p/lib $NQP -e "$probe" 2>&1)
    echo "# run $k $(date '+%F %T') load $l libmoar $lib" >> "$O/bench-$p.txt"
    # shellcheck disable=SC2086
    ( ulimit -c 0; env $scrub MVM_SPESH_BLOCKING=1 LD_LIBRARY_PATH=/tmp/claude-1000/$p/lib timeout -k 5 300 \
        systemd-run --user --scope -q -p MemoryMax=4G -p MemorySwapMax=0 $NQP "$BENCH" ) >> "$O/bench-$p.txt" 2>&1 \
      || echo "# run $k failed: exit $?" >> "$O/bench-$p.txt"
  done
  k=$((k + 1))
done
for p in "$@"; do
  awk -v p="$p" '!/^#/ && NF == 2 { v[$1] = v[$1] " " $2; n[$1]++; if (!($1 in seen)) { seen[$1] = 1; order[++c] = $1 } }
    END { for (i = 1; i <= c; i++) { k = order[i]; m = split(substr(v[k], 2), a, " ");
            for (x = 1; x <= m; x++) for (y = x + 1; y <= m; y++) if (a[y] + 0 < a[x] + 0) { t = a[x]; a[x] = a[y]; a[y] = t }
            med = (m % 2) ? a[(m + 1) / 2] : (a[m / 2] + a[m / 2 + 1]) / 2;
            printf "%s %s runs %d median %s p25 %.4f p75 %.4f values%s\n", p, k, m, med, rank(a, m, (m + 1) / 4), rank(a, m, 3 * (m + 1) / 4), v[k] } }
    function rank(sorted, count, position,    whole) { if (position <= 1) return sorted[1]; if (position >= count) return sorted[count];
            whole = int(position); return sorted[whole] + (position - whole) * (sorted[whole + 1] - sorted[whole]) }' "$O/bench-$p.txt"
done > "$O/bench-medians.txt"
cat "$O/bench-medians.txt"
