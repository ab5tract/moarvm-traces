# C-API delete shift, bisect (Task 9e), 2026-11-04

Header as `bakeoff-baseline-check.md`: LTO, x86-64-v3, AMD Ryzen 9 5900X, load
under 2.0 (`internals-delete-bisect-ab1-load.log`). The C-API bench is one
executable (`hash-bench`, md5 a5e1aa6f..., identical in the base and head
prefixes), run against each variant's libmoar through `LD_LIBRARY_PATH`.
`tools/bench/hash-ab.sh`, C-API ladder, `--sizes=128,1024 --rounds=5 --runs=5
--nth=threshold`. Ratios are variant / base (1478311f6), delete op only.

## Step 1: the cell reproduces

Base 1478311f6 against head (engine identical to 6bbd4612e):
delete 128 = 1.07 [8.17-18.64 / 7.82-14.55], delete 1024 = 1.05
[8.41-8.89 / 7.89-8.56] (`-step1-capi-compare.md`, `-step1-capi-raw.tsv`).
Round medians (ns/op), 1024: base 8.09 7.99 8.40 8.06 8.12; head 8.49 8.48
8.54 8.44 8.55: every head round above every base round but one. 128: base
7.99 7.95 8.36 8.01 8.65; head 8.67 8.45 8.46 8.86 8.56. Control
(`-step1x-capi-raw.tsv`): the head's bench exe against the base libmoar and the
head libmoar, same split (1024: base lib 8.04-8.44, head lib 8.49-8.52), so
the shift is in libmoar, not the harness.

## Step 2: bisect (the other suspects are stats/test-only, see below)

Suspect classification verified with `git show --stat`: 0f8531b6a, 01d11e6c2,
54866bf06 add the `-Dhash-stats` option and stats module (comptime-off in a
plain build); a375403d1 and c642db6ae add comptime-guarded hooks to table.zig
and the tiers; 74158b566 adds the Swiss tier set to the uni kind (uni.zig,
uni_exports.zig, C entry point). Built 54866bf06, a375403d1, c642db6ae,
74158b566 (each about 1 min, `zig build install`, all rc 0); 0f8531b6a and
01d11e6c2 not built (their predecessor-bracketing makes them unnecessary:
54866bf06 includes them and is at base).

| commit | touches | delete 128 | delete 1024 | verdict |
|---|---|---|---|---|
| 54866bf06 (stats option, module) | build, stats.zig | 1.00 [7.90-19.21 / 7.77-9.16] | 1.00 [7.91-9.39 / 7.93-8.40] | at base |
| a375403d1 (stats hooks in engine) | table.zig, tiers, exports | 1.04 [7.89-21.07 / 7.77-9.16] | 1.01 [7.96-22.04 / 7.93-8.40] | within spread |
| c642db6ae (stats bin by size) | stats.zig, table.zig | 1.03 [7.95-13.21 / 7.77-9.16] | 1.01 [7.97-21.33 / 7.93-8.40] | within spread |
| **74158b566 (uni Swiss tier set)** | uni.zig, uni_exports.zig, uni_hash_table.c, unicode_*.c | 1.10 [8.35-11.04 / 7.77-9.16] | 1.06 [8.30-10.55 / 7.93-8.40] | **culprit: disjoint above base** |
| head (6bbd4612e engine) | | 1.10 [8.68-15.31 / 7.77-9.16] | 1.08 [8.44-15.71 / 7.93-8.40] | same as culprit |

Raw: `-ab1-capi-raw.tsv`, `-ab1-capi-compare.md`. Round medians of delete at 1024:
base 7.97-8.14, 54866bf 8.06-8.22, a375403 8.07-8.43, c642db6 8.07-8.56,
74158b5 8.50-9.03. The predecessor of the culprit is within spread, the culprit
is not, and the head equals the culprit: the shift is one step.

## Step 3: diagnosis

74158b566 does not touch the str kind or the delete path. `objdump -d` of
`MVM_str_hash_delete_nocheck` in the c642db6 and 74158b5 libmoar.so
(`-dis-c642db6.txt`, `-dis-74158b5.txt`): 1115 lines each and, with
addresses and rip-relative displacements normalized, identical instruction
for instruction. The function moved from 0x7c4ba0 to 0x7c5bf0 (+0x1050; the
extra code before it is the Swiss instantiation for the uni kind, which LTO
places ahead of the str functions). No fields, flags, loads, or inlining
differ. `perf annotate` (user space) of the 1024 bench (`-perf-*.txt`): the hot
probe loop is `ja/add/dec/inc/sub; movzx; cmp; jne` followed by `mov rsi,[r10+r12]; test rsi,rsi`; in c642db6 it sits at 0x7c4f40 (32-byte
aligned; 25 percent of the function's samples on the test at 0x7c4f60), in 74158b5 at 0x7c5f90 (mod 32 = 16;
34 percent of the samples on the test at 0x7c5fb0, 13 percent on the jne),
and `MVM_str_hash_delete_nocheck` goes from 6.9 to 13.4 percent of the run.
A pure code placement effect (the loop moved to a different 32-byte fetch
window), 0.5 ns per delete.

No fix: there is no source change that corrects it. Pinning it would be
function or loop alignment (`-falign-functions`, `-mllvm -align-all-nofallthru-blocks`
or similar), which is tuning, applies to every function, and is the next
unrelated commit's lottery again. Nothing was changed on the branch.

Recommendation for Task 10: waive the delete cell at 65-and-up on this
diagnosis (identical machine code, moved), or have the user decide on a
build-wide alignment setting.
