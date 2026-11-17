#!/bin/sh
# nqp make test against one side: t7-nqp-test.sh SIDE PREFIX OUTDIR
# Runs in the nqp checkout with LD_LIBRARY_PATH=PREFIX/lib, the caller's
# MVM_*, RAKUDO_*, NQP_*, RAKU_*, PERL6* variables and RAKULIB removed (as
# diff.sh), after a probe of which libmoar ./nqp-m maps; under
# systemd-run MemoryMax=8G, after the 1-minute load is below 2.0.
side=$1 P=$2 O=$3
N=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp
W=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM/.superpowers/sdd/2026-11-16-zig-vmarray-repr
mkdir -p "$O"
scrub=$(env | sed -n 's/^\(\(MVM_\|RAKUDO_\|NQP_\|RAKU_\|PERL6\)[A-Za-z0-9_]*\|RAKULIB\)=.*/-u \1/p')
cd "$N" || exit 1
"$W/waitload.sh" > "$O/$side-load.txt"
# shellcheck disable=SC2086
env $scrub LD_LIBRARY_PATH="$P/lib" ./nqp-m -e 'for nqp::split("\n", slurp("/proc/self/maps")) { if nqp::index($_, "libmoar") >= 0 { say(nqp::substr($_, nqp::index($_, "/"))); last } }' > "$O/$side-probe.txt" 2>&1
s=$(date +%s)
# shellcheck disable=SC2086
env $scrub LD_LIBRARY_PATH="$P/lib" systemd-run --user --scope -q -p MemoryMax=8G make test > "$O/$side-make-test.out" 2>&1
rc=$?
echo "$side: make test exit $rc, $(( $(date +%s) - s )) s, $(cat "$O/$side-load.txt"), libmoar $(cat "$O/$side-probe.txt")" | tee "$O/$side-summary.txt"
# Per-file verdicts: prove's line per test file, sorted.
grep -E '^t/[^ ]+ \.+ ' "$O/$side-make-test.out" | sed 's/ [0-9]* wallclock.*//' | sort > "$O/$side-verdicts.txt"
