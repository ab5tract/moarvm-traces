#!/bin/sh
# va-evidence-master.sh ROOT: the VMArray campaign's Task 8 evidence after the
# unit tests and the differential, one stage at a time (nothing overlaps):
#   1 oracle      va-oracle-driver.sh ROOT/oracle
#   2 suites      va-maketest-driver.sh ROOT/suites (nqp and rakudo make test on
#                 va-{c,n}-base, rakudo make test on va-{c,n}-stress)
#   3 stress      crc-getter.raku --volume=100000 --runs=5 under va-{c,n}-stress,
#                 three runs a side, alternating (ROOT/stress)
#   4 cleanup     tools/bench/gc/cleanup.sh --runs=20 (each run under its own MemoryMax=8G scope) on va-{c,n}-base, with
#                 --stress on va-{c,n}-stress (ROOT/cleanup)
#   5 heap        the heap snapshot of va-switch-on-raw/t7-heap.sh, twice a
#                 side, each after a libmoar probe (ROOT/heap)
#   6 spectest    va-spectest-driver.sh ROOT/spectest
#   7 crc-ab      va-crc-ab-driver.sh ROOT/crc-ab
# Each stage's start, end and exit go to ROOT/master.log; the load is waited
# for (< 2.0, polled every 60 s) by the stage itself before every run.
R=$1
[ -n "$R" ] || { echo "usage: va-evidence-master.sh ROOT" >&2; exit 64; }
mkdir -p "$R"
B=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM/traces/llm/bench
M=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
RK=/home/longwalker/code/raku/x.core/zmoarz/rakudo
stages=${STAGES:-oracle suites stress cleanup heap spectest crc-ab}
log() { echo "$(date '+%F %T') $*" | tee -a "$R/master.log"; }
waitload() { until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 60; done; cut -d' ' -f1 /proc/loadavg; }
scrub=$(env | sed -n 's/^\(\(MVM_\|RAKUDO_\|NQP_\|RAKU_\|PERL6\)[A-Za-z0-9_]*\|RAKULIB\)=.*/-u \1/p')
probe='say "/proc/self/maps".IO.lines.first(*.contains("libmoar")).words[*-1]'
for st in $stages; do
  log "$st start; raku: $(pgrep -a -x raku | wc -l) moar: $(pgrep -a -x moar | wc -l); load $(cut -d' ' -f1-3 /proc/loadavg)"
  case $st in
    oracle)  sh $B/va-oracle-driver.sh "$R/oracle" > "$R/oracle.log" 2>&1; rc=$? ;;
    suites)  sh $B/va-maketest-driver.sh "$R/suites" > "$R/suites.log" 2>&1; rc=$? ;;
    stress)
      mkdir -p "$R/stress"; rc=0
      for i in 1 2 3; do for s in c n; do
        P=/tmp/claude-1000/va-$s-stress
        l=$(waitload)
        # shellcheck disable=SC2086
        m=$(cd $M && env $scrub LD_LIBRARY_PATH=$P/lib $RK/rakudo-m -e "$probe" 2>&1)
        # shellcheck disable=SC2086
        (cd $M && env $scrub LD_LIBRARY_PATH=$P/lib RAKULIB=$M/tools/bench/gc/lib,$RK/lib systemd-run --user --scope -q -p MemoryMax=8G \
            python3 tools/bench/timev.py "$R/stress/$s-$i.time" $RK/rakudo-m tools/bench/gc/crc-getter.raku --volume=100000 --runs=5) \
            > "$R/stress/$s-$i.out" 2>&1
        r=$?; [ $r = 0 ] || rc=1
        printf '%s\t%s\t%s\texit %s\tload %s\tmaps %s\t%s\n' "$(date '+%F %T')" va-$s-stress $i $r $l "$m" "$(tail -1 "$R/stress/$s-$i.out")" | tee -a "$R/stress/runs.tsv"
      done; done ;;
    cleanup)
      mkdir -p "$R/cleanup"; rc=0
      for spec in "c-base:" "n-base:" "c-stress:--stress" "n-stress:--stress"; do
        p=${spec%%:*}; f=${spec#*:}
        l=$(waitload)
        (cd $M && sh tools/bench/gc/cleanup.sh --prefix=/tmp/claude-1000/va-$p --runs=20 $f) > "$R/cleanup/$p.out" 2>&1
        r=$?; [ $r = 0 ] || rc=1
        printf '%s\tva-%s\t%s\texit %s\tload %s\t%s\n' "$(date '+%F %T')" $p "$f" $r $l "$(tail -1 "$R/cleanup/$p.out")" | tee -a "$R/cleanup/runs.tsv"
      done ;;
    heap)
      mkdir -p "$R/heap"; rc=0
      for i in 1 2; do for s in c n; do
        P=/tmp/claude-1000/va-$s-base
        l=$(waitload)
        # shellcheck disable=SC2086
        m=$(env $scrub LD_LIBRARY_PATH=$P/lib $RK/rakudo-m -e "$probe" 2>&1)
        # shellcheck disable=SC2086
        env $scrub LD_LIBRARY_PATH=$P/lib systemd-run --user --scope -q -p MemoryMax=8G timeout 900 $RK/rakudo-m --profile=heap --profile-filename="$R/heap/$s-$i.mvmheap" -e 'my @a = 1..1000; my int @b = 1..1000; say @a.elems + @b.elems' > "$R/heap/$s-$i.out" 2> "$R/heap/$s-$i.err"
        r=$?; [ $r = 0 ] || rc=1
        printf '%s\tva-%s-base\t%s\texit %s\tload %s\tmaps %s\tstdout %s\tstderr %s bytes\tsnapshot %s bytes\n' "$(date '+%F %T')" $s $i $r $l "$m" "$(cat "$R/heap/$s-$i.out")" "$(wc -c < "$R/heap/$s-$i.err")" "$(wc -c < "$R/heap/$s-$i.mvmheap" 2>/dev/null || echo none)" | tee -a "$R/heap/runs.tsv"
      done; done ;;
    spectest) sh $B/va-spectest-driver.sh "$R/spectest" > "$R/spectest.log" 2>&1; rc=$? ;;
    crc-ab)  sh $B/va-crc-ab-driver.sh "$R/crc-ab" > "$R/crc-ab.log" 2>&1; rc=$? ;;
    *) log "unknown stage $st"; exit 64 ;;
  esac
  log "$st end exit $rc"
done
log "all done"
