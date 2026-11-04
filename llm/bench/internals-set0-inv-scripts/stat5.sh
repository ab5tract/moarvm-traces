#!/bin/bash
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo; export RAKULIB=lib
O=/tmp/claude-1000/inv/stat5; mkdir -p $O; : > $O/summary.txt
declare -a T=(
'use Test; plan 3000; for ^3000 { is-deeply sprintf("%+8.2f", 2.71), "   +2.71", "d$_" }'
'use Test; plan 3000; for ^3000 { ok True, "d$_" }'
'use Test; plan 300; for ^300 { subtest "t$_" => { plan 2; ok True; ok True } }'
'my $s=0; for ^3000 { $s += "-+0 ".comb.permutations>>.join.elems }; say $s'
'my $s=0; for ^6000 { $s += sprintf("%+8.2f", 2.71).chars }; say $s'
)
for t in "${T[@]}"; do
 for p in preflip-prefix tune-zig-prefix; do
  r=$(LD_LIBRARY_PATH=/tmp/claude-1000/$p/lib perf stat -e instructions:u -x, ./rakudo-m -e "$t" 2>&1 >/dev/null | awk -F, '/instructions/{printf "%.3fG", $1/1e9}')
  echo "${p%-prefix} $r  :: ${t:0:70}" | tee -a $O/summary.txt
 done
done
