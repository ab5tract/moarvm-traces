# C-API delete shift, bisect (Task 9e), 2026-11-04

Header as `bakeoff-baseline-check.md`: LTO, x86-64-v3, AMD Ryzen 9 5900X, load
under 2.0 (`internals-delete-bisect-ab1-load.log`). The C-API bench is one
executable (`hash-bench`, md5 a5e1aa6f..., identical in the base and head
prefixes), run against each variant's libmoar through `LD_LIBRARY_PATH`.
`tools/bench/hash-ab.sh`, C-API ladder, `--sizes=128,1024 --rounds=5 --runs=5
--nth=threshold`. Ratios are variant / base (1e88a52fb), delete op only. Shas: base 1e88a52fb; suspects built 0dcd14a83, 40bb7da6b, 2148c6213, 5e63c0c16; engine reference 73255e81e; head 36606b7f4.

## Step 1: the cell reproduces

Base 1e88a52fb against head (engine identical to 73255e81e):
delete 128 = 1.07 [8.17-18.64 / 7.82-14.55], delete 1024 = 1.05
[8.41-8.89 / 7.89-8.56] (`-step1-capi-compare.md`, `-step1-capi-raw.tsv`).
Round medians (ns/op), 1024: base 8.09 7.99 8.40 8.06 8.12; head 8.49 8.48
8.54 8.44 8.55: every head round above every base round but one. 128: base
7.99 7.95 8.36 8.01 8.65; head 8.67 8.45 8.46 8.86 8.56. Control
(`-step1x-capi-raw.tsv`): the head's bench exe against the base libmoar and the
head libmoar, same split (1024: base lib 8.04-8.44, head lib 8.49-8.52), so
the shift is in libmoar, not the harness.

## Step 2: bisect (the other suspects are stats/test-only, see below)

Suspect classification verified with `git show --stat`: cf36a87a8, 729b5ca09,
0dcd14a83 add the `-Dhash-stats` option and stats module (comptime-off in a
plain build); 40bb7da6b and 2148c6213 add comptime-guarded hooks to table.zig
and the tiers; 5e63c0c16 adds the Swiss tier set to the uni kind (uni.zig,
uni_exports.zig, C entry point). Built 0dcd14a83, 40bb7da6b, 2148c6213,
5e63c0c16 (each about 1 min, `zig build install`, all rc 0); cf36a87a8 and
729b5ca09 not built (their predecessor-bracketing makes them unnecessary:
0dcd14a83 includes them and is at base).

| commit | touches | delete 128 (round medians, ns; ratio) | delete 1024 (round medians; ratio) | verdict |
|---|---|---|---|---|
| base 1e88a52fb | | 8.00-8.81 | 7.97-8.14 | |
| 0dcd14a83 (stats option, module) | build, stats.zig | 7.99-8.66; 1.00 | 8.06-8.22; 1.00 | at base |
| 40bb7da6b (stats hooks in engine) | table.zig, tiers, exports | 8.00-11.23; 1.04 | 8.07-8.43; 1.01 | overlaps base (thinly at 1024: 8.07-8.14) |
| 2148c6213 (stats bin by size) | stats.zig, table.zig | 8.03-9.07; 1.03 | 8.07-8.56; 1.01 | overlaps base (thinly at 1024: 8.07-8.14) |
| 5e63c0c16 (uni Swiss tier set) | uni.zig, uni_exports.zig, uni_hash_table.c, unicode_*.c | 8.45-8.97; 1.10 | 8.50-9.03; 1.06 | 1024: disjoint above base; 128: overlaps base (base round 2 is 8.81, elevated in every variant) |
| head (73255e81e engine, 36606b7f4) | | 8.79-9.06; 1.10 | 8.52-8.93; 1.08 | overlaps the culprit |

Raw: `-ab1-capi-raw.tsv`, `-ab1-capi-compare.md` (its per-run min-max
brackets are far wider than the round medians and are not used here). The
bracket rests on the 1024 column and on the medians (1.10 against 1.03 at 128):
at 1024 the culprit (8.50-9.03) is disjoint above base (7.97-8.14), while its
predecessor 2148c62 (8.07-8.56) is not, and overlaps the culprit only at the
edge (8.50-8.56). At 128 the culprit does not clear base by the round-median
rule. The head reads 8.75 against the culprit's 8.54 at 1024 (1.08 against
1.06); their ranges overlap (8.52-8.93 against 8.50-9.03), so head and culprit
overlap and the 0.2 ns difference is unexplained and within noise. The shift
enters with 5e63c0c16 and does not grow past it by a measurable amount.

