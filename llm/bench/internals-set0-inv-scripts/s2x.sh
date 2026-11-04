#!/bin/bash
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
B=/tmp/claude-1000/internals-base-prefix; H=/tmp/claude-1000/tune-zig-prefix
V=(--variant=base:$B/lib:$B/bin/hash-bench --variant=head:$H/lib:$H/bin/hash-bench)
O=/tmp/claude-1000/inv
rm -rf $O/s2d $O/s2e $O/s2f
tools/bench/hash-ab.sh --rounds=7 --runs=5 --sizes=4,16,32,63,64,65,128,256,1024,16384 --nth=threshold --out=$O/s2d "${V[@]}" >$O/s2d.log 2>&1
tools/bench/hash-ab.sh --rounds=7 --runs=20 --sizes=65 --nth=threshold --out=$O/s2e "${V[@]}" >$O/s2e.log 2>&1
tools/bench/hash-ab.sh --rounds=7 --runs=5 --sizes=4,16,32,63,64,65,66,128,256,1024,16384 --nth=threshold --out=$O/s2f "${V[@]}" >$O/s2f.log 2>&1
for s in s2d s2e s2f; do echo == $s; python3 $O/ratio.py $O/$s lookup_hit | cut -c1-600; done
