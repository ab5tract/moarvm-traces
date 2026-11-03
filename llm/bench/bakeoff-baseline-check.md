# Bake-off baseline check (strategy 0), 2026-11-03

Informational (controller ruling): the build's default CPU level became
x86-64-v3 (commit 2d43de657) after the ladder record was taken on the generic
baseline CPU, so cells may move for that reason alone; an out-of-band cell
does not stop the campaign.

**Run.** MoarVM `zig-hash-bakeoff` at c4add6e4c plus the Task 4 harness, nqp
`zig-hash-strategies` (ops mapped), installed in one prefix (LTO, x86-64-v3),
AMD Ryzen 9 5900X. `tools/bench/hash-bakeoff.sh --strategies=0 --rounds=5`
with its defaults (`--sizes=4,16,32,63,64,65,128,256,1024,16384,49,97
--runs=5 --nth=all`, all sizes in one process per round); 1-minute load
0.10-0.17 at every run start. Raw: `bakeoff-baseline-s0.tsv` (round,
strategy, then the harness's columns), the campaign's own strategy-0
reference from here on.

**Record.** `tuning-lto-default-il-nqp-zig-lto.tsv` (zig-lto, 9 rounds,
generic CPU, the harness before Task 4) for the ladder sizes;
`tuning-lto-default-nqp-zig-lto-resize.tsv` (9 rounds, `--sizes=49,97` in a
process of their own) for 49 and 97, aggregated the same way (median of the
round medians, min-max of the round medians). Only the six ops the record
has are compared; bulk_load, overwrite, clone and iterate_delete are new.

**Rule.** A cell passes when the strategy-0 median lies within the record's
min-max spread or within 5 percent of its median.

**Two diagnostic runs** (5 rounds each, same sizes, interleaved per round,
load 0.10, not committed): *hint 0*, the Task 4 harness with
`nqp::hashstrategy(%h, 0, 0)` (the call, no size hint); *no call*, the
harness as at c4add6e4c (no hashstrategy call, without the four new
phases). The last two columns: the strategy-0 run over hint 0 isolates the
size hint; hint 0 over no call isolates the per-hash call (plus the new
phases running in the same process).

| op | size | s0 [min-max] | record [min-max] | s0 / record | check | hint n / hint 0 | hint 0 / no call |
|---|---:|---:|---:|---:|---|---:|---:|
| insert | 4 | 19.29 [15.94-19.65] | 56.68 [28.87-60.47] | 0.34 | **out, faster** | 0.75 | 0.42 |
| insert | 16 | 15.73 [15.63-15.85] | 22.28 [21.70-23.82] | 0.71 | **out, faster** | 0.74 | 0.97 |
| insert | 32 | 15.38 [15.18-16.31] | 21.74 [21.45-23.01] | 0.71 | **out, faster** | 0.80 | 0.91 |
| insert | 63 | 16.58 [16.42-18.28] | 22.75 [21.30-23.27] | 0.73 | **out, faster** | 0.67 | 1.27 |
| insert | 64 | 22.21 [20.46-24.14] | 20.40 [19.17-20.86] | 1.09 | **out, slower** | 1.00 | 1.01 |
| insert | 65 | 20.62 [20.49-20.83] | 39.45 [37.82-40.59] | 0.52 | **out, faster** | 0.54 | 1.02 |
| insert | 128 | 20.53 [20.40-20.76] | 48.57 [47.44-48.85] | 0.42 | **out, faster** | 0.43 | 1.02 |
| insert | 256 | 20.54 [20.39-21.47] | 49.80 [48.32-51.80] | 0.41 | **out, faster** | 0.41 | 1.03 |
| insert | 1024 | 20.84 [20.72-21.03] | 50.71 [50.56-51.24] | 0.41 | **out, faster** | 0.42 | 1.00 |
| insert | 16384 | 21.92 [21.84-22.01] | 52.72 [52.41-55.74] | 0.42 | **out, faster** | 0.40 | 1.04 |
| insert | 49 | 16.49 [15.93-18.41] | 54.42 [20.50-61.54] | 0.30 | **out, faster** | 0.65 | 1.14 |
| insert | 97 | 19.47 [19.24-19.67] | 55.85 [55.01-58.31] | 0.35 | **out, faster** | 0.36 | 1.01 |
| lookup_hit | 4 | 10.84 [10.71-11.13] | 15.67 [10.81-46.59] | 0.69 | in spread | 0.98 | 0.23 |
| lookup_hit | 16 | 10.48 [10.29-10.85] | 10.52 [10.41-11.67] | 1.00 | in spread | 0.98 | 0.99 |
| lookup_hit | 32 | 10.40 [9.71-10.68] | 11.06 [10.26-11.51] | 0.94 | in spread | 1.03 | 0.93 |
| lookup_hit | 63 | 11.28 [10.63-12.28] | 12.62 [11.13-13.10] | 0.89 | in spread | 0.95 | 0.98 |
| lookup_hit | 64 | 13.25 [13.03-14.05] | 12.64 [11.60-13.03] | 1.05 | within 5% | 1.12 | 0.98 |
| lookup_hit | 65 | 13.17 [13.14-13.36] | 14.28 [13.42-14.46] | 0.92 | **out, faster** | 0.99 | 0.99 |
| lookup_hit | 128 | 13.14 [13.08-13.17] | 13.23 [13.08-13.55] | 0.99 | in spread | 1.00 | 0.99 |
| lookup_hit | 256 | 13.30 [13.18-13.46] | 13.20 [13.12-13.45] | 1.01 | in spread | 1.00 | 0.99 |
| lookup_hit | 1024 | 13.50 [13.43-13.71] | 13.55 [13.40-13.81] | 1.00 | in spread | 1.00 | 0.99 |
| lookup_hit | 16384 | 14.77 [14.65-15.19] | 14.68 [14.51-14.87] | 1.01 | in spread | 1.00 | 1.00 |
| lookup_hit | 49 | 11.21 [10.49-12.05] | 47.12 [11.70-50.04] | 0.24 | **out, faster** | 0.96 | 0.99 |
| lookup_hit | 97 | 11.96 [11.86-12.04] | 12.19 [12.03-13.42] | 0.98 | within 5% | 1.01 | 1.00 |
| lookup_miss | 4 | 13.58 [10.06-13.74] | 10.38 [10.36-45.79] | 1.31 | in spread | 1.34 | 0.22 |
| lookup_miss | 16 | 9.62 [9.58-10.64] | 10.06 [9.84-10.52] | 0.96 | within 5% | 0.99 | 1.01 |
| lookup_miss | 32 | 10.70 [9.85-11.20] | 10.41 [10.08-11.63] | 1.03 | in spread | 1.07 | 1.00 |
| lookup_miss | 63 | 11.99 [11.27-12.22] | 12.33 [11.38-13.41] | 0.97 | in spread | 1.02 | 0.96 |
| lookup_miss | 64 | 12.90 [12.86-13.07] | 12.04 [11.67-13.12] | 1.07 | in spread | 1.09 | 0.99 |
| lookup_miss | 65 | 13.02 [12.99-13.17] | 13.06 [12.92-13.27] | 1.00 | in spread | 0.99 | 1.00 |
| lookup_miss | 128 | 12.90 [12.83-13.03] | 12.91 [12.78-13.03] | 1.00 | in spread | 1.00 | 1.00 |
| lookup_miss | 256 | 13.03 [12.92-13.14] | 12.96 [12.83-13.11] | 1.01 | in spread | 1.00 | 1.01 |
| lookup_miss | 1024 | 13.00 [12.87-13.23] | 12.93 [12.81-13.16] | 1.01 | in spread | 1.00 | 1.00 |
| lookup_miss | 16384 | 14.19 [13.91-14.31] | 13.98 [13.89-14.17] | 1.02 | within 5% | 1.01 | 1.00 |
| lookup_miss | 49 | 11.24 [10.93-12.30] | 41.12 [12.17-48.80] | 0.27 | **out, faster** | 1.01 | 1.02 |
| lookup_miss | 97 | 11.41 [11.34-11.46] | 11.50 [11.32-11.67] | 0.99 | in spread | 1.00 | 0.99 |
| delete | 4 | 10.89 [10.77-11.21] | 13.73 [11.21-42.86] | 0.79 | **out, faster** | 0.99 | 0.27 |
| delete | 16 | 10.08 [10.02-10.14] | 10.53 [10.45-19.38] | 0.96 | within 5% | 1.00 | 0.99 |
| delete | 32 | 10.98 [10.69-11.29] | 11.75 [11.36-19.70] | 0.93 | **out, faster** | 0.98 | 0.94 |
| delete | 63 | 12.18 [11.34-12.35] | 12.69 [11.80-20.20] | 0.96 | in spread | 0.99 | 1.03 |
| delete | 64 | 13.24 [13.15-13.85] | 13.02 [12.52-20.52] | 1.02 | in spread | 1.08 | 1.02 |
| delete | 65 | 13.24 [13.12-13.30] | 13.48 [13.29-13.74] | 0.98 | within 5% | 1.00 | 1.01 |
| delete | 128 | 12.99 [12.97-13.16] | 13.34 [13.02-13.91] | 0.97 | within 5% | 1.00 | 0.99 |
| delete | 256 | 13.08 [12.97-13.43] | 13.23 [13.14-13.80] | 0.99 | within 5% | 0.99 | 1.01 |
| delete | 1024 | 13.49 [13.27-13.83] | 13.45 [13.38-14.04] | 1.00 | in spread | 1.01 | 1.01 |
| delete | 16384 | 15.06 [14.84-15.23] | 14.97 [14.86-15.47] | 1.01 | in spread | 1.01 | 1.01 |
| delete | 49 | 11.98 [11.60-12.55] | 15.32 [12.27-42.21] | 0.78 | **out, faster** | 0.98 | 1.00 |
| delete | 97 | 12.22 [12.10-12.39] | 12.58 [12.34-12.93] | 0.97 | within 5% | 1.00 | 1.01 |
| iterate | 4 | 14.26 [13.85-16.92] | 16.92 [14.01-47.05] | 0.84 | in spread | 1.00 | 0.31 |
| iterate | 16 | 10.82 [10.79-11.83] | 10.81 [10.69-10.90] | 1.00 | in spread | 1.01 | 0.99 |
| iterate | 32 | 9.92 [9.83-10.11] | 9.95 [9.85-13.10] | 1.00 | in spread | 1.01 | 0.99 |
| iterate | 63 | 9.51 [9.39-10.73] | 9.51 [9.43-11.03] | 1.00 | in spread | 0.90 | 1.11 |
| iterate | 64 | 15.00 [14.95-16.66] | 9.48 [9.43-9.70] | 1.58 | **out, slower** | 1.39 | 1.00 |
| iterate | 65 | 15.42 [14.81-16.16] | 16.08 [15.19-16.36] | 0.96 | in spread | 0.95 | 1.08 |
| iterate | 128 | 14.74 [14.67-14.98] | 14.88 [14.71-15.05] | 0.99 | in spread | 1.00 | 1.00 |
| iterate | 256 | 14.61 [14.48-14.90] | 14.66 [14.59-14.87] | 1.00 | in spread | 1.00 | 1.00 |
| iterate | 1024 | 14.66 [14.47-14.68] | 14.55 [14.43-14.72] | 1.01 | in spread | 1.01 | 1.01 |
| iterate | 16384 | 14.57 [14.40-14.60] | 14.43 [14.35-14.56] | 1.01 | within 5% | 1.01 | 1.00 |
| iterate | 49 | 9.69 [9.59-11.44] | 10.22 [9.60-36.42] | 0.95 | in spread | 0.88 | 1.14 |
| iterate | 97 | 16.25 [16.11-16.56] | 16.78 [16.35-17.08] | 0.97 | within 5% | 1.00 | 1.00 |
| insert_nth | 4 | 14.91 [14.83-14.96] | 15.77 [15.53-16.20] | 0.95 | **out, faster** | 1.02 | 0.98 |
| insert_nth | 16 | 15.42 [14.47-15.47] | 15.64 [15.41-18.88] | 0.99 | in spread | 1.06 | 1.00 |
| insert_nth | 32 | 16.04 [15.51-16.37] | 15.60 [15.30-20.14] | 1.03 | in spread | 0.91 | 1.20 |
| insert_nth | 63 | 16.83 [16.50-19.87] | 21.84 [21.39-27.77] | 0.77 | **out, faster** | 0.99 | 0.80 |
| insert_nth | 64 | 28.16 [27.50-29.49] | 18.48 [17.47-19.87] | 1.52 | **out, slower** | 1.58 | 0.91 |
| insert_nth | 65 | 27.96 [27.21-28.60] | 1045.52 [1033.26-1097.25] | 0.03 | **out, faster** | 0.03 | 0.99 |
| insert_nth | 128 | 29.78 [29.20-30.43] | 31.49 [31.05-33.44] | 0.95 | **out, faster** | 0.96 | 1.00 |
| insert_nth | 256 | 32.45 [30.73-33.15] | 32.17 [31.74-33.27] | 1.01 | in spread | 0.98 | 1.04 |
| insert_nth | 1024 | 34.13 [33.19-35.39] | 35.38 [34.28-38.03] | 0.96 | within 5% | 0.94 | 1.01 |
| insert_nth | 16384 | 60.00 [55.00-67.50] | 55.00 [50.00-65.25] | 1.09 | in spread | 1.00 | 1.20 |
| insert_nth | 49 | 22.62 [16.34-27.34] | 31.44 [17.49-41.25] | 0.72 | in spread | 1.19 | 0.39 |
| insert_nth | 97 | 25.65 [25.19-26.14] | 1976.15 [1664.98-2011.06] | 0.01 | **out, faster** | 0.01 | 1.01 |

Tally: 35 in spread, 12 within 5 percent, 25 out (22 faster, 3 slower).

## Reading

**What moved is the size hint, not the CPU level and not the call.** The
harness passes N as `nqp::hashstrategy`'s size hint (the brief's
`nqp::hashstrategy(%h, N, $n)`), so every hash is built presized for its N
entries and the timed insert never grows the table:

