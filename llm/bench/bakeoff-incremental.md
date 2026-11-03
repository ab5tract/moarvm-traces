# Bake-off: incremental resize on the ORDERED tier (2026-11-03, Task 10)

**Outcome: reverted.** The flag's `insert_nth` win is one ladder size (65, ratio 0.63); the
win rule needs two adjacent sizes. It also loses four other cells (below). No incremental
code remains on the branch; this record is what is kept.

## Design

The plan's "## Incremental resize" section has the one-page design. In short: with
`ordered.Tier(.{ .incremental = true })`, `grow` allocates the 2x block, copies the dense
entries (positions are kept) and copies the old index into a region after the entries
(`Control.has_old`), and sets `Control.moved = 0`. Each following insert registers
`moves_per_insert` = 2 old entries in the new index, in position order; the last sets
`moved` to done. While moving, a lookup that misses the new index probes the old one; an
insert probes both before appending; a delete finishes the move first. All state is a
counter and offsets inside the one block, so a verbatim copy works mid-move and no
`table.zig` hook was needed. Unit tests (in `tiers/ordered.zig`): reachability at every
step across 3000 inserts and 8+ grows, exact move schedule, found-during-move, delete
finishing the move, fsck faults in a partial state, verbatim copy mid-move, two
random-op runs against `std.AutoHashMap` (one grow-heavy); RED before the implementation
(6 failing tests), GREEN after.

## Measurement

MoarVM eb49b1253 (flag + temporary strategy 3 = set 4, `ordered.Tier(.{ .incremental = true })`),
default options, LTO on, installed in /tmp/claude-1000/tune-zig-prefix with the nqp of branch
zig-hash-strategies.
`tools/bench/hash-bakeoff.sh --strategies=2,3 --rounds=7` with the defaults (`--runs=5
--nth=all --hint=0`, sizes 4 16 32 63 64 65 128 256 1024 16384 plus 49 97), then the resize
cells again with `--sizes=49,97`. Ratios are strategy 3 over strategy 2 (`--base=2`), in the same
rounds, order rotated per round. 1512 + 252 rows (raw: `bakeoff-incremental-raw.tsv`,
`bakeoff-incremental-raw-resize.tsv`). Load (1-minute average before each run): 1.27-1.35 for
the main run, 1.17-1.27 for the resize run; no other `hash-bench.nqp` was running.
Cells: `ratio [min-max of the round medians, ns] mem`; s2 is the unflagged ORDERED, s3 the flagged.

### main run: insert

| size | s2 | s3 |
|---:|---:|---:|
| 4 | 1.00 [27.61-31.89] mem 1.00 - | 0.94 [28.65-31.02] mem 0.89 - |
| 16 | 1.00 [27.17-28.82] mem 1.00 - | 1.00 [26.85-29.66] mem 1.25 - |
| 32 | 1.00 [28.17-29.92] mem 1.00 - | 0.99 [28.15-32.63] mem 1.00 - |
| 49 | 1.00 [32.09-36.28] mem 1.00 - | 0.99 [31.63-35.93] mem 1.00 - |
| 63 | 1.00 [29.35-31.18] mem 1.00 - | 1.01 [29.38-32.76] mem 1.00 - |
| 64 | 1.00 [27.51-28.26] mem - - | 1.00 [26.87-28.75] mem - - |
| 65 | 1.00 [39.27-43.07] mem 1.00 - | 0.91 [35.16-37.48] mem 1.30 - |
| 97 | 1.00 [35.32-36.24] mem 1.00 - | 0.95 [32.81-35.79] mem 1.00 - |
| 128 | 1.00 [30.23-32.70] mem 1.00 - | 1.00 [30.18-32.01] mem 1.11 - |
| 256 | 1.00 [31.01-31.93] mem 1.00 - | 1.09 [31.56-35.81] mem 1.00 - |
| 1024 | 1.00 [32.18-35.99] mem 1.00 - | 1.06 [36.48-37.92] mem 1.00 - |
| 16384 | 1.00 [37.95-38.71] mem 1.00 - | 1.12 [40.21-44.17] mem 1.09 - |

### main run: lookup_hit

