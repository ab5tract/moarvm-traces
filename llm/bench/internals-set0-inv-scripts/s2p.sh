#!/bin/bash
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
O=/tmp/claude-1000/inv/perf; mkdir -p $O
P=/tmp/claude-1000
for v in base head; do
  if [ $v = base ]; then pre=$P/internals-base-prefix; else pre=$P/tune-zig-prefix; fi
  export LD_LIBRARY_PATH=$pre/lib
  H=$P/tune-zig-prefix
  # (i) the brief's: nqp --sizes=65 --runs=20 ; (ii) the nth=all sequence ; (iii) capi at 65
  perf record -g -o $O/nqp65-$v.data -- $H/bin/nqp-m tools/bench/hash-bench.nqp --engine=$v --sizes=65 --runs=20 --nth=threshold > $O/nqp65-$v.out 2>$O/nqp65-$v.err
  perf record -g -o $O/nqpseq-$v.data -- $H/bin/nqp-m tools/bench/hash-bench.nqp --engine=$v --sizes=4,16,32,63,64,65 --runs=20 --nth=all > $O/nqpseq-$v.out 2>$O/nqpseq-$v.err
  perf record -g -o $O/capi65-$v.data -- $pre/bin/hash-bench --sizes=65 --runs=20 --nth=threshold > $O/capi65-$v.out 2>$O/capi65-$v.err
  for k in nqp65 nqpseq capi65; do
    perf report -i $O/$k-$v.data --no-children --sort symbol --stdio -g none 2>/dev/null | grep -v '^#' | grep -v '^$' | head -15 > $O/$k-$v.top
  done
done
unset LD_LIBRARY_PATH
echo done
