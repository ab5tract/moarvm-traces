# Bake-off composed set for LOOKUP: Small then Swiss (2026-11-03)

**Outcome: does not ship.** LOOKUP is the bare Swiss tier (`swiss_only`,
the scoreboard's strategy 1, already spectested as
`bakeoff-spectest-s1.txt`); the composed set is deleted.

## What was measured

The composed set is the default ladder with the Swiss-style tier in place
of Robin Hood: Small (`max_capacity` 64) from 0, `tiers/swiss.zig` from 64,
so a hash is in Small to 64 entries and Swiss from 65. It was built into
the string table as set 4 and exposed as a temporary strategy 3
(`MVM_HASH_STRATEGY_SMALL_SWISS`), after the fixed-key strategy 3 had been
deleted (MoarVM 02257560b). The measured build is 02257560b plus that set
(the MoarVM commit that bumps this record), default options, LTO on,
installed into one prefix with the nqp of branch zig-hash-strategies.

Method, the same as the scoreboard's (plan "## Scoreboard"):
- `tools/bench/hash-bakeoff.sh --strategies=0,3 --rounds=7 --runs=5 --nth=all --hint=0`, ladder `--sizes=4,16,32,63,64,65,128,256,1024,16384`, then the resize cells `--sizes=49,97` in a second run. Strategy order rotated per round.
- 1260 + 252 rows, as expected (7 rounds x 2 strategies x (10 sizes x 9 ops) and (2 x 9)).
- The harness no longer has `bulk_load` (it timed insert then `nqp::hashseal`, both deleted with strategy 3), so there are nine ops.
- Load (1-minute average before each run): 1.25-1.31 for the ladder, 1.29-1.31 for the resize cells. No other `hash-bench.nqp` was running.
- A ratio is the composed set's median of round medians over strategy 0's in the same rounds; a win is a ratio at or below 0.90 with disjoint round spreads; a block is two or more adjacent winning ladder sizes.

## The rule (controller ruling 2)

The composed set ships as LOOKUP only if
- (a) it keeps every single-op block strategy 1 holds in the final scoreboard (bulk_load excluded, it no longer exists), and
- (b) its 16-64 cells are within 5 percent of strategy 0 or inside the round spread (strategy 0's and its spreads overlap), since it is the same Small tier there.

### (a) Strategy 1's blocks, cell by cell

A cell keeps the block only with a win (ratio <= 0.90, spreads disjoint).

| block (strategy 1) | composed set's cells | kept |
|---|---|---|
| insert 128-16384 | 128 0.84 win, 256 0.84 win, 1024 0.87 win, 16384 0.85 win | yes |
| lookup_hit 65-256 | 65 1.20, 128 0.92, 256 0.87 win | **no** (65, 128) |
| lookup_miss 63-16384 | 63 1.14, 64 1.12, 65 0.89 (spreads overlap), 128 0.78 win, 256 0.81 win, 1024 0.81 win, 16384 0.81 win | **no** (63-65) |
| delete 65-256 | 65 1.02, 128 0.92, 256 0.92 | **no** (all) |
| iterate 65-16384 | 65 0.75, 128 0.74, 256 0.74, 1024 0.73, 16384 0.73, all win | yes |
| insert_nth 65-1024 | 65 0.77 win, 128 1.06, 256 0.85 (overlap), 1024 0.87 (overlap) | **no** (128-1024) |
| overwrite 65-16384 | 65 1.04, 128 0.93, 256 0.93, 1024 0.96, 16384 1.00 | **no** (all) |
| clone 65-256 | 65 0.69 win, 128 0.63 win, 256 0.64 win | yes |
| iterate_delete 65-16384 | 65 0.88, 128 0.84, 256 0.85, 1024 0.85, 16384 0.87, all win | yes |

(a) fails: five of strategy 1's nine single-op blocks are lost (lookup_hit,
lookup_miss, delete, insert_nth, overwrite).

