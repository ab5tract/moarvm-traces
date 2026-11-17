#!/bin/sh
# run.sh NAME ARGS...: zig build ARGS --summary all after the load wait, into unit/NAME.txt
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM || exit 1
O=/tmp/claude-1000/va/t8/unit; n=$1; shift
{ echo "commit $(git rev-parse --short HEAD); zig build $* --summary all"; sh .superpowers/sdd/2026-11-16-zig-vmarray-repr/waitload.sh; } > $O/$n.txt 2>&1
rm -f src/gen/config.h src/gen/config.c src/gen/config.o
s=$(date +%s)
systemd-run --user --scope -q -p MemoryMax=8G zig build "$@" --summary all >> $O/$n.txt 2>&1
rc=$?; echo "exit $rc $(( $(date +%s)-s ))s" >> $O/$n.txt
echo "$n: exit $rc; $(grep 'Build Summary' $O/$n.txt)"
