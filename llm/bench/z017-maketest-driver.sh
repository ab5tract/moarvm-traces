#!/bin/sh
# z017-maketest-driver.sh OUTDIR: zig-017 Task 5 Step 5 (copied from
# gc-final-maketest-driver.sh, re-pointed at the 0.17 prefixes): nqp make test
# under g7-c-stress and g7-z-stress, rakudo make test under g7-z-base;
# per-file verdict lists.
O=$1
[ -n "$O" ] || { echo "usage: z017-maketest-driver.sh OUTDIR" >&2; exit 64; }
mkdir -p $O
NQP=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp
RAK=/home/longwalker/code/raku/x.core/zmoarz/rakudo
for spec in nqp:c-stress nqp:z-stress rakudo:z-base; do
  proj=${spec%%:*}; p=${spec#*:}
  case $proj in nqp) dir=$NQP ;; rakudo) dir=$RAK ;; esac
  until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 60; done
  l=$(cut -d' ' -f1 /proc/loadavg)
  lib=/tmp/claude-1000/g7-$p/lib
  s=$(date +%s)
  (cd $dir && LD_LIBRARY_PATH=$lib systemd-run --user --scope -q -p MemoryMax=8G make test) > $O/$proj-$p.out 2>&1
  rc=$?
  grep -E '^t/.* \.\.' $O/$proj-$p.out | sed -E 's/ \.+ / /; s/ +[0-9]+\/[0-9]+ *$//' | awk '{print $1, ($NF=="ok" ? "ok" : "notok")}' | sort > $O/$proj-$p.list
  printf '%s\t%s\texit %s\t%ss\tload %s\t%s\t%s\n' $proj $p $rc $(( $(date +%s)-s )) $l "$(grep -E '^Files=' $O/$proj-$p.out)" "$(grep -E '^Result' $O/$proj-$p.out)" | tee -a $O/summary.tsv
done
