#!/bin/sh
# Rebuild the three g7-c-* prefixes as C collector + Zig hash engine from the scratch copy.
T=/tmp/claude-1000/z017/cgc-tree
O=/tmp/claude-1000/z017/t5/builds-cgc; mkdir -p $O
cd $T || exit 1
while read name opts; do
  until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do echo "$name: load $(cut -d' ' -f1 /proc/loadavg), waiting" >> $O/builds.log; sleep 60; done
  l=$(cut -d' ' -f1 /proc/loadavg)
  rm -f src/gen/config.h src/gen/config.c src/gen/config.o
  rm -rf /tmp/claude-1000/$name
  s=$(date +%s)
  systemd-run --user --scope -q -p MemoryMax=8G zig build install --prefix /tmp/claude-1000/$name $opts > $O/$name.out 2>&1
  rc=$?
  t=$(( $(date +%s) - s ))
  v=$(/tmp/claude-1000/$name/bin/moar --version 2>&1)
  printf '%s\texit %s\t%ss\tload %s\topts %s\t%s\n' $name $rc $t $l "$opts" "$v" | tee -a $O/builds.tsv
  [ $rc = 0 ] || exit 1
done <<LIST
g7-c-oracle -Dgc-debug=1
g7-c-base
g7-c-stress -Dgc-debug=1 -Dnursery-size=524288
LIST