| size | s2 | s3 |
|---:|---:|---:|
| 4 | 1.00 [11.16-14.52] mem 1.00 - | 1.02 [11.28-14.28] mem 0.89 - |
| 16 | 1.00 [11.03-12.11] mem 1.00 - | 1.02 [10.78-13.21] mem 1.25 - |
| 32 | 1.00 [11.73-12.51] mem 1.00 - | 0.99 [11.36-12.68] mem 1.00 - |
| 49 | 1.00 [11.18-12.62] mem 1.00 - | 1.01 [12.14-12.78] mem 1.00 - |
| 63 | 1.00 [11.35-12.74] mem 1.00 - | 0.98 [11.77-13.05] mem 1.00 - |
| 64 | 1.00 [11.85-13.08] mem - - | 1.00 [11.92-13.47] mem - - |
| 65 | 1.00 [11.87-14.23] mem 1.00 - | 1.24 [15.83-17.81] mem 1.30 - |
| 97 | 1.00 [11.61-12.87] mem 1.00 - | 1.00 [11.85-13.36] mem 1.00 - |
| 128 | 1.00 [11.94-13.35] mem 1.00 - | 0.98 [12.22-13.57] mem 1.11 - |
| 256 | 1.00 [12.77-14.38] mem 1.00 - | 1.01 [13.05-14.32] mem 1.00 - |
| 1024 | 1.00 [14.94-15.68] mem 1.00 - | 0.98 [14.86-15.91] mem 1.00 - |
| 16384 | 1.00 [19.12-19.51] mem 1.00 - | 1.01 [19.32-20.94] mem 1.09 - |

### main run: lookup_miss

| size | s2 | s3 |
|---:|---:|---:|
| 4 | 1.00 [10.08-14.70] mem 1.00 - | 1.13 [11.33-16.17] mem 0.89 - |
| 16 | 1.00 [10.57-11.47] mem 1.00 - | 1.03 [10.84-11.54] mem 1.25 - |
| 32 | 1.00 [10.90-11.91] mem 1.00 - | 1.01 [10.79-11.94] mem 1.00 - |
| 49 | 1.00 [10.83-12.03] mem 1.00 - | 0.99 [11.21-12.00] mem 1.00 - |
| 63 | 1.00 [11.43-13.13] mem 1.00 - | 1.03 [12.01-12.99] mem 1.00 - |
| 64 | 1.00 [11.88-13.30] mem - - | 1.04 [11.51-13.68] mem - - |
| 65 | 1.00 [10.66-12.11] mem 1.00 - | 1.32 [15.21-16.16] mem 1.30 - |
| 97 | 1.00 [11.38-12.60] mem 1.00 - | 1.03 [11.81-12.74] mem 1.00 - |
| 128 | 1.00 [12.90-14.12] mem 1.00 - | 1.00 [13.05-14.62] mem 1.11 - |
| 256 | 1.00 [14.89-16.07] mem 1.00 - | 1.01 [14.84-15.84] mem 1.00 - |
| 1024 | 1.00 [16.94-17.56] mem 1.00 - | 1.01 [17.09-17.54] mem 1.00 - |
| 16384 | 1.00 [20.85-21.42] mem 1.00 - | 1.01 [21.09-21.65] mem 1.09 - |

### main run: delete

| size | s2 | s3 |
|---:|---:|---:|
| 4 | 1.00 [18.35-20.15] mem 1.00 - | 1.04 [18.40-22.16] mem 0.89 - |
| 16 | 1.00 [18.53-20.25] mem 1.00 - | 1.02 [18.88-21.55] mem 1.25 - |
| 32 | 1.00 [19.34-20.40] mem 1.00 - | 1.01 [19.46-20.89] mem 1.00 - |
| 49 | 1.00 [18.90-19.57] mem 1.00 - | 1.05 [19.31-20.53] mem 1.00 - |
| 63 | 1.00 [19.45-20.13] mem 1.00 - | 1.01 [19.93-20.87] mem 1.00 - |
| 64 | 1.00 [19.34-20.15] mem - - | 1.05 [19.85-21.18] mem - - |
| 65 | 1.00 [18.66-19.36] mem 1.00 - | 1.11 [20.48-21.91] mem 1.30 - |
| 97 | 1.00 [18.99-20.19] mem 1.00 - | 1.02 [19.77-20.68] mem 1.00 - |
| 128 | 1.00 [20.26-21.89] mem 1.00 - | 1.03 [20.72-21.61] mem 1.11 - |
| 256 | 1.00 [22.31-25.72] mem 1.00 - | 1.05 [23.80-26.31] mem 1.00 - |
| 1024 | 1.00 [27.30-28.69] mem 1.00 - | 1.02 [27.84-28.95] mem 1.00 - |
| 16384 | 1.00 [33.03-33.69] mem 1.00 - | 1.03 [33.74-35.02] mem 1.09 - |

