#!/bin/sh
# run-all.sh: every reproducer of cfix-repro on cfix-base and cfix-asan
# (run.sh), in the order of the bug table, with the memory caps of the
# campaign: 2G for the growth cases (G1, G2) and the leak (N2), 4G for the
# rest. M1 is not run (needs ~64 GiB) and D1 is not a runnable reproducer.
# Usage: run-all.sh [-p PREFIX] (with -p, only the plain run on that prefix,
# for the fix branches).
cd "$(dirname "$0")" || exit 1; R=./run.sh; X=; [ "$1" = -p ] && X="-p $2"
# shellcheck disable=SC2086
{
$R $X S1-self-splice-overlap.nqp
$R $X -m 2G -t 60 G1-size-wrap.nqp
for c in over limit under far; do $R $X -m 2G -t 60 G2-limit-boundary.nqp $c; done
$R $X -t 60 P1-splice-from-non-vmarray.nqp
for c in target source; do $R $X -t 60 P2-splice-no-storage-kind.nqp $c; done
for c in int-into-obj obj-into-int num-from-int; do $R $X -t 60 P3-splice-cross-kind.nqp $c; done
$R $X -t 60 T1-rejected-pop.nqp; $R $X -t 60 T1-rejected-pop.nqp control
$R $X -t 60 T2-rejected-unshift.nqp; $R $X -t 60 T2-rejected-unshift.nqp control
$R $X -t 60 T3-self-splice-shifted.nqp; $R $X -t 60 T3-self-splice-shifted.nqp control
$R $X -t 60 B1-read-buf-past-storage.nqp; $R $X -t 60 B1-read-buf-past-storage.raku
$R $X -t 60 B2-buf-offset-wrap.nqp; $R $X -t 60 B2-buf-offset-wrap.raku
$R $X -t 60 B3-writeint-no-storage-kind.nqp
$R $X -t 60 R1-recompose-object-type.nqp
$R $X -t 60 N1-normalize-ssize-bytes.nqp
$R $X -m 2G -t 120 N2-strtocodes-leak.nqp; $R $X -m 2G -t 120 N2-strtocodes-leak.nqp control
$R $X -t 60 E1-encode-append-offset.nqp
for c in int64 hash; do $R $X -t 60 O1-procasync-buf-type.nqp $c; done
$R $X -t 60 X1-recompose-wider-kind.nqp
} > /dev/null 2>&1
echo "done: $(date '+%F %T')"
