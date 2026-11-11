#!/bin/sh
# cb-oracle-driver.sh OUTROOT [groups]: the call-boundary campaign's oracle
# matrix (copied from ngc-oracle-driver.sh, re-pointed at the cb-n-* prefixes;
# groups b and c dropped).
# Groups: a = ng-c-oracle vs cb-n-oracle (the C control vs the native collector at the cb tip),
#         s = ng-c-stress vs cb-n-stress (the same at the 512 KiB nursery, -Dgc-debug=1).
# Default groups "a s". VOLUMES (environment, default "10000 100000") narrows the volumes.
# Each: volumes x {plain, --bad-packages} x tier {1,2} (8 cells per group at both volumes).
# One line per cell to OUTROOT/matrix.tsv:
#   group volume set tier exit seconds load_before lines raw_cmp
# raw_cmp is "same" when cmp of the raw base-1.log and head-1.log is empty, else "differ".
# Exit 0 when every cell exits 0 with identical raw logs, 1 otherwise.
case $1 in --help|-h) sed -n '2,/^# Exit/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
out=$1; [ $# -gt 0 ] && shift
groups=${*:-a s}
[ -n "$out" ] || { echo "usage: cb-oracle-driver.sh OUTROOT [groups]" >&2; exit 64; }
[ -e "$out" ] && { echo "$out exists" >&2; exit 64; }
mkdir -p "$out"
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM || exit 1
bad_cells=0
for g in $groups; do
  case $g in
    a) B=/tmp/claude-1000/ng-c-oracle; H=/tmp/claude-1000/cb-n-oracle ;;
    s) B=/tmp/claude-1000/ng-c-stress; H=/tmp/claude-1000/cb-n-stress ;;
    *) echo "unknown group $g" >&2; exit 64 ;;
  esac
  for v in ${VOLUMES:-10000 100000}; do
    for b in plain bad; do
      for t in 1 2; do
        until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 60; done
        l=$(cut -d' ' -f1 /proc/loadavg)
        if [ $b = bad ]; then flag=--bad-packages; else flag=; fi
        c=$g-v$v-$b-t$t
        s0=$(date +%s)
        systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/oracle.sh --base=$B --head=$H --volume=$v $flag --tier=$t --out="$out/$c" > "$out/$c.stderr" 2>&1
        rc=$?
        s1=$(date +%s)
        n=$(wc -l < "$out/$c/base-1.log" 2>/dev/null || echo 0)
        if cmp -s "$out/$c/base-1.log" "$out/$c/head-1.log"; then raw=same; else raw=differ; fi
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' $g $v $b $t $rc $((s1 - s0)) $l $n $raw | tee -a "$out/matrix.tsv"
        { [ $rc = 0 ] && [ $raw = same ]; } || bad_cells=$((bad_cells + 1))
      done
    done
  done
done
[ $bad_cells = 0 ] || { echo "$bad_cells cell(s) not identical" | tee -a "$out/matrix.tsv"; exit 1; }
