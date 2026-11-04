#!/bin/bash
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo; export RAKULIB=lib
O=/tmp/claude-1000/inv/stat3; mkdir -p $O
for p in internals-base-prefix preflip-prefix tune-zig-prefix; do
 for t in 'say 1' 'my $s=0; for ^300 { $s += sprintf("%.3f", $_ * 1.1).chars }; say $s' 'my %h; %h{$_} = $_ for ^200; my $s=0; for ^20000 { $s += %h{$_ % 200} }; say $s'; do
  r=$(LD_LIBRARY_PATH=/tmp/claude-1000/$p/lib perf stat -e instructions:u -x, ./rakudo-m -e "$t" 2>&1 >/dev/null | awk -F, '{printf "%.3fG", $1/1e9}')
  echo "$p | $t | $r" | tee -a $O/summary.txt
 done
done
