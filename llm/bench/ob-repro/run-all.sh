#!/bin/sh
# ob-repro/run-all.sh -p PREFIX_NAME -o OUTDIR: every reproducer of ob-repro on
# one prefix (run.sh), in the order of the bug ids, then area K. Adapted from
# cfix-mirror-raw/run-all-port.sh (same shape: run from the programs'
# directory, one line per program, outputs only in files). Memory caps: 2G
# for the programs whose "before" makes a huge allocation (OB2) or writes
# past a wrapped allocation (OB18), 4G (run.sh's default) for the rest.
# run.sh adds the .nojit run of the OB3 programs itself. The OB3 JIT programs
# take one case per run (see their headers).
cd "$(dirname "$0")" || exit 1; R=./run.sh; X=
while [ $# -gt 1 ]; do case $1 in -p|-o) X="$X $1 $2"; shift 2 ;; *) break ;; esac; done
case $X in *-p*) ;; *) echo "usage: run-all.sh -p PREFIX_NAME -o OUTDIR" >&2; exit 64 ;; esac
# shellcheck disable=SC2086
{
$R $X -m 2G -t 60 OB2-typeobj-splice.nqp
$R $X -m 2G -t 120 OB2-buf-new-array.raku
for c in flags_3 flags_16; do $R $X -t 120 OB3-readuint-jit.nqp $c; done
for c in writeint_flags_3 writeint_flags_16 writeuint_flags_3 writeuint_flags_16; do $R $X -t 120 OB3-writeint-jit.nqp $c; done
$R $X -t 60 OB3-writenum-size.nqp
$R $X -t 60 OB4-adopted-setelems.nqp
$R $X -t 60 OB7-rejected-push.nqp
$R $X -t 60 OB7-rejected-bindpos.nqp
$R $X -t 60 OB8-write-buf-growth.nqp
$R $X -t 120 OB8-write-uint64.raku
$R $X -t 60 OB9-normalize-empty.nqp
$R $X -t 60 OB12-anon-recompose.nqp
$R $X -t 60 OB16-num-buf-message.nqp
$R $X -m 2G -t 60 OB18-deserialize-size.nqp
$R $X -t 60 OB19-holes.nqp
$R $X -t 120 K-smallnatives.raku
$R $X -t 60 K-compose-small.nqp
} > /dev/null 2>&1
echo "done: $(date '+%F %T')"
