# Internal tables, ladder guard after the stats hooks, 2026-11-03

**Run.** Base: MoarVM 1478311f6 (before the campaign), default build (LTO,
x86-64-v3, no `-Dhash-stats`) in `/tmp/claude-1000/internals-base-prefix`.
Head: `zig-hash-internals` at a375403d1 (the hooks commit; `hash-ab.sh` differs from
the built tree only by its load wait), default build in
`/tmp/claude-1000/tune-zig-prefix`. AMD Ryzen 9 5900X. nqp ladder through
`tune-zig-prefix`'s `nqp-m` under each variant's `LD_LIBRARY_PATH`; C-API ladder
through each prefix's `hash-bench` (head: `zig build hash-bench-exe`; base: the
executable of `zig build hash-bench` copied beside, the step being newer than
the base). `tools/bench/hash-ab.sh --rounds=5
--sizes=4,16,32,63,64,65,128,256,1024,16384` (`--runs=5 --nth=all`), variants
rotated per round. 1-minute load 0.30-0.58 at the run starts (`load.log`
required below 2.0).

**Rule.** A cell passes when the head's min-max of the five round medians
overlaps the base's, or the head median is within 5 percent of the base
median (the bake-off baseline rule).

**Raw.** `internals-ladder-guard-{nqp,capi}-{base,head}.tsv` (the harness's
7 columns, five rounds in order).

**Verdict.** All 90 nqp cells and all 60 C-API cells pass. Judged on the
head median alone against the base's min-max the rule would flag 3 nqp cells
(insert 4, iterate 4, lookup_miss 16) and 10 C-API cells (delete 63/64,
insert_nth 16/32/63/64, lookup_hit and lookup_miss 63/64), all within 15
percent and in both directions (lookup 63/64 are 15 percent *faster* on the
head); the two largest, C-API insert_nth 63 and 64 (head 1.79 and 1.65 of
base), are single-round outliers (one head round at 30.97 and 19.17 ns while
its other rounds read 10.5-11): a rerun of sizes 63,64 over seven rounds
(not committed) shows the same outliers on the base side too and no cell out.

**Zero-cost check (disassembly).** `objdump -d libmoar.so
--disassemble=MVM_str_hash_fetch_nocheck` on the head default build: 805
instructions, no `rdtsc` (none anywhere in the library), no call into stats.