- insert at 65 and up is 0.41-0.52 of the record (about 20 ns against 39-53
  ns), and the hint n / hint 0 column is 0.36-0.54 there while hint 0 sits in
  the record's band: the record's insert paid the grows, this one does not.
  insert at 16-63 is 0.71-0.73 of the record for the same reason (the hint
  skips the small-tier grows).
- insert_nth at 65 and 97 drops from 1045 ns and 1976 ns (the N-th insert
  crossing the grow) to about 28 ns and 26 ns: the hashes of N-1 keys are
  built for N, so the N-th insert does not grow.
- The three slower cells are all size 64: insert_nth 1.52, iterate 1.58
  (insert 1.09 is out only by its spread). With a hint of 64 the table is
  built at the size 65 gets, so 64 entries are iterated and the 64th key
  inserted in the larger table: iterate 64 (15.0 ns) and insert_nth 64 (28.2
  ns) now equal their 65 figures (15.4, 28.0). hint n / hint 0 shows it
  (1.39, 1.58).

**The per-hash call costs nothing measurable**, as expected: it runs in MAIN,
outside the timed subs, which stay JIT-compiled. hint 0 / no call is
0.91-1.04 on every judged cell at 16 and up except a handful of noisy
small-size cells (insert 49/63 1.14/1.27, iterate 49/63/65 1.14/1.11/1.08,
insert_nth 32/49/63/16384, where the record's own spread is wide); size 4 is
the warm-up cell and swings by 3x between processes (0.22-0.42), never
judged.

**The CPU level** shows, if at all, as the few remaining out cells with the
hint taken out (hint 0 against the record): faster lookup_hit 32/65 0.92/0.93,
delete 64 0.94, insert 32 0.89, insert_nth 4/16/63 0.93/0.93/0.78, but also
slower insert 63/64 1.09 and iterate 64 1.14, all a few percent past the
band and in both directions, so no clear x86-64-v3 gain on this ladder. The
49-size faster cells (lookup_hit/lookup_miss 0.24-0.27) are the record's
own warm-up: there 49 was the first size of its process.

**Consequence for the campaign.** The baseline is strategy 0 with the call
and the size hint, `bakeoff-baseline-s0.tsv`; it is not comparable with the
earlier ladder records on insert (65 and up), insert_nth (64, 65, 97) and
iterate 64. Every strategy gets the same hint, so the bake-off columns stay
comparable with each other, but its insert rows measure presized inserts:
growth cost is no longer in any timed row of this harness (bulk_load too
starts presized).