### main run: iterate

| size | s2 | s3 |
|---:|---:|---:|
| 4 | 1.00 [14.74-20.53] mem 1.00 - | 0.91 [14.69-18.93] mem 0.89 - |
| 16 | 1.00 [11.39-12.49] mem 1.00 - | 0.99 [11.27-11.68] mem 1.25 - |
| 32 | 1.00 [10.54-10.98] mem 1.00 - | 1.02 [10.54-10.99] mem 1.00 - |
| 49 | 1.00 [10.22-12.34] mem 1.00 - | 0.98 [10.25-12.48] mem 1.00 - |
| 63 | 1.00 [10.06-10.50] mem 1.00 - | 0.99 [10.03-10.50] mem 1.00 - |
| 64 | 1.00 [10.15-10.73] mem - - | 1.02 [10.04-10.68] mem - - |
| 65 | 1.00 [10.08-10.57] mem 1.00 - | 1.01 [10.02-11.11] mem 1.30 - |
| 97 | 1.00 [9.92-11.44] mem 1.00 - | 0.96 [9.85-10.82] mem 1.00 - |
| 128 | 1.00 [9.87-10.38] mem 1.00 - | 0.96 [9.77-10.43] mem 1.11 - |
| 256 | 1.00 [9.64-10.17] mem 1.00 - | 1.00 [9.62-10.10] mem 1.00 - |
| 1024 | 1.00 [9.52-10.16] mem 1.00 - | 0.96 [9.52-10.00] mem 1.00 - |
| 16384 | 1.00 [9.45-9.97] mem 1.00 - | 0.97 [9.41-9.92] mem 1.09 - |

### main run: insert_nth

| size | s2 | s3 |
|---:|---:|---:|
| 4 | 1.00 [14.43-16.42] mem 1.00 - | 1.09 [14.71-20.57] mem 0.89 - |
| 16 | 1.00 [14.04-21.43] mem 1.00 - | 1.62 [15.67-33.54] mem 1.25 - |
| 32 | 1.00 [16.40-29.32] mem 1.00 - | 0.99 [15.31-45.14] mem 1.00 - |
| 49 | 1.00 [16.45-32.76] mem 1.00 - | 0.97 [16.62-44.41] mem 1.00 - |
| 63 | 1.00 [29.28-78.53] mem 1.00 - | 1.38 [29.20-99.99] mem 1.00 - |
| 64 | 1.00 [35.43-81.89] mem - - | 1.40 [43.71-123.22] mem - - |
| 65 | 1.00 [735.13-790.83] mem 1.00 - | 0.63 [436.76-497.69] mem 1.30 win |
| 97 | 1.00 [17.11-26.44] mem 1.00 - | 0.88 [17.35-35.82] mem 1.00 - |
| 128 | 1.00 [16.95-46.18] mem 1.00 - | 0.82 [17.16-33.91] mem 1.11 - |
| 256 | 1.00 [18.59-38.75] mem 1.00 - | 1.05 [18.86-35.54] mem 1.00 - |
| 1024 | 1.00 [22.55-39.77] mem 1.00 - | 0.69 [24.27-39.14] mem 1.00 - |
| 16384 | 1.00 [37.50-87.50] mem 1.00 - | 1.10 [40.00-100.25] mem 1.09 - |

### main run: overwrite

| size | s2 | s3 |
|---:|---:|---:|
| 4 | 1.00 [16.36-40.51] mem 1.00 - | 0.99 [16.26-18.79] mem 0.89 - |
| 16 | 1.00 [16.76-34.51] mem 1.00 - | 1.00 [16.70-19.23] mem 1.25 - |
| 32 | 1.00 [17.94-36.72] mem 1.00 - | 0.97 [17.49-19.47] mem 1.00 - |
| 49 | 1.00 [16.61-37.23] mem 1.00 - | 1.01 [17.51-19.38] mem 1.00 - |
| 63 | 1.00 [17.10-36.99] mem 1.00 - | 1.04 [18.18-19.61] mem 1.00 - |
| 64 | 1.00 [17.43-33.98] mem - - | 1.05 [18.29-19.71] mem - - |
| 65 | 1.00 [16.86-38.31] mem 1.00 - | 1.28 [21.69-23.15] mem 1.30 - |
| 97 | 1.00 [17.05-36.66] mem 1.00 - | 1.01 [17.55-19.45] mem 1.00 - |
| 128 | 1.00 [17.91-36.64] mem 1.00 - | 1.01 [18.13-20.05] mem 1.11 - |
| 256 | 1.00 [18.68-38.02] mem 1.00 - | 1.01 [19.18-20.96] mem 1.00 - |
| 1024 | 1.00 [21.02-40.03] mem 1.00 - | 0.99 [20.83-22.04] mem 1.00 - |
| 16384 | 1.00 [25.32-49.37] mem 1.00 - | 1.01 [25.53-26.65] mem 1.09 - |

