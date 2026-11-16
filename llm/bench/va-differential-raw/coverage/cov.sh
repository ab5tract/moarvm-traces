#!/bin/sh
# cov.sh NAME PROGRAM-KEY [ENV=VAL ...]: one program under gdb on va-c-syms,
# a breakpoint on every line of VMArray.c that has code.
S=$(cd "$(dirname "$0")" && pwd)
name=$1 key=$2; shift 2
case $key in
  diff-nqp)  cmd="/tmp/claude-1000/tune-zig-prefix/bin/nqp-m tools/bench/repr/vmarray-diff.nqp" ;;
  diff-raku) cmd="/home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m tools/bench/repr/vmarray-diff.raku" ;;
  serial)    cmd="/tmp/claude-1000/tune-zig-prefix/bin/nqp-m tools/bench/repr/vmarray-serial.nqp" ;;
  devirt)    cmd="/tmp/claude-1000/tune-zig-prefix/bin/nqp-m tools/bench/repr/vmarray-devirt.nqp" ;;
  serial-read) cmd="/tmp/claude-1000/tune-zig-prefix/bin/nqp-m tools/bench/repr/vmarray-serial.nqp --read=$S/s1.out" ;;
esac
sed "s|COVOUT|\"$S/cov-$name.txt\"|" $S/cov.py > $S/cov-$name.py
rm -f $S/cov-$name.txt
s=$(date +%s)
env LD_LIBRARY_PATH=/tmp/claude-1000/va-c-syms/lib RAKUDO_NO_PRECOMPILATION=1 "$@" \
  systemd-run --user --scope -q -p MemoryMax=8G timeout 3000 gdb -q -batch -x $S/cov-$name.py --args $cmd > $S/cov-$name.out 2> $S/cov-$name.err
echo "$name: exit $? $(( $(date +%s) - s ))s; $(grep -c '^HIT' $S/cov-$name.txt) lines hit, $(grep -c '^MISS' $S/cov-$name.txt) missed"
