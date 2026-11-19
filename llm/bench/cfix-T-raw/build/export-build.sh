#!/bin/sh
# export-build.sh BRANCH NAME [CONFIGURE ARGS...]: git archive BRANCH (and the
# 3rdparty submodules at their recorded commits) into /tmp/claude-1000/cfix-src-NAME,
# Configure.pl --prefix=/tmp/claude-1000/cfix-NAME ARGS, then make -j8 install
# under MemoryMax=8G once the 1-minute load is below 2.0.
B=$1; N=$2; shift 2
P=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM; L=/tmp/claude-1000/cfix-logs
D=/tmp/claude-1000/cfix-src-$N
[ -e $D ] && { echo "$D exists" >&2; exit 1; }
mkdir -p $D; cd $P || exit 1
git archive $B | tar -x -C $D
for m in $(git ls-tree $B 3rdparty/ | awk '$2=="commit"{print $4}'); do
  mkdir -p $D/$m; git -C $m archive HEAD | tar -x -C $D/$m
done
cd $D || exit 1
env -u LD_LIBRARY_PATH perl Configure.pl "$@" --prefix=/tmp/claude-1000/cfix-$N > $L/$N-configure.log 2>&1 || { echo configure failed; exit 1; }
until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 20; done
echo "make start $(date '+%F %T %Z') load $(cut -d' ' -f1-3 /proc/loadavg)" > $L/$N-make.info
s=$(date +%s)
env -u LD_LIBRARY_PATH systemd-run --user --scope -q -p MemoryMax=8G make -j8 install > $L/$N-make.log 2>&1
rc=$?
echo "make exit $rc, $(( $(date +%s) - s )) s, end $(date '+%F %T %Z')" >> $L/$N-make.info
cat $L/$N-make.info
