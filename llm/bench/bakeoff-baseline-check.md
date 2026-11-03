# Bake-off baseline check (strategy 0), 2026-11-03

Informational (controller ruling): the build's default CPU level became
x86-64-v3 (commit 2d43de657) after the ladder record was taken on the generic
baseline CPU, so cells may move for that reason alone; an out-of-band cell
does not stop the campaign.

**Run.** MoarVM `zig-hash-bakeoff` at c4add6e4c plus the Task 4 harness, nqp
`zig-hash-strategies` (ops mapped), installed in one prefix (LTO, x86-64-v3),
AMD Ryzen 9 5900X. `tools/bench/hash-bakeoff.sh --strategies=0 --rounds=5`
with its defaults (`--sizes=4,16,32,63,64,65,128,256,1024,16384,49,97
--runs=5 --nth=all --hint=0`, all sizes in one process per round): every
hash gets `nqp::hashstrategy(%h, 0, 0)`, size hint 0, so it grows through
its tiers as the record's hashes did. 1-minute load 0.71-0.83 at the run
starts. Raw: `bakeoff-baseline-s0.tsv` (round, strategy, then the harness's
columns), **the campaign's strategy-0 reference** from here on.

**Record.** `tuning-lto-default-il-nqp-zig-lto.tsv` (zig-lto, 9 rounds,
generic CPU, the harness before Task 4) for the ladder sizes;
`tuning-lto-default-nqp-zig-lto-resize.tsv` (9 rounds, `--sizes=49,97` in a
process of their own) for 49 and 97, aggregated the same way (median of the
round medians, min-max of the round medians). Only the six ops the record
has are compared; bulk_load, overwrite, clone and iterate_delete are new.

**Rule.** A cell passes when the strategy-0 median lies within the record's
min-max spread or within 5 percent of its median.

**Columns beyond the check** (5 rounds each, same sizes, load 0.10, not
committed): *presized / hint 0* is the earlier run with `--hint=size` over
this one; *hint 0 / no call* is this run over the harness as at c4add6e4c
(no hashstrategy call, without the four new phases).

## Hint 0 against the record (the reference)

