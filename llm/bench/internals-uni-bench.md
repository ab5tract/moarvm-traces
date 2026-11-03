# Internal tables: Swiss for the uni kind, A/B (Task 7, branch zig-hash-internals, 2026-11-03)

Machine: AMD Ryzen 9 5900X, x86_64, idle (1-min load 1.09-1.28 at the A/B round starts; `internals-uni-bench-load.log`). Code: MoarVM b15c3e60f plus the Task 7 working tree (uni Swiss set, `MVM_uni_hash_build_strategy`, the three C sites). Builds: default `zig build install` (zig-lto, x86-64-v3); `tune-zig-prefix` with the macros resolving to DEFAULT, `internals-uni-prefix` with `MVM_HASH_INTERNAL_UNI_PROPERTY_CODES`, `_SEQ_NAMES`, `_CODEPOINTS` = LOOKUP and `_PROPERTY_VALUES(n)` = LOOKUP for n >= 65 (the user's ruling). Commands:

    tools/bench/hash-ab.sh --ladder=uni --rounds=7 --runs=5 --out=uni-before --variant=base:/tmp/claude-1000/internals-base-prefix/lib --variant=head:/tmp/claude-1000/tune-zig-prefix/lib
    tools/bench/hash-ab.sh --ladder=uni --rounds=7 --runs=5 --out=uni-ab --variant=default:/tmp/claude-1000/tune-zig-prefix/lib:/tmp/claude-1000/tune-zig-prefix/bin/uni-bench --variant=swiss:/tmp/claude-1000/internals-uni-prefix/lib:/tmp/claude-1000/internals-uni-prefix/bin/uni-bench

Cells: median of the 7 round medians, ratio swiss/default (the compare files label the denominator "base"; it is the default variant) [swiss min-max / default min-max of the round medians], ns. Win rule: ratio at or below 0.90 with disjoint spreads on the site's nqp cells. The raw rows: `internals-uni-bench-{nqp,capi}.raw`, compare files `internals-uni-bench-{nqp,capi}-compare.md`; before check `internals-uni-before-*`.

## Before check (macros DEFAULT, explicit sized builds vs the previous base prefix, nqp level)

| cell | size | head / base [spreads] | reading |
|---|---:|---|---|
| cpbyname_hit | 4096 | 0.89 [159.26-171.29 / 177.97-197.86] | faster, disjoint: the one sized build replaces 24 growths from 0 |
| cpbyname_miss | 4096 | 0.89 [247.03-278.27 / 277.46-288.27] | faster, spreads touch |
| cpbyname_miss_prefix | 4096 | 0.93 [203.32-222.27 / 228.88-249.50] | faster, overlapping |
| propcode_hit | 114 | 1.08 [117.02-129.19 / 112.25-120.78] | within spread |
| propcode_alias | 4266 | 1.00 | within spread |
| propcode_miss | 4380 | 1.04 | within spread |
| pvalcode_hit | 1024 | 1.03 | within spread |
| pvalcode_miss | 1024 | 1.04 | within spread |
| strfromname_seq | 3680 | 0.90 [914.84-1059.47 / 986.04-1144.60] | overlapping |

As expected: explicit builds with the real size change at most the build cost, and u3's cells (which include its build) improve. This ships regardless of the Swiss verdict.

## Default vs Swiss, the nqp cells

| site | cell | size | swiss/default [swiss / default] | verdict |
|---|---|---:|---|---|
| u3 | cpbyname_hit | 4096 | 1.02 [164.50-168.69 / 159.53-171.10] | no win |
| u3 | cpbyname_miss | 4096 | 1.02 [249.23-259.23 / 241.26-261.05] | no win |
| u3 | cpbyname_miss_prefix | 4096 | 1.01 [215.91-223.97 / 213.52-219.80] | no win |
| u1 | propcode_hit | 114 | 1.05 [122.63-132.47 / 113.76-130.59] | no win |
| u1 | propcode_alias | 4266 | 1.03 [107.05-113.98 / 103.34-112.95] | no win |
| u1 | propcode_miss | 4380 | 0.98 [95.64-104.61 / 97.50-106.17] | no win |
| u4 | pvalcode_hit | 1024 | 1.00 [152.72-158.51 / 151.21-159.39] | no win |
| u4 | pvalcode_miss | 1024 | 1.00 [149.45-157.37 / 144.09-156.73] | no win |
| u2 | strfromname_seq | 3680 | 1.03 [928.32-1087.96 / 912.70-1064.19] | no win |

## The C-API cells beside them

| site | cell | size | swiss/default [swiss / default] | nqp cell beside it |
|---|---|---:|---|---|
| u3 | cpbyname_hit | 4096 | 1.03 [46.97-48.45 / 45.28-46.52] | 1.02, agrees |
| u3 | cpbyname_miss | 4096 | 1.09 [38.77-39.75 / 35.58-36.37] | 1.02: Swiss is slower at C level, hidden in nqp's per-op overhead |
| u3 | cpbyname_miss_prefix | 4096 | 1.11 [31.74-33.10 / 28.54-28.95] | 1.01, same reading |
| u1 | propcode_hit | 114 | 1.11 [20.46-20.91 / 18.46-19.10] | 1.05, agrees |
| u1 | propcode_alias | 4266 | 0.84 [21.32-22.06 / 25.30-26.22] | 1.03: a real 16 percent win at C level that the nqp cell (about 105 ns per op, mostly interpreter and string encode) does not show |
| u1 | propcode_miss | 4380 | 0.73 [16.20-16.61 / 22.05-22.85] | 0.98: same, a 27 percent win at C level, flat in nqp |
| u4 | pvalcode_hit | 1024 | 1.08 [18.64-19.25 / 17.10-17.59] | 1.00, agrees |
| u4 | pvalcode_miss | 1024 | 1.06 [15.54-17.50 / 14.71-15.15] | 1.00, agrees |
| u2 | strfromname_seq | 3680 | 0.98 [47.61-49.26 / 48.51-49.88] | 1.03, both flat |

## Verdicts

No site clears the rule (every nqp cell is between 0.98 and 1.05 with overlapping spreads), so all four macros return to DEFAULT: u1, u2, u3 and u4 are reverted. The entry point and the Swiss set stay for the uni kind. The one real Swiss signal is u1's miss and alias cells at C level (0.73, 0.84), which the nqp-level cells (the measure the rule names) cannot see because the property-name lookup is a small part of each nqp operation.

u4: the bare Swiss set was neutral at nqp level (1.00 on both cells) and slower on hits at C level (1.08). The brief's extra round with a two-rung `small_then_swiss` set was not run: the pvalcode cells use tables of 1024 entries aggregate, and the macro already puts only tables of 65 or more entries on Swiss, so a two-rung set (Small below 64, Swiss from 64) builds those same tables as Swiss from the start and changes nothing in the cells; with the nqp cells at 1.00 there is no ratio for it to move to 0.90. If wanted, it is a separate, small experiment.

Tag spread: `widen` puts the 4,380 real property and alias names across all 128 tags, each within 3x of the mean (test "widen spreads the tag bits over the property names").
