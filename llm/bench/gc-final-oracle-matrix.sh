#!/bin/sh
# final-oracle.sh OUTROOT: Task 10 Step 1, gc-c-oracle against gc-z-oracle (HEAD),
# volumes 10000 and 100000 x {plain, --bad-packages} x tier {1,2}.
# One line per cell to OUTROOT/matrix.tsv: volume set tier exit seconds load_before lines.
out=$1
[ -n "$out" ] || { echo "usage: final-oracle.sh OUTROOT" >&2; exit 64; }
[ -e "$out" ] && { echo "$out exists" >&2; exit 64; }
mkdir -p "$out"
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
B=/tmp/claude-1000/gc-c-oracle
H=/tmp/claude-1000/gc-z-oracle
for v in 10000 100000; do
  for b in plain bad; do
    for t in 1 2; do
      until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 120; done
      l=$(cut -d' ' -f1 /proc/loadavg)
      if [ $b = bad ]; then flag=--bad-packages; else flag=; fi
      s0=$(date +%s)
      sh tools/bench/gc/oracle.sh --base=$B --head=$H --volume=$v $flag --tier=$t --out="$out/v$v-$b-t$t" > "$out/v$v-$b-t$t.stderr" 2>&1
      rc=$?
      s1=$(date +%s)
      n=$(wc -l < "$out/v$v-$b-t$t/base-1.log" 2>/dev/null || echo 0)
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' $v $b $t $rc $((s1 - s0)) $l $n | tee -a "$out/matrix.tsv"
    done
  done
done
