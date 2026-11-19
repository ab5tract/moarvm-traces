#!/bin/sh
# run.sh [-m MEM] [-t SECS] [-p PREFIX] [-o OUTDIR] PROGRAM [ARGS...]
# Runs one reproducer (.nqp with nqp-m, .raku with rakudo-m) twice: on the
# plain build (cfix-base) and on the AddressSanitizer build (cfix-asan), and
# writes OUTDIR/<file name>[.<args>].{base,asan}.txt: the libmoar the run
# mapped (probe), the command, the output (stdout and stderr together) and
# the exit status. Every run: core dumps off, a timeout (default 120 s), and
# systemd-run --user --scope -p MemoryMax=MEM (default 4G).
# The runners are the ones installed in /tmp/claude-1000/cfix-base (nqp
# 305ff2f77, rakudo c6d6fc3c6b built against cfix-base); for the ASAN run
# LD_LIBRARY_PATH points them at cfix-asan's libmoar (it wins over their
# RUNPATH) and libasan is preloaded. -p NAME instead runs only the plain run
# against /tmp/claude-1000/NAME/lib (for the fix branches later).
# ASAN_OPTIONS: detect_leaks=0 (MoarVM does not free everything at exit),
# abort_on_error=0, and symbolized reports.
MEM=4G; T=120; ONLY=; O=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM/traces/llm/bench/cfix-baseline-raw/repro
while getopts m:t:p:o: f; do case $f in m) MEM=$OPTARG ;; t) T=$OPTARG ;; p) ONLY=$OPTARG ;; o) O=$OPTARG ;; *) exit 64 ;; esac; done
shift $((OPTIND - 1)); P=$1; shift
[ -f "$P" ] || { echo "usage: run.sh [-m MEM] [-t SECS] [-p PREFIX] [-o OUTDIR] PROGRAM [ARGS...]" >&2; exit 64; }
B=/tmp/claude-1000/cfix-base/bin; mkdir -p "$O"; ARGS="$*"
scrub="-u LD_LIBRARY_PATH -u LD_PRELOAD -u ASAN_OPTIONS"
for v in $(env | sed -n 's/^\(MVM_[A-Za-z0-9_]*\|RAKUDO_[A-Za-z0-9_]*\|NQP_[A-Za-z0-9_]*\|RAKU_[A-Za-z0-9_]*\|PERL6[A-Za-z0-9_]*\|RAKULIB\)=.*/\1/p'); do scrub="$scrub -u $v"; done
case $P in *.nqp) run=$B/nqp-m; probe='for nqp::split("\n", slurp("/proc/self/maps")) { if nqp::index($_, "libmoar") >= 0 { say(nqp::substr($_, nqp::index($_, "/"))); last } }' ;;
           *.raku) run=$B/rakudo-m; probe='say "/proc/self/maps".IO.lines.first(*.contains("libmoar")).words[*-1]' ;;
           *) echo "not .nqp or .raku: $P" >&2; exit 64 ;; esac
name=$(basename "$P"); [ $# -gt 0 ] && name="$name.$(echo "$*" | tr ' /' '_-')"
one() { # tag libdir preload [program args]
  tag=$1; lib=$2; pre=$3; shift 3; f="$O/$name.$tag.txt"
  envs="LD_LIBRARY_PATH=$lib"; [ -n "$pre" ] && envs="$envs LD_PRELOAD=$pre ASAN_OPTIONS=detect_leaks=0:abort_on_error=0:symbolize=1"
  # shellcheck disable=SC2086
  { echo "probe: $(env $scrub $envs $run -e "$probe" 2>&1)"
    echo "run:   $envs $(basename $run) $(basename "$P") $ARGS (timeout $T s, MemoryMax=$MEM, ulimit -c 0)"
    echo "----"
    ( ulimit -c 0; env $scrub $envs timeout -k 5 "$T" systemd-run --user --scope -q -p MemoryMax="$MEM" -p MemorySwapMax=0 $run "$P" "$@" ) 2>&1
    rc=$?; echo "----"; echo "exit: $rc"; } > "$f"
  echo "== $f"; cat "$f"
}
if [ -n "$ONLY" ]; then one "$ONLY" /tmp/claude-1000/$ONLY/lib "" "$@"; exit; fi
one base /tmp/claude-1000/cfix-base/lib "" "$@"
one asan /tmp/claude-1000/cfix-asan/lib /usr/lib/libasan.so.8 "$@"
