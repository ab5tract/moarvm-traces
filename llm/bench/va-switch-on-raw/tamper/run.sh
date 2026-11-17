#!/bin/sh
# Tamper checks of diff.sh's two Task 7 fixes, --compare-only on copies of
# the control's self-comparison (W/diff-self-fix1).
set -u
M=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
W=$M/.superpowers/sdd/2026-11-16-zig-vmarray-repr
T=$W/t7-tamper
fresh() { rm -rf "$T/$1"; cp -r "$W/diff-self-fix1" "$T/$1"; }
check() { "$M/tools/bench/repr/diff.sh" --compare-only --out="$T/$1" > "$T/$1.log" 2>&1; echo "$1: exit $? (expected $2)"; }
# 0. untouched
fresh plain; check plain 0
# 1. the head's diff-nqp spesh outputs lose their final newline
fresh nonl
for i in 1 2 3; do f=$T/nonl/head-diff-nqp-spesh-$i.out; head -c -1 "$f" > "$f.t" && mv "$f.t" "$f"; done
check nonl 1
# 1b. only run 1 of one side: not repeatable, and the message must say why
fresh nonl2
f=$T/nonl2/head-diff-nqp-spesh-1.out; head -c -1 "$f" > "$f.t" && mv "$f.t" "$f"
check nonl2 2
# 2. every listed diff-nqp line of the head replaced by the memmove model
fresh mm
names=$(grep '^diff-nqp ' "$M/tools/bench/repr/undefined-lines.txt" | cut -d' ' -f2)
printf '%s\n' "$names" | xargs -d '\n' python3 "$T/emit.py" > "$T/mm-lines.txt"
for i in 1 2 3; do python3 "$T/subst.py" "$T/mm-lines.txt" "$T/mm/head-diff-nqp-spesh-$i.out"; done
check mm 3
# 3. as 2, but one line of the head off the model (one element changed)
fresh mmbad
sed 's/^\(i32\.selfsplice\.middle: elems=20 \[\)1 /\199 /' "$T/mm-lines.txt" > "$T/mmbad-lines.txt"
for i in 1 2 3; do python3 "$T/subst.py" "$T/mmbad-lines.txt" "$T/mmbad/head-diff-nqp-spesh-$i.out"; done
check mmbad 1
# 4. as 2, plus a listed diff-raku line changed (no model for it)
fresh mmraku
for i in 1 2 3; do
    python3 "$T/subst.py" "$T/mm-lines.txt" "$T/mmraku/head-diff-nqp-spesh-$i.out"
    sed -i 's/^\(int8\.nqp\.splice\.self: \).*/\1elems=12 [0 1 2 0 1 2 3 4 5 3 4 5]/' "$T/mmraku/head-diff-raku-nospesh-$i.out"
done
check mmraku 3
