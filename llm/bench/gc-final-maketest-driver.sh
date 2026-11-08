#!/bin/sh
# nqp and rakudo make test under each collector; per-file verdict lists.
O=/tmp/claude-1000/gc-t10-maketest; mkdir -p $O
NQP=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp
RAK=/home/longwalker/code/raku/x.core/zmoarz/rakudo
for spec in nqp:c-base nqp:z-base rakudo:c-base rakudo:z-base nqp:c-stress nqp:z-stress rakudo:c-stress rakudo:z-stress; do
  proj=${spec%%:*}; p=${spec#*:}
  case $proj in nqp) dir=$NQP ;; rakudo) dir=$RAK ;; esac
  until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 120; done
  l=$(cut -d' ' -f1 /proc/loadavg)
  lib=/tmp/claude-1000/gc-$p/lib
  s=$(date +%s)
  (cd $dir && LD_LIBRARY_PATH=$lib make test) > $O/$proj-$p.out 2>&1
  rc=$?
  grep -E '^t/.* \.\.' $O/$proj-$p.out | sed -E 's/ \.+ / /; s/ +[0-9]+\/[0-9]+ *$//' | awk '{print $1, ($NF=="ok" ? "ok" : "notok")}' | sort > $O/$proj-$p.list
  printf '%s\t%s\texit %s\t%ss\tload %s\t%s\t%s\n' $proj $p $rc $(( $(date +%s)-s )) $l "$(grep -E '^Files=' $O/$proj-$p.out)" "$(grep -E '^Result' $O/$proj-$p.out)" | tee -a $O/summary.tsv
done
