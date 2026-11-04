#!/bin/bash
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo; export RAKULIB=lib
O=/tmp/claude-1000/inv/stat4; mkdir -p $O; : > $O/summary.txt
for p in preflip-prefix tune-zig-prefix; do
 for t in "--target=parse t/spec/S32-str/sprintf-f.t" "--target=optimize t/spec/S32-str/sprintf-f.t" "-e use\ v6.e.PREVIEW;use\ Test;plan\ 1;ok\ 1"; do
  r=$(eval "LD_LIBRARY_PATH=/tmp/claude-1000/$p/lib perf stat -e instructions:u -x, ./rakudo-m $t" 2>&1 >/dev/null | awk -F, '{printf "%.3fG", $1/1e9}')
  echo "$p | $t | $r" | tee -a $O/summary.txt
 done
done
