#!/bin/sh
# Wait until the 1-minute load is below 2.0 (polled every 60 s); print it.
until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do echo "load $(cut -d' ' -f1 /proc/loadavg), waiting" >&2; sleep 60; done
echo "load $(cut -d' ' -f1-3 /proc/loadavg) at $(date '+%F %T')"
