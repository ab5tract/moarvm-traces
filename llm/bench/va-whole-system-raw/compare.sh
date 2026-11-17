#!/bin/sh
# va fix wave, part B: compare the .moarvm files of two nqp builds made by
# build-nqp.sh. Usage: compare.sh A B (names under /tmp/claude-1000/va-ws/out).
# Prints one line per file present in either: "same", or "differs size A/B
# first differing byte at offset N (0-based)", or "only in A/B"; then counts.
W=/tmp/claude-1000/va-ws/out; A=$W/$1/files; B=$W/$2/files
same=0; diff=0; only=0
{ (cd $A && find . -name '*.moarvm'); (cd $B && find . -name '*.moarvm'); } | sort -u | while read f; do
  if [ ! -f "$A/$f" ] || [ ! -f "$B/$f" ]; then echo "$f only in $( [ -f "$A/$f" ] && echo $1 || echo $2 )"; continue; fi
  if cmp -s "$A/$f" "$B/$f"; then echo "$f same $(stat -c %s "$A/$f")"; else
    first=$(cmp "$A/$f" "$B/$f" 2>/dev/null | sed -n 's/.* byte \([0-9]*\),.*/\1/p')
    echo "$f differs size $(stat -c %s "$A/$f")/$(stat -c %s "$B/$f") first-differing-offset $((first - 1)) differing-bytes $(cmp -l "$A/$f" "$B/$f" 2>/dev/null | wc -l)"
  fi
done
