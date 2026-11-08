# Set 0 revert ladder guard (Task 9d), 2026-11-04

Base: 1e88a52fb (default ladder Small then Robin Hood), prefix `/tmp/claude-1000/internals-base-prefix`. Head: db611b1b8 (the revert; `src/zig/core/hash/` is byte-identical to 73255e81e), prefix `/tmp/claude-1000/tune-zig-prefix`. Both the default build (zig impl, LTO, x86-64-v3, stats off); the same `bin/hash-bench` (copied from the head build) drives both. CPU AMD Ryzen 9 5900X. 1-minute load 0.80-1.06 at run starts.

Commands (two runs, the variant order swapped in the second):

    hash-ab.sh --rounds=5 --sizes=4,16,32,63,64,65,128,256,1024,16384 --runs=5 --nth=all \
        --variant=base:$B/lib:$B/bin/hash-bench --variant=head:$H/lib:$H/bin/hash-bench --out=...   (run a)
    (the same with head listed first, run b)

Raw: `internals-set0-revert-{a,b}-{nqp,capi}-raw.tsv`, `-load.log`, `-{nqp,capi}-compare.md`.

Rule: a cell passes when the head's median of the five round medians is within 5 percent of base, or its min-max over the rounds overlaps base's.

## Verdict

Cells outside the rule (round-median min-max, head over base):

| run | level | cell | ratio | base range | head range |
|---|---|---|---:|---|---|
| a | nqp | clone 64 | 1.063 | 3.27-6.35 | 6.38-6.52 |
| a | nqp | insert_nth 64 | 1.416 | 20.35-27.5 | 27.84-37.97 |
| a | capi | delete 128 | 1.064 | 7.87-8.05 | 8.32-8.54 |
| a | capi | delete 256 | 1.079 | 7.95-8.05 | 8.41-8.73 |
| a | capi | delete 1024 | 1.073 | 8.01-8.1 | 8.45-8.85 |
| a | capi | delete 16384 | 1.066 | 8.66-8.83 | 9.14-9.54 |
| b | nqp | clone 63 | 2.006 | 3.19-3.29 | 3.7-6.63 |
| b | nqp | lookup_miss 32 | 1.129 | 9.7-10.91 | 10.98-11.92 |
| b | capi | delete 65 | 1.058 | 8.09-8.24 | 8.54-8.66 |
| b | capi | delete 128 | 1.062 | 7.92-8.1 | 8.38-8.55 |
| b | capi | delete 256 | 1.076 | 7.94-8.0 | 8.41-8.72 |
| b | capi | delete 1024 | 1.062 | 7.99-8.1 | 8.45-8.6 |
| b | capi | delete 16384 | 1.07 | 8.68-8.8 | 9.15-9.39 |
| b | capi | iterate 4 | 1.06 | 7.1-7.46 | 7.48-7.64 |

Reading: the nqp-level cells are not reproducible between runs (different cells each time, wide base spreads: noise, mostly the single-sample clone and insert_nth cells). The C-API delete cells at 65 and up (the Robin Hood rung) reproduce in both runs with the order swapped: head 1.06-1.08 of base, disjoint by 0.3-0.5 ns of about 8. Small-rung cells (4-64) pass at the capi level except iterate 4 in run b (1.06, not in run a). Not tuned. Both builds are Small then Robin Hood; 1e88a52fb to HEAD differ in the uni sized builds and the engine entry points (and whatever else the campaign changed outside `src/zig/core/hash/str.zig`), so the delete shift has a source outside the ladder and is open.
