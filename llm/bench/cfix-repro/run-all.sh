#!/bin/sh
# run-all.sh: every reproducer of cfix-repro on cfix-base and cfix-asan
# (run.sh), in the order of the bug table, with the memory caps of the
# campaign: 2G for the growth cases (G1, G2) and the leak (N2), 4G for the
# rest. M1 is not run (needs ~64 GiB) and D1 is not a runnable reproducer.
# Usage: run-all.sh [-p PREFIX] [-o OUTDIR] (with -p, only one run on that
# prefix, for the fix branches: ASAN when PREFIX ends in -asan).
# Task 4 added B2-buf-offset-before-storage, B-buf-grid, B3-write-no-storage-state
# and R-recompose-matrix.
cd "$(dirname "$0")" || exit 1; R=./run.sh; X=
while [ $# -gt 1 ]; do case $1 in -p|-o) X="$X $1 $2"; shift 2 ;; *) break ;; esac; done
# shellcheck disable=SC2086
{
$R $X S1-self-splice-overlap.nqp
$R $X -m 2G -t 60 G1-size-wrap.nqp
for c in over limit under far; do $R $X -m 2G -t 60 G2-limit-boundary.nqp $c; done
$R $X -t 60 P1-splice-from-non-vmarray.nqp
for c in target source; do $R $X -t 60 P2-splice-no-storage-kind.nqp $c; done
for c in int-into-obj obj-into-int num-from-int str-into-obj empty-other; do $R $X -t 60 P3-splice-cross-kind.nqp $c; done
$R $X -t 60 T1-rejected-pop.nqp; $R $X -t 60 T1-rejected-pop.nqp control
$R $X -t 60 T2-rejected-unshift.nqp; $R $X -t 60 T2-rejected-unshift.nqp control
$R $X -t 60 T3-self-splice-shifted.nqp; $R $X -t 60 T3-self-splice-shifted.nqp control
$R $X -t 60 T3-self-splice-overcount.nqp; $R $X -t 60 T3-self-splice-overcount.nqp control
$R $X -t 600 S1-self-splice-vs-clone.nqp
$R $X -t 60 P1-splice-empty-non-vmarray.nqp
for c in same-fit same-grow empty-src empty-into; do $R $X -t 60 P2-splice-no-storage-same-kind.nqp $c; done
$R $X -t 120 P3-splice-kind-matrix.nqp
$R $X -t 60 T-rejected-leaves-array.nqp
$R $X -t 60 B1-read-buf-past-storage.nqp; $R $X -t 60 B1-read-buf-past-storage.raku
$R $X -t 60 B2-buf-offset-wrap.nqp; $R $X -t 60 B2-buf-offset-wrap.raku
$R $X -t 60 B2-buf-offset-before-storage.nqp
$R $X -t 60 B3-writeint-no-storage-kind.nqp
$R $X -t 60 R1-recompose-object-type.nqp
$R $X -t 60 N1-normalize-ssize-bytes.nqp
$R $X -m 2G -t 120 N2-strtocodes-leak.nqp; $R $X -m 2G -t 120 N2-strtocodes-leak.nqp control
$R $X -t 60 E1-encode-append-offset.nqp
$R $X -t 60 E2-encode-append-rounding.nqp
for c in int64 hash; do $R $X -t 60 O1-procasync-buf-type.nqp $c; done
$R $X -t 60 X1-recompose-wider-kind.nqp
$R $X -t 300 B-buf-grid.nqp
for c in live fresh; do $R $X -t 60 B3-write-no-storage-state.nqp $c; done
$R $X -t 60 R-recompose-matrix.nqp
} > /dev/null 2>&1
echo "done: $(date '+%F %T')"
