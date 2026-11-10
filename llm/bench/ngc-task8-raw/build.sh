#!/bin/sh
# ngc Task 8: the three native prefixes, one at a time, from b0b3a48d6 (build9.sh's recipe).
M=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
O=/tmp/claude-1000/ngc/t8; mkdir -p $O
cd $M || exit 1
while read name opts; do
  until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do echo "$name: load $(cut -d' ' -f1 /proc/loadavg), waiting" >> $O/builds.log; sleep 60; done
  l=$(cut -d' ' -f1 /proc/loadavg)
  rm -f src/gen/config.h src/gen/config.c src/gen/config.o
  s=$(date +%s)
  systemd-run --user --scope -q -p MemoryMax=8G zig build install --prefix /tmp/claude-1000/$name $opts > $O/$name.out 2>&1
  rc=$?
  t=$(( $(date +%s) - s ))
  v=$(/tmp/claude-1000/$name/bin/moar --version 2>&1)
  printf '%s\texit %s\t%ss\tload %s\topts %s\t%s\n' $name $rc $t $l "$opts" "$v" | tee -a $O/builds.tsv
  [ $rc = 0 ] || exit 1
done <<LIST
ng-n-oracle -Dgc-debug=1
ng-n-base
ng-n-stress -Dgc-debug=1 -Dnursery-size=524288
LIST
