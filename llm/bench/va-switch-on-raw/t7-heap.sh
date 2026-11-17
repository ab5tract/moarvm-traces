#!/bin/sh
# Heap snapshot through the Zig or C array: t7-heap.sh SIDE PREFIX OUTDIR
side=$1 P=$2 O=$3
R=/home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m
W=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM/.superpowers/sdd/2026-11-16-zig-vmarray-repr
mkdir -p "$O"
scrub=$(env | sed -n 's/^\(\(MVM_\|RAKUDO_\|NQP_\|RAKU_\|PERL6\)[A-Za-z0-9_]*\|RAKULIB\)=.*/-u \1/p')
"$W/waitload.sh" > "$O/$side-heap-load.txt"
s=$(date +%s)
# shellcheck disable=SC2086
env $scrub LD_LIBRARY_PATH="$P/lib" systemd-run --user --scope -q -p MemoryMax=8G timeout 900 "$R" --profile=heap --profile-filename="$O/$side.mvmheap" -e 'my @a = 1..1000; my int @b = 1..1000; say @a.elems + @b.elems' > "$O/$side-heap.out" 2> "$O/$side-heap.err"
rc=$?
echo "$side: heap snapshot exit $rc, $(( $(date +%s) - s )) s, $(cat "$O/$side-heap-load.txt"), stdout '$(cat "$O/$side-heap.out")', stderr $(wc -c < "$O/$side-heap.err") bytes, snapshot $(wc -c < "$O/$side.mvmheap" 2>/dev/null || echo none) bytes" | tee "$O/$side-heap-summary.txt"
