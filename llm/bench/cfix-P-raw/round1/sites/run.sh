#!/bin/sh
# run.sh PREFIX: each snippet under PREFIX's libmoar, 2G cap, 60 s
p=$1; out=/tmp/claude-1000/t3/r1/$p; mkdir -p $out
pre=; case $p in *-asan) pre="LD_PRELOAD=/usr/lib/libasan.so.8 ASAN_OPTIONS=detect_leaks=0:abort_on_error=0:symbolize=1" ;; esac
while IFS='	' read -r name code; do
  ( ulimit -c 0; env -u LD_PRELOAD LD_LIBRARY_PATH=/tmp/claude-1000/$p/lib $pre timeout -k 5 60 systemd-run --user --scope -q -p MemoryMax=2G -p MemorySwapMax=0 /tmp/claude-1000/cfix-base/bin/rakudo-m -e "$code" ) > $out/$name.txt 2>&1
  echo "exit: $?" >> $out/$name.txt
  printf '%-22s %s\n' "$name" "$(grep -v '^ *#\|^ *in \|^$' $out/$name.txt | grep -m1 -E 'DIED|Can only|exit|Error|SEGV|alloc|^[A-Za-z]' | cut -c1-110) | $(tail -1 $out/$name.txt)"
done < /tmp/claude-1000/t3/r1/snippets.txt
