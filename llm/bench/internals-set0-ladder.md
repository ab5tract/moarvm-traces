# Set 0 ladder: Small then Swiss against Small then Robin Hood (MoarVM f0e68afff, 2026-11-03)

Task 9b of the internal-tables campaign. Base is 1e88a52fb (default ladder Small then Robin Hood), head is f0e68afff (default ladder Small then Swiss; the build in the prefix is that commit's tree, installed before the commit). Both are the default build (`zig build install --prefix <p>`, zig impl, LTO, x86-64-v3, stats off). CPU AMD Ryzen 9 5900X. Prefixes: base `/tmp/claude-1000/internals-base-prefix`, head `/tmp/claude-1000/tune-zig-prefix`.

Commands (`tools/bench/hash-ab.sh`, 7 rounds, the variant order rotated per round, load waited under 2.0):

    hash-ab.sh --rounds=7 --sizes=4,16,32,63,64,65,128,256,1024,16384 --runs=5 --nth=all --out=set0-main \
        --variant=base:$B/lib:$B/bin/hash-bench --variant=head:$H/lib:$H/bin/hash-bench
    hash-ab.sh --rounds=7 --sizes=49,97 --runs=5 --nth=all --out=set0-resize  (the same variants)

Both levels: nqp (`hash-bench.nqp`, each prefix's libmoar under the same nqp) and capi (the `hash-bench` exe). Cells: median of the 7 round medians, ratio head/base; the brackets are the per-run min/max ns that `hash-compare.pl` prints (not the spread of the round medians). Verdicts were re-judged by the round medians (min-max over the 7 rounds per side, from the raw files) in fix round 1; where the bracket and the round medians disagree the round medians rule, from `hash-compare.pl`. Verdict rule (the user's, for this task): 16-64 cells within the round spread (overlapping) or within 5 percent of base; 65 and up expected near the Swiss column of the scoreboard (hits 0.88-0.99, misses 0.80-0.83, inserts 0.78-0.86, deletes 0.88-0.97, overwrite 0.78-0.89, iterate 0.72, clone 0.61-0.81), judged pass when ratio < 1.05 or the spreads overlap; the size-4 cells are warm-up and not read; 49/97 are resize cells and insert_nth 65 is the migration cell, reported only. Machine idle: 1-minute load 0.84-1.19 at the run starts. Raw: `internals-set0-{nqp,capi}-{base,head}.tsv` (the harness's 7 columns, main and resize runs concatenated), `internals-set0-{nqp,capi}-raw.tsv` (with variant and round columns), `internals-set0-load.log`.

## Verdict

Kept. No 16-64 cell fails when judged by the round medians: each is within 5 percent of base or overlaps (disjoint but within 5 percent: nqp clone 16 at 1.047, capi iterate 16/32/63/64 at 1.04; no 16-64 cell flipped). The 65-and-up cells land on the scoreboard's Swiss column except the nqp lookup_hit at 65 (1.26, disjoint) and lookup_hit/delete at 16384 (1.04), reported as losses.

One fix attempt was used, and it worked. The first A/B of the flipped ladder (the same tree without `noinline` on Swiss's `highestLiveBelow`) read iterate at 16-64 as 1.05-1.09 at the nqp level and 1.06-1.08 at the C-API level, with disjoint spreads at 16, 32 and 64 (capi): the Swiss `next` had been inlined into the set-0 iteration dispatch and grew the Small rung's path. Making it `noinline` brought iterate 4-64 to 1.00-1.04 (capi) and 1.00-1.09 (nqp, overlapping) and kept the 65-and-up iterate at 0.72-0.75. The first run's compare files are kept in the scratchpad only; the table below is the full re-run after the fix.

Headline cells:

- 16-64, worst per op (nqp / capi): insert 1.10 at 63 (overlap) / 0.94, lookup_miss 1.07 at 32 (overlap) / 0.96, delete 1.04 / 1.00, iterate 1.09 at 64 (overlap) / 1.04, clone 1.05 / not in the C-API harness, insert_nth 1.09 at 63 (overlap) / 0.96.
- 65 to 16384 (nqp / capi): insert 0.82-0.88 / 0.74-0.81, lookup_hit 0.90-1.26 (65 is the noisy cell below) / 0.70-0.81, lookup_miss 0.82-0.91 / 0.58-0.60, delete 0.90-1.04 / 0.83-0.91, overwrite 0.92-1.02, iterate 0.73-0.75 / 0.72-0.73, clone 0.63-0.85, iterate_delete 0.81-0.85, insert_nth (128 up) 0.86-0.92 / 0.84-0.88. The nqp-level lookup and delete cells sit a little above the scoreboard's Swiss column at 1024-16384 (0.94-1.04), inside their spreads.
- lookup_hit 65 at the nqp level is a loss: 1.26, round medians 16.29-18.57 ns (head) against 13.04-13.77 (base), disjoint (first run 1.29); the C-API level reads 0.73. It is a 65-and-up cell (a fresh migration), so the 4-64 verdict is untouched. Also at the nqp level, lookup_hit and delete at 16384 read 1.04 with disjoint round medians (small losses).
- insert_nth 65, the migration into the 128-slot Swiss block: 0.69 nqp, 0.62 capi. The 97th insert_nth is 0.05 nqp and 0.01 capi because the base grows its 128-slot Robin Hood block (load limit 96) at the 97th while the Swiss block (limit 112) grows at the 113th.
- 49 and 97: see the table; 97 is 0.47-0.56 on inserts and 0.67-0.68 on iterate.
- Memory (capi, process maximum RSS after the insert block, median of rounds, head/base): 1.00 up to 64, 0.58 at 65, 0.29 at 97, 0.57 at 128, 0.67 at 256, 0.89 at 1024, 0.99 at 16384. The nqp-level RSS is the whole process and noisy.

## Level: nqp

| op | size | ratio [head min-max / base min-max] ns | verdict |
|---|---:|---|---|
| insert | 4 | 0.95 [21.26-60.27 / 22.09-68.5] | warm-up, not read |
| insert | 16 | 1.00 [18.29-22.56 / 18.41-38.26] | pass (<=1.05) |
| insert | 32 | 1.01 [20.44-24.38 / 20.41-24.56] | pass (<=1.05) |
| insert | 49 | 1.00 [18.19-60.1 / 18.27-63.21] | resize cell, reported |
| insert | 63 | 1.10 [21.12-26.52 / 20.84-26.34] | pass (overlap) |
| insert | 64 | 0.99 [20.72-25.2 / 20.77-25.6] | pass (<=1.05) |
| insert | 65 | 0.88 [29.56-34.94 / 33.94-40.19] | pass (<1.0) |
| insert | 97 | 0.55 [27.84-34.56 / 52.85-59.55] | resize cell, reported |
| insert | 128 | 0.82 [34.36-49.44 / 43.75-51.72] | pass (<1.0) |
| insert | 256 | 0.82 [38.92-43.78 / 46.78-56.41] | pass (<1.0) |
| insert | 1024 | 0.84 [40.21-46.89 / 46.79-55.01] | pass (<1.0) |
| insert | 16384 | 0.85 [41.68-58.9 / 48.78-67.44] | pass (<1.0) |
| lookup_hit | 4 | 1.01 [10.78-76.68 / 10.74-63.3] | warm-up, not read |
| lookup_hit | 16 | 1.02 [10.3-11.29 / 10.24-11.19] | pass (<=1.05) |
| lookup_hit | 32 | 1.00 [10.25-11.72 / 10.34-11.95] | pass (<=1.05) |
| lookup_hit | 49 | 0.89 [11.17-48.56 / 11.2-52.11] | resize cell, reported |
| lookup_hit | 63 | 1.00 [11.33-13.64 / 11.62-12.57] | pass (<=1.05) |
| lookup_hit | 64 | 1.00 [11.25-12.16 / 11.51-13.08] | pass (<=1.05) |
| lookup_hit | 65 | 1.26 [12.82-20.55 / 12.9-23.57] | LOSS, disjoint round medians (16.29-18.57 / 13.04-13.77); reported, not passed |
| lookup_hit | 97 | 0.99 [10.78-14.73 / 11.88-13.58] | resize cell, reported |
| lookup_hit | 128 | 0.96 [11.34-21.4 / 12.83-15.42] | pass (<1.0) |
| lookup_hit | 256 | 0.90 [11.54-13.17 / 12.9-17.07] | pass (<1.0) |
| lookup_hit | 1024 | 0.95 [12.01-15.13 / 13.23-14.94] | pass (<1.0) |
| lookup_hit | 16384 | 1.04 [14.86-17.13 / 14.51-15.31] | small loss, disjoint round medians (1.04); reported |
| lookup_miss | 4 | 1.05 [10.33-48.24 / 10.09-52.51] | warm-up, not read |
| lookup_miss | 16 | 1.05 [9.84-11.19 / 9.62-11.23] | pass (<=1.05) |
| lookup_miss | 32 | 1.07 [9.81-12.26 / 9.3-12.19] | pass (overlap) |
| lookup_miss | 49 | 0.86 [11.58-48.98 / 11.2-53.72] | resize cell, reported |
| lookup_miss | 63 | 1.00 [11.34-20.14 / 11.19-13.16] | pass (<=1.05) |
| lookup_miss | 64 | 1.00 [11.23-13.54 / 10.84-14.2] | pass (<=1.05) |
| lookup_miss | 65 | 0.91 [10.01-14.51 / 12.9-15.78] | pass (<1.0) |
| lookup_miss | 97 | 1.04 [10.71-13.33 / 11.24-11.66] | resize cell, reported |
| lookup_miss | 128 | 0.82 [10.16-13.53 / 12.75-13.37] | pass (<1.0) |
| lookup_miss | 256 | 0.82 [10.16-11.73 / 12.83-13.42] | pass (<1.0) |
| lookup_miss | 1024 | 0.84 [10.46-11.19 / 12.84-13.41] | pass (<1.0) |
| lookup_miss | 16384 | 0.84 [11.46-16.43 / 13.74-18.11] | pass (<1.0) |
| delete | 4 | 1.01 [10.9-44.22 / 10.6-47.64] | warm-up, not read |
| delete | 16 | 1.01 [9.99-10.84 / 10.01-10.38] | pass (<=1.05) |
| delete | 32 | 1.04 [10.67-12.7 / 10.76-11.93] | pass (<=1.05) |
| delete | 49 | 1.08 [11.62-41.23 / 11.72-43.37] | resize cell, reported |
| delete | 63 | 1.01 [11.59-15.28 / 11.54-13.48] | pass (<=1.05) |
| delete | 64 | 1.02 [11.74-12.93 / 11.38-14.09] | pass (<=1.05) |
| delete | 65 | 1.02 [12.24-15.77 / 13.0-20.41] | pass |
| delete | 97 | 0.99 [11.8-14.13 / 12.38-16.43] | resize cell, reported |
| delete | 128 | 0.92 [11.92-16.09 / 13.12-13.77] | pass (<1.0) |
| delete | 256 | 0.90 [11.82-12.49 / 13.12-13.64] | pass (<1.0) |
| delete | 1024 | 0.97 [12.77-14.52 / 13.3-14.52] | pass (<1.0) |
| delete | 16384 | 1.04 [14.9-16.52 / 14.74-15.62] | small loss, disjoint round medians (1.04); reported |
| iterate | 4 | 1.17 [13.77-48.41 / 13.9-49.69] | warm-up, not read |
| iterate | 16 | 1.00 [10.73-13.06 / 10.76-14.29] | pass (<=1.05) |
| iterate | 32 | 1.00 [9.88-13.14 / 10.04-13.61] | pass (<=1.05) |
| iterate | 49 | 2.40 [9.87-37.89 / 9.72-42.84] | resize cell, reported |
| iterate | 63 | 1.00 [9.49-11.32 / 9.56-11.32] | pass (<=1.05) |
| iterate | 64 | 1.09 [9.59-11.18 / 9.59-11.19] | pass (overlap) |
| iterate | 65 | 0.75 [11.22-11.91 / 14.9-17.1] | pass (<1.0) |
| iterate | 97 | 0.68 [11.03-11.42 / 16.28-17.33] | resize cell, reported |
| iterate | 128 | 0.74 [10.98-11.48 / 14.82-15.47] | pass (<1.0) |
| iterate | 256 | 0.73 [10.74-11.29 / 14.49-15.19] | pass (<1.0) |
| iterate | 1024 | 0.73 [10.58-11.84 / 14.48-15.07] | pass (<1.0) |
| iterate | 16384 | 0.73 [10.37-18.28 / 14.38-16.2] | pass (<1.0) |
| overwrite | 4 | 1.00 [16.17-55.29 / 16.22-58.71] | warm-up, not read |
| overwrite | 16 | 1.02 [15.61-17.22 / 15.53-17.18] | pass (<=1.05) |
| overwrite | 32 | 1.01 [15.81-21.18 / 15.71-18.23] | pass (<=1.05) |
| overwrite | 49 | 2.36 [17.02-52.97 / 16.94-55.07] | resize cell, reported |
| overwrite | 63 | 0.98 [17.13-20.55 / 17.42-19.67] | pass (<=1.05) |
| overwrite | 64 | 0.98 [17.22-22.23 / 17.79-19.12] | pass (<=1.05) |
| overwrite | 65 | 1.02 [18.67-24.62 / 20.12-33.55] | pass |
| overwrite | 97 | 0.97 [17.74-19.73 / 19.24-19.94] | resize cell, reported |
| overwrite | 128 | 0.93 [18.44-24.01 / 20.27-21.98] | pass (<1.0) |
| overwrite | 256 | 0.92 [18.54-19.47 / 20.43-21.83] | pass (<1.0) |
| overwrite | 1024 | 0.94 [19.15-20.45 / 20.66-22.1] | pass (<1.0) |
| overwrite | 16384 | 0.99 [21.47-27.24 / 22.11-23.02] | pass (<1.0) |
| clone | 4 | 0.89 [9.4-150.32 / 9.14-158.1] | warm-up, not read |
| clone | 16 | 1.05 [4.17-7.53 / 4.04-7.88] | pass (<=1.05) |
| clone | 32 | 1.00 [3.45-6.81 / 3.47-6.93] | pass (<=1.05) |
| clone | 49 | 1.04 [3.52-7.59 / 3.46-7.63] | resize cell, reported |
| clone | 63 | 0.94 [3.1-6.76 / 3.13-6.89] | pass (<=1.05) |
| clone | 64 | 1.01 [3.1-6.57 / 3.11-6.65] | pass (<=1.05) |
| clone | 65 | 0.72 [7.61-11.16 / 10.85-17.37] | pass (<1.0) |
| clone | 97 | 0.34 [5.88-9.72 / 16.38-21.22] | resize cell, reported |
| clone | 128 | 0.63 [8.54-13.25 / 13.89-16.0] | pass (<1.0) |
| clone | 256 | 0.65 [8.84-12.32 / 9.77-15.42] | pass (<1.0) |
| clone | 1024 | 0.85 [6.85-12.49 / 8.58-14.38] | pass (<1.0) |
| clone | 16384 | 0.80 [7.58-12.31 / 10.32-11.16] | pass (<1.0) |
| iterate_delete | 4 | 1.01 [25.4-66.87 / 25.01-65.06] | warm-up, not read |
| iterate_delete | 16 | 1.03 [20.81-22.75 / 20.42-22.08] | pass (<=1.05) |
| iterate_delete | 32 | 1.01 [20.61-24.2 / 20.04-23.95] | pass (<=1.05) |
| iterate_delete | 49 | 1.07 [20.8-51.17 / 21.53-49.91] | resize cell, reported |
| iterate_delete | 63 | 0.99 [20.46-23.55 / 20.88-22.94] | pass (<=1.05) |
| iterate_delete | 64 | 1.01 [20.5-23.11 / 20.83-23.64] | pass (<=1.05) |
| iterate_delete | 65 | 0.84 [21.78-23.35 / 26.68-27.91] | pass (<1.0) |
| iterate_delete | 97 | 0.82 [21.5-23.49 / 27.03-28.38] | resize cell, reported |
| iterate_delete | 128 | 0.83 [20.76-24.48 / 26.31-27.49] | pass (<1.0) |
| iterate_delete | 256 | 0.81 [21.09-22.27 / 26.06-32.14] | pass (<1.0) |
| iterate_delete | 1024 | 0.81 [21.33-22.15 / 26.41-27.78] | pass (<1.0) |
| iterate_delete | 16384 | 0.85 [26.28-28.96 / 31.2-34.72] | pass (<1.0) |
| insert_nth | 4 | 1.01 [14.26-30.86 / 14.38-51.26] | warm-up, not read |
| insert_nth | 16 | 0.99 [13.98-16.21 / 13.99-24.39] | pass (<=1.05) |
| insert_nth | 32 | 1.03 [14.15-55.35 / 14.02-22.55] | pass (<=1.05) |
| insert_nth | 49 | 0.85 [17.36-69.32 / 15.93-52.49] | resize cell, reported |
| insert_nth | 63 | 1.09 [15.67-28.84 / 15.24-91.5] | pass (overlap) |
| insert_nth | 64 | 0.75 [17.99-42.63 / 15.84-85.88] | pass (<=1.05) |
| insert_nth | 65 | 0.69 [602.74-929.86 / 836.81-1215.41] | migration cell, reported |
| insert_nth | 97 | 0.05 [57.9-99.49 / 1370.17-1940.14] | resize cell, reported |
| insert_nth | 128 | 0.92 [26.08-61.27 / 29.71-35.5] | pass (<1.0) |
| insert_nth | 256 | 0.86 [27.36-30.88 / 31.27-54.99] | pass (<1.0) |
| insert_nth | 1024 | 0.84 [29.28-40.39 / 30.98-95.33] | pass (<1.0) |
| insert_nth | 16384 | 0.88 [42.5-92.75 / 42.5-218.0] | pass (<1.0) |

Memory (nqp, process RSS after the insert block, median of rounds, head/base):

| size | ratio | bytes head / base |
|---:|---:|---|
| 4 | 0.929 | 27611136 / 29708288 |
| 16 | 1.000 | 16781312 / 16781312 |
| 32 | 1.000 | 18882560 / 18878464 |
| 49 | 0.967 | 24698880 / 25538560 |
| 63 | 1.000 | 18878464 / 18882560 |
| 64 | 1.111 | 20975616 / 18882560 |
| 65 | 0.143 | 2097152 / 14680064 |
| 97 | 0.324 | 25165824 / 77602816 |
| 128 | 0.679 | 39854080 / 58728448 |
| 256 | 0.769 | 41951232 / 54530048 |
| 1024 | 0.952 | 41947136 / 44040192 |
| 16384 | 0.950 | 37871616 / 39849984 |

## Level: capi

| op | size | ratio [head min-max / base min-max] ns | verdict |
|---|---:|---|---|
| insert | 4 | 0.98 [13.28-16.18 / 13.43-17.18] | warm-up, not read |
| insert | 16 | 0.96 [12.37-16.43 / 13.01-15.34] | pass (<=1.05) |
| insert | 32 | 0.95 [11.61-15.77 / 12.84-16.75] | pass (<=1.05) |
| insert | 49 | 0.98 [12.68-20.34 / 13.34-20.21] | resize cell, reported |
| insert | 63 | 0.95 [12.81-16.74 / 13.51-17.86] | pass (<=1.05) |
| insert | 64 | 0.96 [12.59-17.03 / 13.31-18.26] | pass (<=1.05) |
| insert | 65 | 0.78 [22.4-27.28 / 27.93-40.58] | pass (<1.0) |
| insert | 97 | 0.45 [16.84-23.65 / 38.46-52.76] | resize cell, reported |
| insert | 128 | 0.77 [26.95-33.22 / 36.53-42.29] | pass (<1.0) |
| insert | 256 | 0.74 [28.94-39.6 / 39.6-43.91] | pass (<1.0) |
| insert | 1024 | 0.81 [31.08-36.97 / 41.9-46.26] | pass (<1.0) |
| insert | 16384 | 0.81 [35.27-47.39 / 44.2-63.05] | pass (<1.0) |
| lookup_hit | 4 | 0.94 [4.57-6.31 / 4.84-5.22] | warm-up, not read |
| lookup_hit | 16 | 0.94 [4.48-5.97 / 4.8-5.27] | pass (<=1.05) |
| lookup_hit | 32 | 0.98 [4.67-6.65 / 4.78-5.89] | pass (<=1.05) |
| lookup_hit | 49 | 1.00 [5.08-6.72 / 5.58-7.21] | resize cell, reported |
| lookup_hit | 63 | 0.93 [4.98-6.4 / 5.52-7.06] | pass (<=1.05) |
| lookup_hit | 64 | 0.94 [4.96-6.63 / 5.45-6.87] | pass (<=1.05) |
| lookup_hit | 65 | 0.73 [5.15-6.65 / 7.53-11.82] | pass (<1.0) |
| lookup_hit | 97 | 0.89 [4.78-7.0 / 6.15-16.26] | resize cell, reported |
| lookup_hit | 128 | 0.72 [5.22-6.19 / 7.58-8.21] | pass (<1.0) |
| lookup_hit | 256 | 0.70 [5.21-8.04 / 7.7-8.67] | pass (<1.0) |
| lookup_hit | 1024 | 0.75 [5.83-7.11 / 7.79-9.54] | pass (<1.0) |
| lookup_hit | 16384 | 0.81 [6.8-7.25 / 8.36-9.01] | pass (<1.0) |
| lookup_miss | 4 | 0.97 [4.07-5.41 / 4.23-5.49] | warm-up, not read |
| lookup_miss | 16 | 0.89 [4.02-5.43 / 4.42-5.92] | pass (<=1.05) |
| lookup_miss | 32 | 0.95 [4.35-5.93 / 4.59-5.73] | pass (<=1.05) |
| lookup_miss | 49 | 1.01 [4.98-6.67 / 5.12-6.31] | resize cell, reported |
| lookup_miss | 63 | 0.96 [5.24-5.99 / 5.39-6.2] | pass (<=1.05) |
| lookup_miss | 64 | 0.95 [5.19-5.93 / 5.31-6.2] | pass (<=1.05) |
| lookup_miss | 65 | 0.60 [4.3-5.43 / 7.95-11.4] | pass (<1.0) |
| lookup_miss | 97 | 0.75 [4.58-5.83 / 6.4-7.09] | resize cell, reported |
| lookup_miss | 128 | 0.58 [4.32-5.42 / 7.94-8.7] | pass (<1.0) |
| lookup_miss | 256 | 0.59 [4.43-5.99 / 7.98-8.36] | pass (<1.0) |
| lookup_miss | 1024 | 0.60 [4.73-5.93 / 7.89-9.61] | pass (<1.0) |
| lookup_miss | 16384 | 0.60 [5.57-9.14 / 9.17-13.02] | pass (<1.0) |
| delete | 4 | 1.03 [6.15-30.7 / 6.03-7.31] | warm-up, not read |
| delete | 16 | 1.02 [6.85-26.39 / 6.81-7.55] | pass (<=1.05) |
| delete | 32 | 1.02 [7.84-10.13 / 7.72-9.3] | pass (<=1.05) |
| delete | 49 | 0.99 [8.68-25.45 / 8.66-9.67] | resize cell, reported |
| delete | 63 | 1.00 [8.64-9.51 / 8.86-10.01] | pass (<=1.05) |
| delete | 64 | 0.99 [8.82-9.92 / 8.42-10.2] | pass (<=1.05) |
| delete | 65 | 0.91 [7.07-7.68 / 7.95-8.27] | pass (<1.0) |
| delete | 97 | 1.02 [6.42-10.39 / 6.85-7.89] | resize cell, reported |
| delete | 128 | 0.85 [6.53-7.05 / 7.88-8.33] | pass (<1.0) |
| delete | 256 | 0.83 [6.47-7.73 / 7.88-8.29] | pass (<1.0) |
| delete | 1024 | 0.88 [6.66-7.4 / 7.93-8.58] | pass (<1.0) |
| delete | 16384 | 0.90 [7.5-8.2 / 8.63-9.19] | pass (<1.0) |
| iterate | 4 | 1.05 [7.07-9.55 / 6.82-8.87] | warm-up, not read |
| iterate | 16 | 1.04 [6.44-9.07 / 6.23-6.53] | pass (<=1.05) |
| iterate | 32 | 1.04 [6.43-8.34 / 6.28-6.52] | pass (<=1.05) |
| iterate | 49 | 1.03 [6.49-8.2 / 6.31-6.7] | resize cell, reported |
| iterate | 63 | 1.04 [6.41-6.9 / 6.17-6.52] | pass (<=1.05) |
| iterate | 64 | 1.04 [6.41-6.61 / 6.17-6.39] | pass (<=1.05) |
| iterate | 65 | 0.73 [7.87-8.32 / 10.76-12.25] | pass (<1.0) |
| iterate | 97 | 0.67 [7.76-11.5 / 11.85-13.29] | resize cell, reported |
| iterate | 128 | 0.72 [7.75-8.38 / 10.76-11.41] | pass (<1.0) |
| iterate | 256 | 0.73 [7.76-10.88 / 10.74-11.38] | pass (<1.0) |
| iterate | 1024 | 0.72 [7.7-7.95 / 10.71-11.13] | pass (<1.0) |
| iterate | 16384 | 0.72 [7.71-8.02 / 10.69-11.34] | pass (<1.0) |
| insert_nth | 4 | 0.93 [7.99-10.55 / 8.62-9.32] | warm-up, not read |
| insert_nth | 16 | 0.96 [8.23-13.07 / 8.65-11.45] | pass (<=1.05) |
| insert_nth | 32 | 0.93 [8.22-10.18 / 8.87-15.04] | pass (<=1.05) |
| insert_nth | 49 | 0.91 [9.5-17.54 / 10.23-50.25] | resize cell, reported |
| insert_nth | 63 | 1.00 [9.23-40.68 / 9.55-19.09] | pass (<=1.05) |
| insert_nth | 64 | 0.99 [9.22-17.93 / 9.68-16.03] | pass (<=1.05) |
| insert_nth | 65 | 0.62 [614.98-875.91 / 1027.19-1121.59] | migration cell, reported |
| insert_nth | 97 | 0.01 [17.92-79.08 / 1609.81-2065.97] | resize cell, reported |
| insert_nth | 128 | 0.84 [18.75-41.6 / 21.66-25.17] | pass (<1.0) |
| insert_nth | 256 | 0.86 [20.2-24.85 / 21.84-43.09] | pass (<1.0) |
| insert_nth | 1024 | 0.88 [20.67-31.78 / 22.55-36.64] | pass (<1.0) |
| insert_nth | 16384 | 0.79 [25.0-45.0 / 25.0-42.75] | pass (<1.0) |

Memory (capi, process RSS after the insert block, median of rounds, head/base):

| size | ratio | bytes head / base |
|---:|---:|---|
| 4 | 1.000 | 152 / 152 |
| 16 | 1.000 | 288 / 288 |
| 32 | 1.000 | 560 / 560 |
| 49 | 1.000 | 1104 / 1104 |
| 63 | 1.000 | 1104 / 1104 |
| 64 | 1.000 | 1104 / 1104 |
| 65 | 0.577 | 2208 / 3824 |
| 97 | 0.289 | 2208 / 7632 |
| 128 | 0.574 | 4384 / 7632 |
| 256 | 0.669 | 8736 / 13056 |
| 1024 | 0.890 | 34848 / 39168 |
| 16384 | 0.992 | 557088 / 561408 |

## Open leads

- nqp-level hit at 65 (fresh migration, 128 slots at 51 percent load) 1.26 while the C-API hit is 0.73; cause not investigated.

## Notes

- nqp-level RSS figures are the whole nqp process and move with the GC heap, not the hash: not read.
- The Small tier is the same code in both builds; the 16-64 differences that remain are code layout in the shared dispatch (iterate at 1.04 capi) and noise.
- The 49-entry outliers (nqp iterate 2.40, overwrite 2.36, spreads like 9.87-37.89) are resize-cell noise: the 49 cells include a first-run warm-up that dominates the per-run range.