### main run: clone

| size | s2 | s3 |
|---:|---:|---:|
| 4 | 1.00 [14.10-16.46] mem 1.00 - | 0.97 [12.35-16.08] mem 0.89 - |
| 16 | 1.00 [5.63-8.49] mem 1.00 - | 1.02 [8.39-8.84] mem 1.25 - |
| 32 | 1.00 [7.50-7.85] mem 1.00 - | 1.02 [4.98-8.03] mem 1.00 - |
| 49 | 1.00 [7.92-8.09] mem 1.00 - | 1.00 [7.61-8.27] mem 1.00 - |
| 63 | 1.00 [6.94-8.04] mem 1.00 - | 0.98 [4.74-8.08] mem 1.00 - |
| 64 | 1.00 [5.00-5.14] mem - - | 0.99 [4.99-5.22] mem - - |
| 65 | 1.00 [7.83-9.23] mem 1.00 - | 1.06 [7.72-9.72] mem 1.30 - |
| 97 | 1.00 [4.95-8.11] mem 1.00 - | 1.03 [7.17-8.21] mem 1.00 - |
| 128 | 1.00 [4.53-7.71] mem 1.00 - | 0.96 [4.58-7.59] mem 1.11 - |
| 256 | 1.00 [7.19-7.58] mem 1.00 - | 1.00 [6.91-7.44] mem 1.00 - |
| 1024 | 1.00 [4.38-7.37] mem 1.00 - | 1.29 [6.68-7.21] mem 1.00 - |
| 16384 | 1.00 [4.16-7.21] mem 1.00 - | 0.99 [6.84-7.14] mem 1.09 - |

### main run: iterate_delete

| size | s2 | s3 |
|---:|---:|---:|
| 4 | 1.00 [31.74-34.31] mem 1.00 - | 1.05 [31.99-35.26] mem 0.89 - |
| 16 | 1.00 [27.62-28.91] mem 1.00 - | 1.03 [28.57-29.67] mem 1.25 - |
| 32 | 1.00 [28.24-29.20] mem 1.00 - | 1.02 [28.79-29.70] mem 1.00 - |
| 49 | 1.00 [27.78-30.39] mem 1.00 - | 1.00 [28.24-29.49] mem 1.00 - |
| 63 | 1.00 [27.24-28.15] mem 1.00 - | 1.04 [28.24-29.04] mem 1.00 - |
| 64 | 1.00 [27.28-28.55] mem - - | 1.03 [28.29-29.99] mem - - |
| 65 | 1.00 [27.34-28.34] mem 1.00 - | 1.05 [27.84-29.45] mem 1.30 - |
| 97 | 1.00 [27.21-27.84] mem 1.00 - | 1.03 [28.13-29.22] mem 1.00 - |
| 128 | 1.00 [27.66-29.40] mem 1.00 - | 1.04 [29.06-30.38] mem 1.11 - |
| 256 | 1.00 [29.84-31.65] mem 1.00 - | 1.04 [31.02-32.33] mem 1.00 - |
| 1024 | 1.00 [32.62-33.26] mem 1.00 - | 1.03 [33.12-34.41] mem 1.00 - |
| 16384 | 1.00 [37.39-37.76] mem 1.00 - | 1.03 [38.28-38.97] mem 1.09 - |

### Resize cells run (sizes 49, 97, second run)

#### insert

| size | s2 | s3 |
|---:|---:|---:|
| 49 | 1.00 [29.86-41.82] mem 1.00 - | 0.97 [28.47-37.75] mem 0.96 - |
| 97 | 1.00 [35.02-37.36] mem 1.00 - | 0.98 [33.92-36.83] mem 1.00 - |

#### lookup_hit

| size | s2 | s3 |
|---:|---:|---:|
| 49 | 1.00 [44.47-49.39] mem 1.00 - | 0.33 [15.41-46.97] mem 0.96 - |
| 97 | 1.00 [12.61-13.60] mem 1.00 - | 0.98 [12.35-13.35] mem 1.00 - |

