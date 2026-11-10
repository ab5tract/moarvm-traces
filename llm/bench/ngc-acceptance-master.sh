#!/bin/sh
# ngc Task 9: the acceptance stages, serial, in the brief's order (one background
# script, so nothing else timed runs beside it): the 48-cell oracle, the
# three-sided crc-getter A/B, the spectest, the suites (C and native, base and
# stress, interleaved), the full-cleanup runs on the four prefixes, the
# after-profile. Each stage's exit goes to OUT/master.log; a failing stage does
# not stop the later ones (their evidence is independent).
M=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
B=$M/traces/llm/bench
O=/tmp/claude-1000/ngc/acc
log() { echo "$(date '+%F %T %Z') $*" | tee -a $O/master.log; }
log "master start"
sh $B/ngc-oracle-driver.sh $O/oracle a b c > $O/oracle-driver.out 2>&1; log "oracle exit $?"
sh $B/ngc-crc-ab-driver.sh $O/crc > $O/crc-driver.out 2>&1; log "crc exit $?"
sh $B/ngc-spectest-driver.sh $O/spectest > $O/spectest-driver.out 2>&1; log "spectest exit $?"
sh $B/ngc-maketest-driver.sh $O/suites nqp:c-base nqp:n-base nqp:c-stress nqp:n-stress rakudo:c-base rakudo:n-base rakudo:c-stress rakudo:n-stress > $O/suites-driver.out 2>&1; log "suites exit $?"
mkdir -p $O/cleanup
for p in ng-c-base ng-n-base ng-c-stress ng-n-stress; do
  until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 60; done
  { echo "load $(cut -d' ' -f1 /proc/loadavg) $(date +%T)"; sh $M/tools/bench/gc/cleanup.sh --prefix=/tmp/claude-1000/$p --runs=20; echo "exit $?"; } > $O/cleanup/cleanup-$p.txt 2>&1
  log "cleanup $p: $(tail -1 $O/cleanup/cleanup-$p.txt)"
done
sh $B/ngc-profile-after-driver.sh > $O/profile-driver.out 2>&1; log "profile exit $?"
log "master end"