| op | size | s0 hint 0 [min-max] | record [min-max] | s0 / record | check | presized / hint 0 | hint 0 / no call |
|---|---:|---:|---:|---:|---|---:|---:|
| insert | 4 | 24.74 [23.87-25.82] | 56.68 [28.87-60.47] | 0.44 | **out, faster** | 0.78 | 0.41 |
| insert | 16 | 21.30 [20.96-21.95] | 22.28 [21.70-23.82] | 0.96 | within 5% | 0.74 | 0.97 |
| insert | 32 | 18.50 [18.40-19.73] | 21.74 [21.45-23.01] | 0.85 | **out, faster** | 0.83 | 0.87 |
| insert | 63 | 24.27 [21.54-24.67] | 22.75 [21.30-23.27] | 1.07 | **out, slower** | 0.68 | 1.24 |
| insert | 64 | 21.88 [21.19-24.89] | 20.40 [19.17-20.86] | 1.07 | **out, slower** | 1.02 | 0.99 |
| insert | 65 | 37.23 [36.81-37.85] | 39.45 [37.82-40.59] | 0.94 | **out, faster** | 0.55 | 1.00 |
| insert | 128 | 46.77 [45.03-48.62] | 48.57 [47.44-48.85] | 0.96 | within 5% | 0.44 | 1.00 |
| insert | 256 | 48.47 [47.37-50.73] | 49.80 [48.32-51.80] | 0.97 | in spread | 0.42 | 0.99 |
| insert | 1024 | 49.58 [49.17-50.57] | 50.71 [50.56-51.24] | 0.98 | within 5% | 0.42 | 0.99 |
| insert | 16384 | 54.66 [51.73-55.00] | 52.72 [52.41-55.74] | 1.04 | in spread | 0.40 | 1.05 |
| insert | 49 | 24.68 [23.37-25.72] | 54.42 [20.50-61.54] | 0.45 | in spread | 0.67 | 1.10 |
| insert | 97 | 54.02 [53.76-55.36] | 55.85 [55.01-58.31] | 0.97 | within 5% | 0.36 | 1.00 |
| lookup_hit | 4 | 10.80 [10.65-14.43] | 15.67 [10.81-46.59] | 0.69 | **out, faster** | 1.00 | 0.23 |
| lookup_hit | 16 | 10.83 [10.43-10.98] | 10.52 [10.41-11.67] | 1.03 | in spread | 0.97 | 1.00 |
| lookup_hit | 32 | 10.62 [9.71-11.09] | 11.06 [10.26-11.51] | 0.96 | in spread | 0.98 | 0.98 |
| lookup_hit | 63 | 12.31 [11.25-12.63] | 12.62 [11.13-13.10] | 0.98 | in spread | 0.92 | 1.01 |
| lookup_hit | 64 | 12.32 [11.30-12.47] | 12.64 [11.60-13.03] | 0.97 | in spread | 1.08 | 1.02 |
| lookup_hit | 65 | 13.19 [13.13-13.47] | 14.28 [13.42-14.46] | 0.92 | **out, faster** | 1.00 | 0.98 |
| lookup_hit | 128 | 13.21 [13.02-13.44] | 13.23 [13.08-13.55] | 1.00 | in spread | 0.99 | 1.00 |
| lookup_hit | 256 | 13.30 [13.22-13.39] | 13.20 [13.12-13.45] | 1.01 | in spread | 1.00 | 0.99 |
| lookup_hit | 1024 | 13.47 [13.40-13.67] | 13.55 [13.40-13.81] | 0.99 | in spread | 1.00 | 0.99 |
| lookup_hit | 16384 | 14.79 [14.72-14.88] | 14.68 [14.51-14.87] | 1.01 | in spread | 1.00 | 1.00 |
| lookup_hit | 49 | 11.95 [11.02-12.40] | 47.12 [11.70-50.04] | 0.25 | in spread | 0.94 | 1.01 |
| lookup_hit | 97 | 11.90 [11.87-12.07] | 12.19 [12.03-13.42] | 0.98 | within 5% | 1.01 | 1.00 |
| lookup_miss | 4 | 10.10 [10.07-13.77] | 10.38 [10.36-45.79] | 0.97 | within 5% | 1.34 | 0.22 |
| lookup_miss | 16 | 9.58 [9.44-10.89] | 10.06 [9.84-10.52] | 0.95 | within 5% | 1.00 | 0.99 |
| lookup_miss | 32 | 10.04 [9.94-11.20] | 10.41 [10.08-11.63] | 0.96 | within 5% | 1.07 | 1.01 |
| lookup_miss | 63 | 11.65 [11.59-12.06] | 12.33 [11.38-13.41] | 0.94 | in spread | 1.03 | 0.95 |
| lookup_miss | 64 | 11.72 [11.31-12.00] | 12.04 [11.67-13.12] | 0.97 | in spread | 1.10 | 0.98 |
| lookup_miss | 65 | 13.14 [12.97-13.24] | 13.06 [12.92-13.27] | 1.01 | in spread | 0.99 | 1.00 |
| lookup_miss | 128 | 12.90 [12.78-12.98] | 12.91 [12.78-13.03] | 1.00 | in spread | 1.00 | 1.00 |
| lookup_miss | 256 | 12.95 [12.89-12.99] | 12.96 [12.83-13.11] | 1.00 | in spread | 1.01 | 1.00 |
| lookup_miss | 1024 | 12.93 [12.88-13.04] | 12.93 [12.81-13.16] | 1.00 | in spread | 1.01 | 0.99 |
| lookup_miss | 16384 | 13.99 [13.93-14.15] | 13.98 [13.89-14.17] | 1.00 | in spread | 1.01 | 1.00 |
| lookup_miss | 49 | 11.29 [10.74-11.53] | 41.12 [12.17-48.80] | 0.27 | **out, faster** | 1.00 | 1.04 |
| lookup_miss | 97 | 11.34 [11.29-11.40] | 11.50 [11.32-11.67] | 0.99 | in spread | 1.01 | 0.99 |
| delete | 4 | 10.80 [10.62-10.94] | 13.73 [11.21-42.86] | 0.79 | **out, faster** | 1.01 | 0.26 |
| delete | 16 | 10.09 [9.93-10.24] | 10.53 [10.45-19.38] | 0.96 | within 5% | 1.00 | 0.99 |
| delete | 32 | 10.76 [10.75-10.86] | 11.75 [11.36-19.70] | 0.92 | **out, faster** | 1.02 | 0.90 |
| delete | 63 | 11.91 [11.82-12.55] | 12.69 [11.80-20.20] | 0.94 | in spread | 1.02 | 0.99 |
| delete | 64 | 12.08 [11.55-12.52] | 13.02 [12.52-20.52] | 0.93 | **out, faster** | 1.10 | 1.01 |
| delete | 65 | 13.25 [13.15-13.43] | 13.48 [13.29-13.74] | 0.98 | within 5% | 1.00 | 1.01 |
| delete | 128 | 13.04 [12.94-13.30] | 13.34 [13.02-13.91] | 0.98 | in spread | 1.00 | 1.00 |
| delete | 256 | 13.18 [12.91-13.25] | 13.23 [13.14-13.80] | 1.00 | in spread | 0.99 | 1.01 |
| delete | 1024 | 13.36 [13.22-13.45] | 13.45 [13.38-14.04] | 0.99 | within 5% | 1.01 | 1.01 |
| delete | 16384 | 15.09 [14.96-15.21] | 14.97 [14.86-15.47] | 1.01 | in spread | 1.00 | 1.02 |
| delete | 49 | 11.77 [11.56-12.45] | 15.32 [12.27-42.21] | 0.77 | **out, faster** | 1.02 | 0.96 |
| delete | 97 | 12.26 [12.09-12.41] | 12.58 [12.34-12.93] | 0.97 | within 5% | 1.00 | 1.01 |
| iterate | 4 | 14.05 [13.81-17.01] | 16.92 [14.01-47.05] | 0.83 | in spread | 1.01 | 0.30 |
| iterate | 16 | 10.74 [10.57-14.18] | 10.81 [10.69-10.90] | 0.99 | in spread | 1.01 | 0.99 |
| iterate | 32 | 9.89 [9.80-9.93] | 9.95 [9.85-13.10] | 0.99 | in spread | 1.00 | 1.00 |
| iterate | 63 | 10.78 [9.47-10.91] | 9.51 [9.43-11.03] | 1.13 | in spread | 0.88 | 1.13 |
| iterate | 64 | 10.85 [9.60-10.90] | 9.48 [9.43-9.70] | 1.14 | **out, slower** | 1.38 | 1.00 |
| iterate | 65 | 16.07 [14.97-16.31] | 16.08 [15.19-16.36] | 1.00 | in spread | 0.96 | 1.08 |
| iterate | 128 | 14.69 [14.62-14.96] | 14.88 [14.71-15.05] | 0.99 | within 5% | 1.00 | 1.00 |
| iterate | 256 | 14.66 [14.50-14.77] | 14.66 [14.59-14.87] | 1.00 | in spread | 1.00 | 1.00 |
| iterate | 1024 | 14.61 [14.37-14.64] | 14.55 [14.43-14.72] | 1.00 | in spread | 1.00 | 1.01 |
| iterate | 16384 | 14.47 [14.32-14.63] | 14.43 [14.35-14.56] | 1.00 | in spread | 1.01 | 1.01 |
| iterate | 49 | 9.72 [9.48-11.38] | 10.22 [9.60-36.42] | 0.95 | in spread | 1.00 | 1.01 |
| iterate | 97 | 16.22 [16.08-16.36] | 16.78 [16.35-17.08] | 0.97 | within 5% | 1.00 | 0.99 |
| insert_nth | 4 | 14.81 [14.38-15.00] | 15.77 [15.53-16.20] | 0.94 | **out, faster** | 1.01 | 0.99 |
| insert_nth | 16 | 14.70 [14.49-19.74] | 15.64 [15.41-18.88] | 0.94 | **out, faster** | 1.05 | 1.01 |
| insert_nth | 32 | 16.00 [14.46-17.21] | 15.60 [15.30-20.14] | 1.03 | in spread | 1.00 | 1.08 |
| insert_nth | 63 | 22.04 [17.87-26.99] | 21.84 [21.39-27.77] | 1.01 | in spread | 0.76 | 1.04 |
| insert_nth | 64 | 18.28 [16.99-31.87] | 18.48 [17.47-19.87] | 0.99 | in spread | 1.54 | 0.94 |
| insert_nth | 65 | 1012.67 [959.03-1027.38] | 1045.52 [1033.26-1097.25] | 0.97 | within 5% | 0.03 | 1.00 |
| insert_nth | 128 | 31.54 [30.68-32.62] | 31.49 [31.05-33.44] | 1.00 | in spread | 0.94 | 1.02 |
| insert_nth | 256 | 33.03 [31.70-34.56] | 32.17 [31.74-33.27] | 1.03 | in spread | 0.98 | 1.05 |
| insert_nth | 1024 | 38.98 [35.53-40.39] | 35.38 [34.28-38.03] | 1.10 | **out, slower** | 0.88 | 1.09 |
| insert_nth | 16384 | 57.50 [55.00-67.75] | 55.00 [50.00-65.25] | 1.05 | in spread | 1.04 | 1.15 |
| insert_nth | 49 | 18.40 [16.11-18.84] | 31.44 [17.49-41.25] | 0.59 | in spread | 1.23 | 0.38 |
| insert_nth | 97 | 1917.73 [1900.57-1998.48] | 1976.15 [1664.98-2011.06] | 0.97 | in spread | 0.01 | 1.02 |

