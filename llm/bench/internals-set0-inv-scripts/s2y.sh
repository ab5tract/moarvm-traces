#!/bin/bash
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
B=/tmp/claude-1000/internals-base-prefix; H=/tmp/claude-1000/tune-zig-prefix
V=(--variant=base:$B/lib:$B/bin/hash-bench --variant=head:$H/lib:$H/bin/hash-bench)
O=/tmp/claude-1000/inv
rm -rf $O/s2g $O/s2h $O/s2i $O/s2j
tools/bench/hash-ab.sh --rounds=7 --runs=5 --sizes=4,16,32,63,64,65,16384 --nth=all --out=$O/s2g "${V[@]}" >$O/s2g.log 2>&1
tools/bench/hash-ab.sh --rounds=7 --runs=5 --sizes=4,16,32,63,64,65 --nth=all --out=$O/s2h "${V[@]}" >$O/s2h.log 2>&1
tools/bench/hash-ab.sh --rounds=7 --runs=5 --sizes=4,16,32,63,64,65,16384 --nth=threshold --out=$O/s2i "${V[@]}" >$O/s2i.log 2>&1
tools/bench/hash-ab.sh --rounds=7 --runs=5 --sizes=4,16,32,63,64,65,128,256,1024,16384 --nth=all --out=$O/s2j "${V[@]}" >$O/s2j.log 2>&1
for s in s2g s2h s2i s2j; do echo == $s; python3 $O/ratio.py $O/$s lookup_hit | sed -n 3,6p | cut -c1-700; done
