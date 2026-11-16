#!/bin/sh
# Reproduces the hit counts of va-adoption-audit.md. Run from the MoarVM
# checkout root: sh traces/llm/bench/va-adoption-audit-raw/greps.sh
# Writes g1.txt, g2.txt, g3.txt next to itself and prints the counts.
set -eu
out=$(dirname "$0")
inc="--include=*.c --include=*.h --include=*.dasc"

# G1: the brief's assignment grep, all of src.
grep -rnE 'slots\.[a-z0-9]+ *=[^=]|\.ssize *=[^=]|->ssize *=[^=]|body\.start *=[^=]|body\.elems *=[^=]' \
    src $inc > "$out/g1.txt" || true
# G2: the brief's free grep.
grep -rnE 'MVM_free\([^)]*slots\.' src $inc > "$out/g2.txt" || true
# G3: supplementary. G1 misses `p->start =` and `p->elems =` through an
# MVMArrayBody pointer, so: every assignment to start/elems/ssize/slots.*
# through `.` or `->`, in each file that names MVMArray or MVMArrayBody,
# except VMArray.[ch] and MultiDimArray.[ch].
files=$(grep -rlE '\bMVMArray\b|\bMVMArrayBody\b' src $inc \
        | grep -vE '^src/6model/reprs/(VMArray|MultiDimArray)\.[ch]$' | sort)
grep -nE '(\.|->)(start|elems|ssize|slots\.[a-z0-9]+) *=[^=]' $files > "$out/g3.txt" || true

c() { wc -l < "$1" | tr -d ' '; }
echo "G1 all:                 $(c "$out/g1.txt")"
echo "G1 in VMArray.c:        $(grep -c '^src/6model/reprs/VMArray.c:' "$out/g1.txt")"
echo "G1 in MultiDimArray.c:  $(grep -c '^src/6model/reprs/MultiDimArray.c:' "$out/g1.txt")"
echo "G2 all:                 $(c "$out/g2.txt")"
echo "G2 in VMArray.c:        $(grep -c '^src/6model/reprs/VMArray.c:' "$out/g2.txt")"
echo "G2 in MultiDimArray.c:  $(grep -c '^src/6model/reprs/MultiDimArray.c:' "$out/g2.txt")"
echo "G3 files searched:      $(echo "$files" | wc -l | tr -d ' ')"
echo "G3 all:                 $(c "$out/g3.txt")"
echo "G3 MVMString strands:   $(grep -c 'strands\[0\]\.start\|ss_[a-z]*->start' "$out/g3.txt")"
echo "G3 not in G1:           $(grep -vxFf "$out/g1.txt" "$out/g3.txt" | grep -vc 'strands\[0\]\.start\|ss_[a-z]*->start')"
grep -vxFf "$out/g1.txt" "$out/g3.txt" | grep -v 'strands\[0\]\.start\|ss_[a-z]*->start' | sed 's/^/  G3-only: /'