Tally: **56 of 72 cells pass** (41 in spread, 15 within 5 percent); 16 out
(12 faster, 4 slower).

Which moved:

- Warm-up cells, not judged: all four size-4 cells are out (insert 0.44,
  lookup_hit 0.69, delete 0.79, insert_nth 0.94; the record's own size-4
  spreads span 3-4x). lookup_miss and delete at 49 are out too (0.27/0.77):
  in the record 49 was the first size of its process, and here it runs
  after 4-32.
- The other ten are all within 15 percent and go in both directions.
  Faster: insert 32 0.85, insert 65 0.94, lookup_hit 65 0.92, delete 32/64
  0.92/0.93, insert_nth 16 0.94. Slower: insert 63/64 1.07, iterate 64 1.14,
  insert_nth 1024 1.10. The growth cells match the record: insert at
  65-16384 is 0.94-0.98, insert_nth 65 is 1013 ns against 1046, insert_nth
  97 is 1918 ns against 1976, and insert 97 is 0.97.

The CPU change (x86-64-v3) shows no clear gain on this ladder. The out
cells differ by a few percent in both directions, which looks like
run-to-run and neighbouring-size (spesh) variation rather than a
CPU-level shift. The per-hash `hashstrategy` call does not show as a cost
either (next section).

## Presized (`--hint=size`), kept for what it shows

The first run of this check passed the size as the hint (the plan's first
wording; now `--hint=size`, engine column `zig-s0-presized`). Against the
record, 47 of 72 cells passed and 25 were out, almost all because of the
presizing:

- **Growth is the whole insert cost above the threshold.** Presized insert
  at 65 and up is 0.36-0.55 of hint-0 insert (about 20 ns against 37-54
  ns). insert_nth at 65 and 97 drops from about 1013 and 1918 ns to 28 and
  26 ns (0.03, 0.01), so the migration cell at 65 is pure growth.
- Size 64 with hint 64 gets the 65-size table: presized iterate 64 and
  insert_nth 64 equal their 65 figures (15.0, 28.2 ns), 1.38x and 1.54x
  the hint-0 cells.
- **The per-hash call costs nothing measurable.** The call runs in MAIN,
  outside the timed subs, which stay JIT-compiled. Hint 0 / no call is
  0.95-1.05 on the judged cells at 16 and up, apart from a handful of
  noisy small-size cells (insert 32/49/63 0.87/1.10/1.24, delete 32 0.90,
  iterate 63/65 1.13/1.08, insert_nth 32/49/64/1024/16384) where the
  record's own spreads are wide.