## Step 3: diagnosis

5e63c0c16 does not touch the str kind or the delete path. `objdump -d` of
`MVM_str_hash_delete_nocheck` in the 2148c62 and 5e63c0c libmoar.so
(`-dis-2148c62.txt`, `-dis-5e63c0c.txt`): 1115 lines each and, with
addresses and rip-relative displacements normalized, identical instruction
for instruction. The function moved from 0x7c4ba0 to 0x7c5bf0 (+0x1050; the
extra code before it is the Swiss instantiation for the uni kind, which LTO
places ahead of the str functions). No fields, flags, loads, or inlining
differ. `perf annotate` (user space) of the 1024 bench (`-perf-*.txt`): the hot
probe loop is `ja/add/dec/inc/sub; movzx; cmp; jne` followed by `mov rsi,[r10+r12]; test rsi,rsi`; in 2148c62 it sits at 0x7c4f40 (32-byte
aligned; 25 percent of the annotated samples on the test at 0x7c4f60), in 5e63c0c at 0x7c5f90 (mod 32 = 16;
34 percent of the annotated samples on the test at 0x7c5fb0, 13 percent on the jne; `-perf-*.txt`).
(Function-level shares of the run are not cited: the symbols could no longer be resolved after the prefixes were removed.)
Consistent with a code-placement effect (the loop in a different 32-byte fetch
window), 0.5 ns per delete. The data does not exclude: an inlining change at
delete's callers (the C-API wrapper or the nqp op), a changed layout of the hash
header or the uni tables, or uop-cache, branch-predictor or aliasing effects of
the moved loop as against a fetch-window effect. No alignment experiment was
run because the brief forbade tuning.

No fix: there is no source change that corrects it. Pinning it would be
function or loop alignment (`-falign-functions`, `-mllvm -align-all-nofallthru-blocks`
or similar), which is tuning, applies to every function, and is the next
unrelated commit's lottery again. Nothing was changed on the branch.

Recommendation for Task 10: waive the delete cell at 65-and-up on this
diagnosis (identical machine code, moved), or have the user decide on a
build-wide alignment setting.

## Confirmation (2026-11-04, final-review fix wave)

The whole-branch review asked for an experiment: take the uni Swiss set (the
code 5e63c0c16 added) out of the shipped engine and see whether the shift goes
with it. `swiss_rung`, its set index and the strategy-1 entry of
`MVM_uni_hash_build_strategy` are now compiled out of `libmoar` unless
`-Duni-swiss` is given (unit tests always have them; `uni.swiss_enabled` in
`src/zig/core/hash/uni.zig`). No internal site used the set. The head prefix was
rebuilt from that tree and measured against the 1e88a52fb prefix with one
`hash-bench` exe for both variants:
`hash-ab.sh --sizes=65,128,1024 --rounds=7 --runs=5 --nth=threshold --variant=base:... --variant=head:...`
(run a: base first; run b: head first; load 1.13 or under at every start).
Raw: `internals-delete-confirm-{a,b}/`.

| capi delete | before (final ladder a / b, with the Swiss set) | run a (base first) | run b (head first) |
|---|---|---|---|
| 65 | 1.067 overlap / 1.062 | 1.04 [8.21-17.58 / 7.88-15.00] | head/base 1.05 (base/head 0.95), ranges [8.05-13.92 / 8.19-20.66] overlap |
| 128 | 1.061 / 1.053, disjoint | 1.02 [8.11-8.68 / 7.90-8.48] | head/base 1.03 (base/head 0.97) [7.93-8.42 / 8.09-10.30] |
| 1024 | 1.071 / 1.058, disjoint | 1.01 [8.12-12.79 / 7.90-8.48] | head/base 1.02 (base/head 0.98) [7.92-8.30 / 8.10-10.53] |

(Run a prints head over base with [head / base] ranges; run b has the head first,
so its compare file prints base over head with [base / head] ranges.) Every
delete cell is within 5 percent or overlaps, in both orders. The shift went with the
Swiss set.

New `libmoar.so`: `MVM_str_hash_delete_nocheck` is at 0x7c4e00 (mod 32 = 0) and its probe
loop (the `ja/add/dec/sub/inc; movzbl; cmp; jne` loop) starts at 0x7c4f00 (mod 32 = 0), again 32-byte
aligned like 2148c62 (the loop sat at mod 32 = 16 in 5e63c0c). That supports the
code-placement attribution: the function body is unchanged, and it is aligned
again once the uni Swiss instantiation no longer sits ahead of it. The delete
exception of Task 10 is therefore resolved by the gate; it is not needed.
