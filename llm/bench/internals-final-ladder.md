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

Rule: a cell passes when the median of the 7 round medians (head over base) is within 5 percent, or the min-max ranges of the 7 round medians overlap. Two-run requirement (controller ruling, tightened): nothing is judged from a single run; a cell that read outside the rule in a run passes only if it is inside the rule in both focused re-runs (c, d).

Waivers, per cell:

- capi `delete` at 65, 128, 256, 1024 and 16384: no waiver stands. The runs below (a, b) read 1.053-1.073 on a head that contained the uni Swiss set; this was resolved by gating the uni Swiss set out of the shipped build; see the bisect record (`internals-delete-bisect.md`, "## Confirmation": delete 65/128/1024 now 1.01-1.05 or overlapping in both orders, `internals-delete-confirm-{a,b}/`).
- capi `delete` 16 and capi `iterate` 32: no waiver; each passes under the rule above (inside the rule in both c and d).
- every other cell: no waiver.

## Runs a and b (full ladders, both levels, order swapped)

Cells outside the rule by round medians (ratio, base range / head range, ns):

| cell | run a | run b | verdict |
|---|---|---|---|
| capi delete 16 | 1.103 [6.87-7.05 / 7.11-7.72] OUT | within 5 percent or overlapping | focused runs below |
| capi iterate 32 | within | 1.054 [6.29-6.39 / 6.51-6.89] OUT | focused runs below |
| capi delete 128 (was an exception) | 1.061 [7.88-8.04 / 8.29-8.46] | 1.053 [7.87-8.05 / 8.30-8.52] | resolved by the gate (see waivers) |
| capi delete 1024 (was an exception) | 1.071 [7.94-8.12 / 8.36-10.72] | 1.058 [7.94-8.15 / 8.39-8.62] | resolved by the gate (see waivers) |
| capi delete 16384 (was an exception) | 1.059 [8.65-9.01 / 9.16-10.5] | 1.053 [8.58-8.93 / 9.10-9.27] | resolved by the gate (see waivers) |
| capi delete 65 (was an exception) | 1.067, overlaps | 1.062 [7.99-8.22 / 8.43-8.64] | resolved by the gate (see waivers) |
| capi delete 256 (was an exception) | 1.073 [7.87-8.39 / 8.34-8.85], overlaps | 1.062 [7.84-8.06 / 8.38-8.64] | resolved by the gate (see waivers) |

The `delete` cells at 65 and up read 1.053-1.073 in both runs on the head that contained the uni Swiss set; this is the C-API delete shift of Task 9e, resolved by gating that set out of the shipped build (see the waivers and `internals-delete-bisect.md`). Every other cell of both ladders, both runs, is within 5 percent or overlaps (largest ratios: nqp insert_nth 64 1.19 in a and 1.39 in b, nqp clone 63 1.08 / 1.94, all overlapping: these are the noisy migration cells with ranges 20-136 ns).

## Runs c and d (focused: capi delete and iterate at 16 and 32, `--nth=threshold`)

| cell | run a | run b | run c (base first) | run d (head first) | verdict |
|---|---|---|---|---|---|
| capi delete 16 | 1.103 OUT | within | 1.049 [6.99-7.27 / 7.11-8.01] | 1.042 [6.88-7.40 / 7.12-7.60] | pass (inside the rule in both c and d) |
| capi iterate 32 | within | 1.054 OUT | 1.043 [6.28-6.68 / 6.53-6.89] | 1.030 [6.32-6.42 / 6.55-6.62] | pass (inside the rule in both c and d) |

Neither cell is outside the rule in both focused runs, and each was outside in only one of the two full runs; both pass. Other cells in c and d: delete 32 0.991 / 1.056 (d overlaps), iterate 16 1.048 / 1.034.

## Verdict

The guard passes: no cell is outside the rule in both of its two-run readings, and the `delete` cells at 65 and up, which read at most 1.073 on the ungated head, are now within the rule in both orders after the gate (`internals-delete-bisect.md`, "## Confirmation"). The ladder rows above were measured on 421aec8b9 before the gate; the gated tree changes only the uni kind (`internals-uni-widen-compare.md`: uni cells 0.91-1.02).
