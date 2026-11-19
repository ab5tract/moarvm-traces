#!/bin/sh
# cfix-mirror: the gate prefixes, one at a time (va-prefixes-raw/build.sh
# with this task's names and output directory). Arguments: "<name> <options>" ...
M=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
O=$M/traces/llm/bench/cfix-mirror-raw/build; mkdir -p $O
cd $M || exit 1
for l in "$@"; do echo "$l"; done | while read name opts; do
  until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do echo "$name: load $(cut -d' ' -f1 /proc/loadavg), waiting" >> $O/builds.log; sleep 60; done
  l=$(cut -d' ' -f1 /proc/loadavg)
  rm -f src/gen/config.h src/gen/config.c src/gen/config.o
  s=$(date +%s)
  systemd-run --user --scope -q -p MemoryMax=8G zig build install --prefix /tmp/claude-1000/$name $opts > $O/$name.out 2>&1
  rc=$?
  t=$(( $(date +%s) - s ))
  v=$(/tmp/claude-1000/$name/bin/moar --version 2>&1)
  printf '%s\t%s\texit %s\t%ss\tload %s\tcommit %s\topts %s\t%s\n' "$(date '+%F %T %Z')" $name $rc $t $l "$(git rev-parse --short HEAD)" "$opts" "$v" | tee -a $O/builds.tsv
  [ $rc = 0 ] || exit 1
done
