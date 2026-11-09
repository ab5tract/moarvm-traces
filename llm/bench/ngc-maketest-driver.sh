#!/bin/sh
# ngc-maketest-driver.sh OUTDIR [project:prefix ...]: the Zig-native GC
# campaign's suites (copied from z017-maketest-driver.sh, re-pointed at the
# ng-* prefixes). Each project:prefix pair runs `make test` in the nqp or
# rakudo checkout with LD_LIBRARY_PATH=/tmp/claude-1000/ng-<prefix>/lib.
# Default (Task 1): nqp:c-stress nqp:f-stress rakudo:f-base rakudo:c-base.
# Writes OUTDIR/<project>-<prefix>.out, the sorted per-file verdict list
# OUTDIR/<project>-<prefix>.list and a line per run to OUTDIR/summary.tsv.
O=$1; [ $# -gt 0 ] && shift
[ -n "$O" ] || { echo "usage: ngc-maketest-driver.sh OUTDIR [project:prefix ...]" >&2; exit 64; }
specs=${*:-nqp:c-stress nqp:f-stress rakudo:f-base rakudo:c-base}
mkdir -p $O
NQP=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp
RAK=/home/longwalker/code/raku/x.core/zmoarz/rakudo
for spec in $specs; do
  proj=${spec%%:*}; p=${spec#*:}
  case $proj in nqp) dir=$NQP ;; rakudo) dir=$RAK ;; *) echo "unknown project $proj" >&2; exit 64 ;; esac
  until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 60; done
  l=$(cut -d' ' -f1 /proc/loadavg)
  lib=/tmp/claude-1000/ng-$p/lib
  [ -e $lib/libmoar.so ] || { echo "$lib/libmoar.so missing" >&2; exit 64; }
  s=$(date +%s)
  (cd $dir && LD_LIBRARY_PATH=$lib systemd-run --user --scope -q -p MemoryMax=8G make test) > $O/$proj-$p.out 2>&1
  rc=$?
  grep -E '^t/.* \.\.' $O/$proj-$p.out | sed -E 's/ \.+ / /; s/ +[0-9]+\/[0-9]+ *$//' | awk '{print $1, ($NF=="ok" ? "ok" : "notok")}' | sort > $O/$proj-$p.list
  printf '%s\t%s\texit %s\t%ss\tload %s\t%s\t%s\n' $proj $p $rc $(( $(date +%s)-s )) $l "$(grep -E '^Files=' $O/$proj-$p.out)" "$(grep -E '^Result' $O/$proj-$p.out)" | tee -a $O/summary.tsv
done
