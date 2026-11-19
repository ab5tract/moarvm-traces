#!/bin/sh
# build-moar.sh NAME: make install in /tmp/claude-1000/cfix-src-NAME (prefix /tmp/claude-1000/cfix-NAME)
N=$1; L=/tmp/claude-1000/cfix-logs
cd /tmp/claude-1000/cfix-src-$N || exit 1
until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 20; done
echo "make start $(date '+%F %T %Z') load $(cut -d' ' -f1-3 /proc/loadavg)" > $L/$N-make.info
s=$(date +%s)
env -u LD_LIBRARY_PATH systemd-run --user --scope -q -p MemoryMax=8G make -j8 install > $L/$N-make.log 2>&1
rc=$?
echo "make exit $rc, $(( $(date +%s) - s )) s, end $(date '+%F %T %Z')" >> $L/$N-make.info