### (b) The 16-64 cells

Within 5 percent (ratio 0.95-1.05) or overlapping round spreads passes; a failing cell shows the composed set's spread against strategy 0's.

| op | 16 | 32 | 63 | 64 | passes |
|---|---|---|---|---|---|
| insert | 1.01 | 1.01 | 1.02 | 1.05 | yes |
| lookup_hit | 1.15 [12.10-12.80] vs [10.56-11.03] | 1.11 overlap | 1.12 overlap | 1.08 overlap | **no** (16) |
| lookup_miss | 1.18 [11.83-12.60] vs [9.69-10.51] | 1.15 [11.69-13.26] vs [9.94-11.49] | 1.14 overlap | 1.12 overlap | **no** (16, 32) |
| delete | 1.19 overlap | 1.13 overlap | 1.14 overlap | 1.16 overlap | yes (strategy 0's delete spreads are wide, 10-19 ns) |
| iterate | 1.07 [11.65-11.86] vs [10.86-11.37] | 1.04 | 0.95 | 0.99 | **no** (16) |
| insert_nth | 1.02 | 1.04 | 0.94 overlap | 1.03 | yes |
| overwrite | 1.01 | 1.03 | 1.02 | 1.01 | yes |
| clone | 1.25 overlap | 1.21 [7.68-8.23] vs [3.78-6.60] | 0.82 overlap | 1.23 overlap | **no** (32) |
| iterate_delete | 1.14 [24.09-26.27] vs [21.12-22.15] | 1.17 [23.57-26.76] vs [20.30-22.60] | 1.13 [23.82-26.45] vs [20.20-23.11] | 1.12 [24.45-26.72] vs [20.33-22.81] | **no** (16, 32, 63, 64) |

(b) fails too: lookup_hit at 16, lookup_miss at 16 and 32, iterate at
16, clone at 32 and iterate_delete at every size from 16 to 64 are 7-21
percent slower with disjoint spreads, although the tier is the same Small tier as strategy 0's.
The likely cause (not isolated) is dispatch: `table.zig` specialises only
set 0, so the composed set's Small rung is reached through the out-of-line
`dispatchOtherCall` and the general `resolve` path, where set 0's Small is
an inline switch. Above 64 the composed set also pays a two-rung dispatch
and migrates at 65, where the bare Swiss tier has neither; that fits it
losing lookup_hit, delete and overwrite at 65-256, which strategy 1 won.

## Outcome

Both (a) and (b) fail, so the composed set does not ship: LOOKUP is the
bare `swiss_only` set (strategy 1 of the scoreboard), which gives up 16-64
as the scoreboard records (insert 1.6-1.85x, clone 1.5-1.9x, memory
2.0-2.2x there). No spectest was run for the composed set (the ruling asks
for one only if it ships). The composed set, its strategy slot and its
tests are deleted in the renaming commit.

## Ladder cells (aggregator output, verbatim; s3 is the composed set)

### insert

| size | s0 | s3 |
|---:|---:|---:|
| 4 | 1.00 [25.84-30.66] mem 1.00 - | 1.03 [25.71-31.50] mem 1.25 - |
| 16 | 1.00 [24.56-25.48] mem 1.00 - | 1.01 [25.14-25.89] mem 1.00 - |
| 32 | 1.00 [24.34-25.47] mem 1.00 - | 1.01 [24.31-26.00] mem 1.00 - |
| 63 | 1.00 [24.88-28.19] mem 1.00 - | 1.02 [24.94-27.35] mem 1.00 - |
| 64 | 1.00 [24.54-25.53] mem 1.00 - | 1.05 [24.59-26.52] mem 1.11 - |
| 65 | 1.00 [38.35-39.57] mem 1.00 - | 0.96 [35.17-37.73] mem 0.29 - |
| 128 | 1.00 [47.50-49.60] mem 1.00 - | 0.84 [39.78-44.37] mem 0.61 win |
| 256 | 1.00 [48.99-52.25] mem 1.00 - | 0.84 [40.66-44.94] mem 0.77 win |
| 1024 | 1.00 [50.90-52.84] mem 1.00 - | 0.87 [42.34-45.45] mem 0.86 win |
| 16384 | 1.00 [53.78-59.12] mem 1.00 - | 0.85 [45.23-48.61] mem 0.90 win |

### lookup_hit

| size | s0 | s3 |
|---:|---:|---:|
| 4 | 1.00 [11.05-14.22] mem 1.00 - | 1.14 [12.59-16.11] mem 1.25 - |
| 16 | 1.00 [10.56-11.03] mem 1.00 - | 1.15 [12.10-12.80] mem 1.00 - |
| 32 | 1.00 [10.09-11.65] mem 1.00 - | 1.11 [11.62-12.72] mem 1.00 - |
| 63 | 1.00 [10.91-12.68] mem 1.00 - | 1.12 [12.55-14.46] mem 1.00 - |
| 64 | 1.00 [10.87-12.82] mem 1.00 - | 1.08 [12.58-14.96] mem 1.11 - |
| 65 | 1.00 [13.77-15.42] mem 1.00 - | 1.20 [16.32-17.95] mem 0.29 - |
| 128 | 1.00 [13.63-13.92] mem 1.00 - | 0.92 [11.95-13.20] mem 0.61 - |
| 256 | 1.00 [13.74-14.00] mem 1.00 - | 0.87 [11.70-12.71] mem 0.77 win |
| 1024 | 1.00 [14.05-14.61] mem 1.00 - | 0.92 [12.76-13.23] mem 0.86 - |
| 16384 | 1.00 [15.34-15.92] mem 1.00 - | 0.98 [14.83-15.99] mem 0.90 - |

### lookup_miss

| size | s0 | s3 |
|---:|---:|---:|
| 4 | 1.00 [10.40-14.46] mem 1.00 - | 1.48 [12.51-19.13] mem 1.25 - |
| 16 | 1.00 [9.69-10.51] mem 1.00 - | 1.18 [11.83-12.60] mem 1.00 - |
| 32 | 1.00 [9.94-11.49] mem 1.00 - | 1.15 [11.69-13.26] mem 1.00 - |
| 63 | 1.00 [11.14-13.02] mem 1.00 - | 1.14 [12.17-14.10] mem 1.00 - |
| 64 | 1.00 [10.93-12.64] mem 1.00 - | 1.12 [12.18-13.98] mem 1.11 - |
| 65 | 1.00 [13.52-13.75] mem 1.00 - | 0.89 [11.30-13.56] mem 0.29 - |
| 128 | 1.00 [13.41-13.56] mem 1.00 - | 0.78 [10.12-10.97] mem 0.61 win |
| 256 | 1.00 [13.43-13.61] mem 1.00 - | 0.81 [10.39-11.23] mem 0.77 win |
| 1024 | 1.00 [13.33-13.57] mem 1.00 - | 0.81 [10.65-10.99] mem 0.86 win |
| 16384 | 1.00 [14.50-14.97] mem 1.00 - | 0.81 [11.66-12.04] mem 0.90 win |

### delete

| size | s0 | s3 |
|---:|---:|---:|
| 4 | 1.00 [11.05-18.52] mem 1.00 - | 1.18 [13.01-13.50] mem 1.25 - |
| 16 | 1.00 [10.18-17.29] mem 1.00 - | 1.19 [12.18-12.28] mem 1.00 - |
| 32 | 1.00 [11.28-18.94] mem 1.00 - | 1.13 [12.62-13.72] mem 1.00 - |
| 63 | 1.00 [11.62-19.17] mem 1.00 - | 1.14 [13.27-14.95] mem 1.00 - |
| 64 | 1.00 [11.69-18.93] mem 1.00 - | 1.16 [13.29-15.02] mem 1.11 - |
| 65 | 1.00 [13.21-21.24] mem 1.00 - | 1.02 [13.17-14.48] mem 0.29 - |
| 128 | 1.00 [13.20-21.08] mem 1.00 - | 0.92 [11.87-12.65] mem 0.61 - |
| 256 | 1.00 [13.26-21.36] mem 1.00 - | 0.92 [12.00-12.95] mem 0.77 - |
| 1024 | 1.00 [13.48-21.78] mem 1.00 - | 0.95 [12.90-13.36] mem 0.86 - |
| 16384 | 1.00 [15.02-21.94] mem 1.00 - | 1.00 [14.95-15.65] mem 0.90 - |

### iterate

| size | s0 | s3 |
|---:|---:|---:|
| 4 | 1.00 [14.20-17.35] mem 1.00 - | 1.13 [17.43-18.84] mem 1.25 - |
| 16 | 1.00 [10.86-11.37] mem 1.00 - | 1.07 [11.65-11.86] mem 1.00 - |
| 32 | 1.00 [10.01-12.98] mem 1.00 - | 1.04 [10.86-13.07] mem 1.00 - |
| 63 | 1.00 [10.98-11.29] mem 1.00 - | 0.95 [10.45-12.08] mem 1.00 - |
| 64 | 1.00 [9.61-11.10] mem 1.00 - | 0.99 [10.39-12.19] mem 1.11 - |
| 65 | 1.00 [15.15-15.63] mem 1.00 - | 0.75 [11.36-11.52] mem 0.29 win |
| 128 | 1.00 [14.99-15.53] mem 1.00 - | 0.74 [10.95-11.16] mem 0.61 win |
| 256 | 1.00 [14.80-15.32] mem 1.00 - | 0.74 [10.96-11.04] mem 0.77 win |
| 1024 | 1.00 [14.71-14.89] mem 1.00 - | 0.73 [10.80-11.11] mem 0.86 win |
| 16384 | 1.00 [14.59-15.00] mem 1.00 - | 0.73 [10.69-10.90] mem 0.90 win |

### insert_nth

| size | s0 | s3 |
|---:|---:|---:|
| 4 | 1.00 [17.81-18.28] mem 1.00 - | 0.99 [17.87-18.18] mem 1.25 - |
| 16 | 1.00 [17.47-17.61] mem 1.00 - | 1.02 [17.49-18.10] mem 1.00 - |
| 32 | 1.00 [17.59-25.47] mem 1.00 - | 1.04 [17.65-25.14] mem 1.00 - |
| 63 | 1.00 [18.87-29.10] mem 1.00 - | 0.94 [19.05-28.60] mem 1.00 - |
| 64 | 1.00 [22.33-32.88] mem 1.00 - | 1.03 [24.47-35.65] mem 1.11 - |
| 65 | 1.00 [1022.43-1066.26] mem 1.00 - | 0.77 [736.33-884.11] mem 0.29 win |
| 128 | 1.00 [31.41-33.01] mem 1.00 - | 1.06 [27.34-36.28] mem 0.61 - |
| 256 | 1.00 [32.60-46.18] mem 1.00 - | 0.85 [29.32-41.91] mem 0.77 - |
| 1024 | 1.00 [34.75-43.36] mem 1.00 - | 0.87 [32.25-39.77] mem 0.86 - |
| 16384 | 1.00 [62.50-268.00] mem 1.00 - | 1.00 [55.00-120.25] mem 0.90 - |

### overwrite

| size | s0 | s3 |
|---:|---:|---:|
| 4 | 1.00 [18.96-21.93] mem 1.00 - | 1.00 [19.19-20.58] mem 1.25 - |
| 16 | 1.00 [18.34-19.37] mem 1.00 - | 1.01 [18.65-20.99] mem 1.00 - |
| 32 | 1.00 [18.40-19.92] mem 1.00 - | 1.03 [18.80-20.49] mem 1.00 - |
| 63 | 1.00 [19.70-20.92] mem 1.00 - | 1.02 [20.10-21.96] mem 1.00 - |
| 64 | 1.00 [19.62-20.88] mem 1.00 - | 1.01 [20.27-21.93] mem 1.11 - |
| 65 | 1.00 [20.39-20.83] mem 1.00 - | 1.04 [20.77-21.97] mem 0.29 - |
| 128 | 1.00 [20.31-20.60] mem 1.00 - | 0.93 [18.94-19.39] mem 0.61 - |
| 256 | 1.00 [20.27-20.83] mem 1.00 - | 0.93 [18.86-19.51] mem 0.77 - |
| 1024 | 1.00 [20.85-20.98] mem 1.00 - | 0.96 [19.87-20.53] mem 0.86 - |
| 16384 | 1.00 [22.23-22.74] mem 1.00 - | 1.00 [22.23-22.86] mem 0.90 - |

### clone

| size | s0 | s3 |
|---:|---:|---:|
| 4 | 1.00 [10.78-14.01] mem 1.00 - | 1.19 [13.43-14.85] mem 1.25 - |
| 16 | 1.00 [6.78-7.17] mem 1.00 - | 1.25 [6.11-8.86] mem 1.00 - |
| 32 | 1.00 [3.78-6.60] mem 1.00 - | 1.21 [7.68-8.23] mem 1.00 - |
| 63 | 1.00 [3.45-6.73] mem 1.00 - | 0.82 [5.17-8.13] mem 1.00 - |
| 64 | 1.00 [3.46-6.78] mem 1.00 - | 1.23 [5.19-8.34] mem 1.11 - |
| 65 | 1.00 [11.80-14.69] mem 1.00 - | 0.69 [8.37-8.61] mem 0.29 win |
| 128 | 1.00 [14.91-15.22] mem 1.00 - | 0.63 [8.99-12.32] mem 0.61 win |
| 256 | 1.00 [14.18-14.47] mem 1.00 - | 0.64 [8.83-12.39] mem 0.77 win |
| 1024 | 1.00 [10.87-11.49] mem 1.00 - | 0.81 [8.77-11.65] mem 0.86 - |
| 16384 | 1.00 [10.52-11.07] mem 1.00 - | 0.81 [8.37-8.92] mem 0.90 win |

### iterate_delete

| size | s0 | s3 |
|---:|---:|---:|
| 4 | 1.00 [25.93-31.51] mem 1.00 - | 1.08 [28.06-30.23] mem 1.25 - |
| 16 | 1.00 [21.12-22.15] mem 1.00 - | 1.14 [24.09-26.27] mem 1.00 - |
| 32 | 1.00 [20.30-22.60] mem 1.00 - | 1.17 [23.57-26.76] mem 1.00 - |
| 63 | 1.00 [20.20-23.11] mem 1.00 - | 1.13 [23.82-26.45] mem 1.00 - |
| 64 | 1.00 [20.33-22.81] mem 1.00 - | 1.12 [24.45-26.72] mem 1.11 - |
| 65 | 1.00 [26.87-27.40] mem 1.00 - | 0.88 [23.29-24.33] mem 0.29 win |
| 128 | 1.00 [26.73-27.05] mem 1.00 - | 0.84 [22.51-23.13] mem 0.61 win |
| 256 | 1.00 [26.32-26.77] mem 1.00 - | 0.85 [22.31-23.17] mem 0.77 win |
| 1024 | 1.00 [27.03-27.37] mem 1.00 - | 0.85 [22.52-23.65] mem 0.86 win |
| 16384 | 1.00 [32.14-32.82] mem 1.00 - | 0.87 [28.05-29.12] mem 0.90 win |

## Blocks (aggregator, ladder run)

- s3: insert 128-16384
- s3: lookup_miss 128-16384
- s3: iterate 65-16384
- s3: clone 65-256
- s3: iterate_delete 65-16384
- s3 (multi-op): iterate+clone+iterate_delete 65-256
- s3 (multi-op): iterate+iterate_delete 65-16384
- s3 (multi-op): insert+lookup_miss+iterate+clone+iterate_delete 128-256
- s3 (multi-op): insert+lookup_miss+iterate+iterate_delete 128-16384

## Resize cells (49, 97; reported, never blocked)

At 97 strategy 0 grows past its Small tier inside the timed region (Robin Hood) and the composed set grows into Swiss; both migrate. The composed set wins insert 0.56, iterate 0.67, insert_nth 0.05, clone 0.45 and iterate_delete 0.84 at 97. At 49 it wins nothing; delete 1.19, clone 1.48 and iterate_delete 1.10 are behind, but 49 is the first size its process measures and carries warm-up (spreads up to 4x).

### insert

| size | s0 | s3 |
|---:|---:|---:|
| 49 | 1.00 [22.44-28.21] mem 1.00 - | 1.11 [22.43-56.18] mem 1.10 - |
| 97 | 1.00 [56.83-58.50] mem 1.00 - | 0.56 [30.12-34.52] mem 0.32 win |

### lookup_hit

| size | s0 | s3 |
|---:|---:|---:|
| 49 | 1.00 [10.78-46.24] mem 1.00 - | 1.02 [15.69-48.02] mem 1.10 - |
| 97 | 1.00 [12.55-13.34] mem 1.00 - | 0.93 [11.54-12.45] mem 0.32 - |

### lookup_miss

| size | s0 | s3 |
|---:|---:|---:|
| 49 | 1.00 [14.15-47.12] mem 1.00 - | 1.06 [16.51-49.27] mem 1.10 - |
| 97 | 1.00 [11.90-12.01] mem 1.00 - | 0.97 [10.33-12.19] mem 0.32 - |

### delete

| size | s0 | s3 |
|---:|---:|---:|
| 49 | 1.00 [11.75-17.13] mem 1.00 - | 1.19 [14.62-41.06] mem 1.10 - |
| 97 | 1.00 [12.51-12.84] mem 1.00 - | 0.94 [11.72-12.24] mem 0.32 - |

### iterate

| size | s0 | s3 |
|---:|---:|---:|
| 49 | 1.00 [12.39-35.87] mem 1.00 - | 1.01 [13.58-36.02] mem 1.10 - |
| 97 | 1.00 [16.44-16.73] mem 1.00 - | 0.67 [11.18-11.45] mem 0.32 win |

### insert_nth

| size | s0 | s3 |
|---:|---:|---:|
| 49 | 1.00 [19.60-38.75] mem 1.00 - | 1.00 [19.25-43.92] mem 1.10 - |
| 97 | 1.00 [1540.55-1576.77] mem 1.00 - | 0.05 [67.40-130.87] mem 0.32 win |

### overwrite

| size | s0 | s3 |
|---:|---:|---:|
| 49 | 1.00 [20.94-51.95] mem 1.00 - | 1.03 [21.81-51.42] mem 1.10 - |
| 97 | 1.00 [19.40-19.66] mem 1.00 - | 0.97 [18.48-34.28] mem 0.32 - |

### clone

| size | s0 | s3 |
|---:|---:|---:|
| 49 | 1.00 [3.92-6.72] mem 1.00 - | 1.48 [5.60-8.59] mem 1.10 - |
| 97 | 1.00 [17.01-20.42] mem 1.00 - | 0.45 [6.04-9.24] mem 0.32 win |

### iterate_delete

| size | s0 | s3 |
|---:|---:|---:|
| 49 | 1.00 [20.63-25.32] mem 1.00 - | 1.10 [25.21-50.37] mem 1.10 - |
| 97 | 1.00 [27.56-28.10] mem 1.00 - | 0.84 [22.77-24.03] mem 0.32 win |