#### lookup_miss

| size | s2 | s3 |
|---:|---:|---:|
| 49 | 1.00 [16.45-52.05] mem 1.00 - | 0.32 [14.16-48.26] mem 0.96 - |
| 97 | 1.00 [11.76-13.60] mem 1.00 - | 1.02 [11.37-13.31] mem 1.00 - |

#### delete

| size | s2 | s3 |
|---:|---:|---:|
| 49 | 1.00 [19.39-23.29] mem 1.00 - | 0.90 [19.52-23.43] mem 0.96 - |
| 97 | 1.00 [19.78-20.69] mem 1.00 - | 1.01 [20.22-21.17] mem 1.00 - |

#### iterate

| size | s2 | s3 |
|---:|---:|---:|
| 49 | 1.00 [13.23-17.85] mem 1.00 - | 0.90 [10.69-16.82] mem 0.96 - |
| 97 | 1.00 [9.94-10.39] mem 1.00 - | 0.99 [9.91-10.47] mem 1.00 - |

#### insert_nth

| size | s2 | s3 |
|---:|---:|---:|
| 49 | 1.00 [17.83-40.92] mem 1.00 - | 0.98 [19.51-36.95] mem 0.96 - |
| 97 | 1.00 [49.64-136.68] mem 1.00 - | 0.99 [53.39-153.34] mem 1.00 - |

#### overwrite

| size | s2 | s3 |
|---:|---:|---:|
| 49 | 1.00 [19.94-22.07] mem 1.00 - | 0.90 [17.75-21.44] mem 0.96 - |
| 97 | 1.00 [18.04-19.21] mem 1.00 - | 1.00 [17.88-18.98] mem 1.00 - |

#### clone

| size | s2 | s3 |
|---:|---:|---:|
| 49 | 1.00 [5.15-8.16] mem 1.00 - | 1.01 [5.24-7.70] mem 0.96 - |
| 97 | 1.00 [4.96-8.29] mem 1.00 - | 1.04 [7.61-8.00] mem 1.00 - |

#### iterate_delete

| size | s2 | s3 |
|---:|---:|---:|
| 49 | 1.00 [30.15-31.33] mem 1.00 - | 1.02 [28.04-33.12] mem 0.96 - |
| 97 | 1.00 [28.31-29.16] mem 1.00 - | 1.03 [28.74-30.15] mem 1.00 - |


## The rule, cell by cell

Win: ratio <= 0.90 with the round spreads disjoint. Loss: ratio >= 1.05 with disjoint spreads.

**insert_nth (decides)** ladder sizes: 16 1.62 (overlap), 32 0.99, 63 1.38 (overlap), 64 1.40
(overlap), **65 0.63 win** ([436.76-497.69] vs [735.13-790.83]), 128 0.82 (overlap:
[17.16-33.91] vs [16.95-46.18]), 256 1.05 (overlap), 1024 0.69 (overlap), 16384 1.10 (overlap).
The only win is 65; its neighbours 64 (1.40) and 128 (0.82, overlap) do not win. No two adjacent
wins: **the win condition fails.** (The spike at 65 is spread as designed: 735 to 437-498 ns
over the 65th insert; but the cost moves to the table's life after the grow.)

**Cells that lose (disjoint spreads, ratio >= 1.05):**
- lookup_hit 65: 1.24 [15.83-17.81] vs [11.87-14.23]
- lookup_miss 65: 1.32 [15.21-16.16] vs [10.66-12.11]
- delete 65: 1.11 [20.48-21.91] vs [18.66-19.36]
- insert 16384: 1.12 [40.21-44.17] vs [37.95-38.71]

Why 65: a table of exactly 65 entries has just grown and has had one insert since, so it is
mid-move for the whole of the read phase, and every miss in the new index probes the old one
too (and the block is 1.30x the memory, the old index kept). Other 5%-plus ratios (delete 64 and
256 at 1.05, overwrite 65 1.28, insert 256 1.09, 1024 1.06, clone 1024 1.29, iterate_delete 65
1.05) have overlapping spreads and do not count.

**Not-lose condition fails** (four cells), and **the win condition fails**: both must hold to
keep. **Reverted.**

## Concern for any future retry

The benefit is confined to the single insert that grows; for tables that stop growing just after
a doubling the lookup cost is a flat tax. A variant that finishes the move on the first read, or
a block that rebuilds eagerly below some size, would remove the 65 tax but not the 16384 insert
loss, and the one-size win would remain.
