#!/bin/sh
# va Task 1 Step 6: the three control prefixes (C array), one at a time,
# from the -Dzig-reprs commit. Arguments, if given, replace the list:
#   build.sh "<name> <options>" ...
M=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
O=/tmp/claude-1000/va/builds; mkdir -p $O
cd $M || exit 1
list() {
  if [ $# -gt 0 ]; then for l in "$@"; do echo "$l"; done; else cat <<LIST
va-c-oracle -Dzig-reprs=false -Dgc-debug=1
va-c-base -Dzig-reprs=false
va-c-stress -Dzig-reprs=false -Dgc-debug=1 -Dnursery-size=524288
LIST
  fi
}
list "$@" | while read name opts; do
  until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do echo "$name: load $(cut -d' ' -f1 /proc/loadavg), waiting" >> $O/builds.log; sleep 60; done
  l=$(cut -d' ' -f1 /proc/loadavg)
  rm -f src/gen/config.h src/gen/config.c src/gen/config.o
  s=$(date +%s)
  systemd-run --user --scope -q -p MemoryMax=8G zig build install --prefix /tmp/claude-1000/$name $opts > $O/$name.out 2>&1
  rc=$?
  t=$(( $(date +%s) - s ))
  v=$(/tmp/claude-1000/$name/bin/moar --version 2>&1)
  printf '%s\t%s\texit %s\t%ss\tload %s\topts %s\t%s\n' "$(date '+%F %T %Z')" $name $rc $t $l "$opts" "$v" | tee -a $O/builds.tsv
  [ $rc = 0 ] || exit 1
done
