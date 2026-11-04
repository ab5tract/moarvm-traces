# Final ladder guard (Task 10), 2026-11-04

```
Date:      2026-11-04
Base:      1478311f6 (zig-hash-engine), prefix /tmp/claude-1000/internals-base-prefix
Head:      421aec8b9 (zig-hash-internals, default build: zig impl, LTO, x86-64-v3, stats off), prefix /tmp/claude-1000/tune-zig-prefix
CPU:       AMD Ryzen 9 5900X
Harness:   one hash-bench exe for both variants: internals-base-prefix/bin/hash-bench (md5 a5e1aa6f...). The head build's own
           hash-bench (md5 5b08dcc7...) was not used because it differs from the base copy; one exe across variants is the control.
Commands:  hash-ab.sh --rounds=7 --sizes=4,16,32,63,64,65,128,256,1024,16384 --runs=5 --nth=all
               --variant=base:$B/lib:$B/bin/hash-bench --variant=head:$H/lib:$B/bin/hash-bench      (run a; run b lists head first)
           hash-ab.sh --rounds=7 --sizes=16,32 --runs=5 --nth=threshold (same variants; run c base first, run d head first)
Load:      1-minute load at every run start: a 1.12-1.16, b 0.64-0.88, c 0.35-0.43, d 0.43-0.55 (all under 2.0; internals-final-ladder-{a,b,c,d}-load.log)
Raw:       internals-final-ladder-{a,b,c,d}-{nqp,capi}-raw.tsv (c, d also hold an nqp level), -compare.md (hash-compare.pl's per-run brackets), scripts in internals-final-scripts/
```

Rule: a cell passes when the median of the 7 round medians (head over base) is within 5 percent, or the min-max ranges of the 7 round medians overlap. Recorded exception (ruled 2026-11-04 after Task 9e): the C-API `delete` cells at 65 entries and up may read up to 1.10 of base. `internals-delete-bisect.md` brackets that shift to 74158b566; `MVM_str_hash_delete_nocheck` is instruction-identical and relocated off 32-byte loop alignment, a placement effect, no alignment tuning in this campaign. Two-run requirement (controller ruling): nothing is judged from a single run; a cell outside the rule in one run and inside it in the order-swapped run is re-measured in two focused runs (c, d), and fails only if it is outside the rule in both.

## Runs a and b (full ladders, both levels, order swapped)

Cells outside the rule by round medians (ratio, base range / head range, ns):

| cell | run a | run b | verdict |
|---|---|---|---|
| capi delete 16 | 1.103 [6.87-7.05 / 7.11-7.72] OUT | within 5 percent or overlapping | focused runs below |
| capi iterate 32 | within | 1.054 [6.29-6.39 / 6.51-6.89] OUT | focused runs below |
| capi delete 128 (exception) | 1.061 [7.88-8.04 / 8.29-8.46] | 1.053 [7.87-8.05 / 8.30-8.52] | exception: pass |
| capi delete 1024 (exception) | 1.071 [7.94-8.12 / 8.36-10.72] | 1.058 [7.94-8.15 / 8.39-8.62] | exception: pass |
| capi delete 16384 (exception) | 1.059 [8.65-9.01 / 9.16-10.5] | 1.053 [8.58-8.93 / 9.10-9.27] | exception: pass |
| capi delete 65 (exception) | 1.067, overlaps | 1.062 [7.99-8.22 / 8.43-8.64] | exception: pass |
| capi delete 256 (exception) | 1.073 [7.87-8.39 / 8.34-8.85], overlaps | 1.062 [7.84-8.06 / 8.38-8.64] | exception: pass |

The `delete` cells at 65 and up read 1.053-1.073 in both runs, under the 1.10 cap; this is the C-API delete shift of Task 9e, kept as a known artifact (it is a code-placement effect of 74158b566, not a source change in the delete function). Every other cell of both ladders, both runs, is within 5 percent or overlaps (largest ratios: nqp insert_nth 64 1.19 in a and 1.39 in b, nqp clone 63 1.08 / 1.94, all overlapping: these are the noisy migration cells with ranges 20-136 ns).

## Runs c and d (focused: capi delete and iterate at 16 and 32, `--nth=threshold`)

| cell | run a | run b | run c (base first) | run d (head first) | verdict |
|---|---|---|---|---|---|
| capi delete 16 | 1.103 OUT | within | 1.049 [6.99-7.27 / 7.11-8.01] | 1.042 [6.88-7.40 / 7.12-7.60] | pass (within 5 percent in c and d) |
| capi iterate 32 | within | 1.054 OUT | 1.043 [6.28-6.68 / 6.53-6.89] | 1.030 [6.32-6.42 / 6.55-6.62] | pass (within 5 percent in c and d) |

Neither cell is outside the rule in both focused runs, and each was outside in only one of the two full runs; both pass. Other cells in c and d: delete 32 0.991 / 1.056 (d overlaps), iterate 16 1.048 / 1.034.

## Verdict

The guard passes: no cell is outside the rule in both of its two-run readings, and the `delete` cells at 65 and up stay under the recorded exception (maximum 1.073, cap 1.10).
