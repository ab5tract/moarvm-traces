#!/bin/sh
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
O=/tmp/claude-1000/gc-t10-suites; mkdir -p $O
run() { name=$1; shift; until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 120; done; l=$(cut -d' ' -f1 /proc/loadavg); rm -f src/gen/config.h src/gen/config.c src/gen/config.o; s=$(date +%s); "$@" > $O/$name.out 2>&1; rc=$?; printf '%s\texit %s\t%ss\tload %s\tbytes %s\n' "$name" $rc $(( $(date +%s)-s )) $l $(wc -c < $O/$name.out) | tee -a $O/suites.tsv; }
run unit-test-0 zig build unit-test
run unit-test-0-summary zig build unit-test --summary all
run unit-test-1 zig build -Dgc-debug=1 unit-test
run unit-test-1-summary zig build -Dgc-debug=1 unit-test --summary all
run test-0 zig build test --prefix /tmp/claude-1000/gc-t10-check
run test-0-summary zig build test --prefix /tmp/claude-1000/gc-t10-check --summary all
run test-1 zig build -Dgc-debug=1 test --prefix /tmp/claude-1000/gc-t10-check
run test-1-summary zig build -Dgc-debug=1 test --prefix /tmp/claude-1000/gc-t10-check --summary all
run strategy-test zig build strategy-test -Dnqp-prefix=/tmp/claude-1000/tune-zig-prefix --summary all
run prove prove tools/bench/t/
run fmt zig fmt --check src/zig
run perl-c sh -c 'for f in tools/bench/t/*.t tools/bench/*.pl; do perl -c $f || exit 1; done'
run sh-n sh -c 'for f in tools/bench/gc/*.sh tools/bench/*.sh; do sh -n $f || exit 1; done'
run py-compile python3 -m py_compile tools/bench/timev.py
