#!/bin/sh
# ob-repro/run.sh: one reproducer of the open-bugs fixes (plan
# traces/llm/plans/2026-11-23-open-bugs-port-fixes.md, Task 1) on one prefix.
# Adapted from cfix-mirror-raw/run-port.sh, with these changes only:
#   - -p PREFIX_NAME is required (there is no two-prefix mode);
#   - the default OUTDIR is ob-fixes-raw/adhoc;
#   - .raku programs get -I<rakudo checkout>/lib (for `use experimental`);
#   - an OB3-* program is run a second time with MVM_JIT_DISABLE=1, into a
#     second file whose name has ".nojit" before the prefix name, and a third
#     time with MVM_SPESH_BLOCKING=1 and MVM_SPESH_LOG=<temporary file>, into
#     a file with ".jitlog" there: after the exit status it gets the lines
#     "jit: specialization of '<frame>' holding <ops>: compiled|not compiled"
#     (with any "BAIL: ..." comment the JIT left on the frame), one per
#     specialization of a frame of PROGRAM's own file whose final ("After:")
#     code holds readuint, writeint, writeuint or writenum, read from the
#     spesh log (MVMSpeshCandidate.c prints the After dump, which carries the
#     JIT's BAIL comments, and "JIT was [not ]successful" for every
#     specialization). This is the evidence that the op ran in JIT-compiled
#     code (the plain run's counts alone cannot show it). The log is deleted.
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
jit_evidence() { # spesh log, program path as passed to the runner, its basename
  # A frame is the program's when the "file: <path>:<line>" of a "Spesh of"
  # header names the program: the path as given, or any path ending in
  # /<basename> (the log holds the path the way the runner was given it).
  awk -v given="$2" -v base="$3" '
    /^Specialization of \x27/ { name = $3; in_section = 1; in_after = 0; mine = 0; ops = ""; bails = ""; jit = ""; next }
    !in_section { next }
    /^After:$/ { in_after = 1; next }
    match($0, /file: [^ ]*:[0-9]+\)/) { f = substr($0, RSTART + 6, RLENGTH - 7); sub(/:[0-9]+$/, "", f)
                                         if (f == given || f == base || substr(f, length(f) - length(base)) == "/" base) mine = 1 }
    in_after && /^      (readuint|writeint|writeuint|writenum) / { if (index(ops, " " $1 " ") == 0) ops = ops " " $1 " " }
    in_after && /BAIL: / { b = substr($0, index($0, "BAIL: ")); if (index(bails, b) == 0) bails = bails "; " b }
    /^JIT was successful/ { jit = "compiled" }
    /^JIT was not successful/ { jit = "not compiled" }
    /^========$/ { if (mine && ops != "") { gsub(/  +/, " ", ops); sub(/^ /, "", ops); sub(/ $/, "", ops)
                     print "jit: specialization of " name " holding " ops ": " (jit == "" ? "no JIT line" : jit) bails }
                   in_section = 0 }' "$1" | sort -u
}
one "$ONLY" "" "$@"
case $(basename "$P") in OB3-*)
  one "nojit.$ONLY" "MVM_JIT_DISABLE=1" "$@"
  spesh_log=$(mktemp /tmp/claude-1000/ob-spesh-log.XXXXXX) || exit 1
  one "jitlog.$ONLY" "MVM_SPESH_BLOCKING=1 MVM_SPESH_LOG=$spesh_log" "$@" > /dev/null
  f="$O/$name.jitlog.$ONLY.txt"
  evidence=$(jit_evidence "$spesh_log" "$P" "$(basename "$P")")
  { echo "---- jit evidence (MVM_SPESH_LOG)"; if [ -n "$evidence" ]; then echo "$evidence"; else echo "jit: no specialization of this file holds the op"; fi; } >> "$f"
  rm -f "${spesh_log:?}"
  echo "== $f"; cat "$f" ;;
esac
