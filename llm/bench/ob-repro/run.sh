#!/bin/sh
# ob-repro/run.sh: one reproducer of the open-bugs fixes (plan
# traces/llm/plans/2026-11-23-open-bugs-port-fixes.md, Task 1) on one prefix.
# Adapted from cfix-mirror-raw/run-port.sh, with these changes only:
#   - -p PREFIX_NAME is required (there is no two-prefix mode);
#   - the default OUTDIR is ob-fixes-raw/adhoc;
#   - .raku programs get -I<rakudo checkout>/lib (for `use experimental`);
#   - an OB3-* program is run a second time with MVM_JIT_DISABLE=1, into a
#     second file whose name has ".nojit" before the prefix name.
#
# run.sh -p PREFIX_NAME [-m MEM] [-t SECS] [-o OUTDIR] PROGRAM [ARGS...]
# Runs PROGRAM (.nqp with nqp-m, .raku with rakudo-m) against the libmoar of
# /tmp/claude-1000/PREFIX_NAME/lib and writes
#   OUTDIR/<file name>[.<args>].<PREFIX_NAME>.txt
#   OUTDIR/<file name>[.<args>].nojit.<PREFIX_NAME>.txt   (OB3-* only)
# each with: the libmoar the runner mapped (probe), the command, the output
# (stdout and stderr together) and the exit status. Every run: core dumps off,
# a timeout (default 120 s), systemd-run --user --scope -p MemoryMax=MEM
# (default 4G) and MemorySwapMax=0, spesh and JIT at their defaults (every
# MVM_*, RAKUDO_*, NQP_*, RAKU_*, PERL6* and RAKULIB variable of the caller's
# environment is removed).
# Runners (as cfix-mirror-raw/run-port.sh): nqp-m of
# /tmp/claude-1000/tune-zig-prefix (read only) and the rakudo checkout's
# rakudo-m with RAKUDO_NO_PRECOMPILATION=1; LD_LIBRARY_PATH points them at the
# prefix's libmoar (it wins over their RUNPATH).
MEM=4G; T=120; ONLY=; O=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM/traces/llm/bench/ob-fixes-raw/adhoc
while getopts m:t:p:o: f; do case $f in m) MEM=$OPTARG ;; t) T=$OPTARG ;; p) ONLY=$OPTARG ;; o) O=$OPTARG ;; *) exit 64 ;; esac; done
shift $((OPTIND - 1)); P=$1; [ $# -gt 0 ] && shift
usage="usage: run.sh -p PREFIX_NAME [-m MEM] [-t SECS] [-o OUTDIR] PROGRAM [ARGS...]"
[ -n "$ONLY" ] || { echo "run.sh: -p PREFIX_NAME is required; $usage" >&2; exit 64; }
[ -f "$P" ] || { echo "$usage" >&2; exit 64; }
[ -d "/tmp/claude-1000/$ONLY/lib" ] || { echo "run.sh: no /tmp/claude-1000/$ONLY/lib" >&2; exit 64; }
RAKUDO_DIR=/home/longwalker/code/raku/x.core/zmoarz/rakudo
NQP=/tmp/claude-1000/tune-zig-prefix/bin/nqp-m; RAK=$RAKUDO_DIR/rakudo-m; mkdir -p "$O"; ARGS="$*"
scrub="-u LD_LIBRARY_PATH -u LD_PRELOAD -u ASAN_OPTIONS"
for v in $(env | sed -n 's/^\(MVM_[A-Za-z0-9_]*\|RAKUDO_[A-Za-z0-9_]*\|NQP_[A-Za-z0-9_]*\|RAKU_[A-Za-z0-9_]*\|PERL6[A-Za-z0-9_]*\|RAKULIB\)=.*/\1/p'); do scrub="$scrub -u $v"; done
case $P in *.nqp) run=$NQP; runopts=; probe='for nqp::split("\n", slurp("/proc/self/maps")) { if nqp::index($_, "libmoar") >= 0 { say(nqp::substr($_, nqp::index($_, "/"))); last } }' ;;
           *.raku) run=$RAK; runopts="-I$RAKUDO_DIR/lib"; probe='say "/proc/self/maps".IO.lines.first(*.contains("libmoar")).words[*-1]' ;;
           *) echo "not .nqp or .raku: $P" >&2; exit 64 ;; esac
name=$(basename "$P"); [ $# -gt 0 ] && name="$name.$(echo "$*" | tr ' /' '_-')"
one() { # tag extra_env [program args]
  tag=$1; extra=$2; shift 2; f="$O/$name.$tag.txt"
  envs="LD_LIBRARY_PATH=/tmp/claude-1000/$ONLY/lib"; case $P in *.raku) envs="$envs RAKUDO_NO_PRECOMPILATION=1" ;; esac
  [ -n "$extra" ] && envs="$envs $extra"
  # shellcheck disable=SC2086
  { echo "probe: $(env $scrub $envs $run -e "$probe" 2>&1)"
    echo "run:   $envs $(basename $run) $runopts $(basename "$P") $ARGS (timeout $T s, MemoryMax=$MEM, ulimit -c 0)"
    echo "----"
    ( ulimit -c 0; env $scrub $envs timeout -k 5 "$T" systemd-run --user --scope -q -p MemoryMax="$MEM" -p MemorySwapMax=0 $run $runopts "$P" "$@" ) 2>&1
    rc=$?; echo "----"; echo "exit: $rc"; } > "$f"
  echo "== $f"; cat "$f"
}
one "$ONLY" "" "$@"
case $(basename "$P") in OB3-*) one "nojit.$ONLY" "MVM_JIT_DISABLE=1" "$@" ;; esac
