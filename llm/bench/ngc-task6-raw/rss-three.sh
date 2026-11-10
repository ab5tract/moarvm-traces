#!/bin/sh
# ngc Task 6, spec 8 h evidence: peak RSS of the three-thread full-cleanup
# program (tools/bench/gc/cleanup/three.nqp, --full-cleanup), ng-c-base against
# ng-n-base, ROUNDS rounds (default 3) x 10 runs per side, side order rotated per
# round, load < 2.0 before every run. One line per run to OUT/runs.tsv:
#   round side run exit maxrss_kB wall load last_line
# (timev.py, the GNU time -v stand-in ab.sh uses)
M=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
out=$1; rounds=${2:-3}
[ -n "$out" ] || { echo "usage: rss-three.sh OUT [rounds]" >&2; exit 64; }
mkdir -p "$out"
lib=/tmp/claude-1000/tune-zig-prefix/share/nqp/lib
for r in $(seq 1 $rounds); do
  if [ $((r % 2)) = 1 ]; then sides="ng-c-base ng-n-base"; else sides="ng-n-base ng-c-base"; fi
  for s in $sides; do
    for k in $(seq 1 10); do
      until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 60; done
      l=$(cut -d' ' -f1 /proc/loadavg)
      LD_LIBRARY_PATH=/tmp/claude-1000/$s/lib systemd-run --user --scope -q -p MemoryMax=8G \
        python3 $M/tools/bench/timev.py "$out/$s-r$r-$k.time" timeout 60 /tmp/claude-1000/$s/bin/moar --full-cleanup \
        --libpath=$lib $lib/nqp.moarvm $M/tools/bench/gc/cleanup/three.nqp > "$out/$s-r$r-$k.out" 2>&1
      rc=$?
      rss=$(sed -n 's/.*Maximum resident set size (kbytes): //p' "$out/$s-r$r-$k.time")
      wall=$(sed -n 's/.*Elapsed (wall clock) time (h:mm:ss or m:ss): //p' "$out/$s-r$r-$k.time")
      last=$(tail -1 "$out/$s-r$r-$k.out")
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' $r $s $k $rc "$rss" "$wall" $l "$last" >> "$out/runs.tsv"
    done
  done
done
