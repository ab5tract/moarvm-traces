# zig-017 oracle: 0.16 C vs 0.17 C (group b) identical, 8/8 cells; 0.17 C vs 0.17 Zig (group a) identical, 8/8

- (a) g7-c-oracle vs g7-z-oracle (0.17 C collector vs 0.17 Zig collector): 8/8 exit 0, raw logs byte-identical.
- (b) gc-c-oracle vs g7-c-oracle (0.16 C vs 0.17 C, the toolchain: Zig 0.16.0 / clang 21 vs Zig 0.17.1 / clang 22.1.8): 8/8 exit 0, raw logs byte-identical.
- (c) gc-z-oracle vs g7-z-oracle (0.16 Zig vs 0.17 Zig, extra): 8/8 exit 0, raw logs byte-identical.
- (d) gc-c-oracle vs g7-z-oracle (Campaign 4's C side vs the 0.17 Zig collector, extra): 8/8 exit 0, raw logs byte-identical.
- Note: an all-C side (-Dzig-impl=false, C hash tables) is not repeatable and cannot be an oracle side: the C
  string hash salts every table with MVM_proc_rand_i (src/core/str_hash_table.c:150), so the allocation
  sequence varies between runs. Every C side here is the C collector with the Zig hash engine, as in Campaign 4
  (z017-prefixes.md).

```
zig-017 oracle record (Task 5, step 2)
Date:          2026-11-08 23:25 - 2026-11-09 00:42 CET (all-C attempt 23:25-23:28; c/d 10k 23:31-23:36; a/b 23:58-00:14;
               c/d 100k 00:14-00:42)
MoarVM:        zig-017 at b1bbb9dd4; traces 175921d before this record
Prefixes:      z017-prefixes.md (g7-c-* C collector + Zig hash engine, from a scratch copy; g7-z-* the checkout);
               gc-c-oracle (built at 96d049123, version 2026.09-211-g139d404ed) and gc-z-oracle (version 2026.09-239-g64f82bf6d), the Campaign 4 prefixes, Zig 0.16.0; all -Dgc-debug=1,
               paths of equal length, version strings 22 characters (g7-*: 2026.09-257-gb1bbb9dd4)
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (rakudo zig-build-spec 042608fb82; execs
               /tmp/claude-1000/tune-zig-prefix/bin/moar, libmoar from LD_LIBRARY_PATH); nqp 41e7210ba
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Environment:   as gc-final-oracle.md (MVM_SPESH_DISABLE=1 RAKUDO_NO_PRECOMPILATION=1 MVM_GC_LOG; tier 2 adds
               MVM_GC_DEBUG_RSS=104857600); each cell under systemd-run --user --scope -q -p MemoryMax=8G
Commands:      sh z017-oracle-matrix-driver.sh /tmp/claude-1000/z017/t5/oracle a b
               VOLUMES=10000 sh z017-oracle-matrix-driver.sh /tmp/claude-1000/z017/t5/oracle-diag c d
               VOLUMES=100000 sh z017-oracle-matrix-driver.sh /tmp/claude-1000/z017/t5/oracle-cd100k c d
               per cell: tools/bench/gc/oracle.sh --base=B --head=H --volume=V [--bad-packages] --tier=T --out=...
               (three logged runs per side, crc-sequential.raku --runs=5; each side repeatable, base-1 vs head-1)
Load:          1-minute load before each cell: a 1.04-1.29, b 1.01-1.31, c 0.80-1.12, d 1.01-1.10 (matrix column 7)
Raw:           z017-oracle-matrix.tsv (group, volume, set, tier, exit, seconds, load, log lines),
               z017-oracle-logs/<group>-vV-<set>-tT-{base,head}.log (base-1.log and head-1.log of each cell),
               z017-oracle-logs/allc-try1/ (the superseded all-C group a attempt: stderr per cell, matrix),
               z017-oracle-logs/allc-b-cell/ (one all-C group b cell, base-1/head-1 logs)
```

## Cells

exit / seconds / log lines; every cell exit 0 means each side's three logs agree and base-1 equals head-1 after the
tier filter; in addition `cmp` of the raw base-1.log and head-1.log is empty in all 32 cells (tier 1 included).

| volume | set | tier | a: g7-c vs g7-z | b: gc-c vs g7-c | c: gc-z vs g7-z | d: gc-c vs g7-z |
|---:|---|---:|---|---|---|---|
| 10000 | plain | 1 | 0 / 36 s / 55 | 0 / 37 s / 55 | 0 / 37 s / 55 | 0 / 37 s / 55 |
| 10000 | plain | 2 | 0 / 37 / 55 | 0 / 37 / 55 | 0 / 37 / 55 | 0 / 37 / 55 |
| 10000 | bad | 1 | 0 / 37 / 55 | 0 / 36 / 55 | 0 / 37 / 55 | 0 / 36 / 55 |
| 10000 | bad | 2 | 0 / 37 / 55 | 0 / 37 / 55 | 0 / 38 / 55 | 0 / 37 / 55 |
| 100000 | plain | 1 | 0 / 199 / 361 | 0 / 200 / 361 | 0 / 202 / 361 | 0 / 202 / 361 |
| 100000 | plain | 2 | 0 / 200 / 361 | 0 / 209 / 361 | 0 / 206 / 361 | 0 / 201 / 361 |
| 100000 | bad | 1 | 0 / 200 / 361 | 0 / 201 / 361 | 0 / 202 / 361 | 0 / 201 / 361 |
| 100000 | bad | 2 | 0 / 199 / 361 | 0 / 201 / 361 | 0 / 208 / 361 | 0 / 202 / 361 |

Line counts equal Campaign 4's (55 and 361). The logs themselves are not byte-comparable with
gc-final-oracle-logs/: the same gc-c-oracle prefix logs different promoted= values in this run than in Campaign 4,
because the workload's environment differs (MVM_GC_LOG names a path of a different length, which rakudo's %*ENV
allocates); comparisons are only within one run, where both sides share the environment shape.

## The all-C attempt (superseded)

The brief's first configuration, g7-c-oracle built with -Dzig-impl=false (C hash tables and C collector), gave in
group a at 10 000 the exits 2 1 1 2 (plain t1, plain t2, bad t1, bad t2): plain t1 "base not repeatable", base-1 vs
base-2 differing at seq=3 (promoted=1850862 against 1850670); the others "base and head differ" from seq=1
(promoted=4368248 all-C against 4315128). One group b cell (10000 plain t2, gc-c-oracle vs all-C g7-c-oracle) split
the same way at seq=1 (4315128 vs 4368248). Every build with the Zig hash engine logs 4315128 there. backendconfig of
all pairs differs only in prefix paths and version strings. On the controller's ruling the three g7-c-* prefixes were
rebuilt as C collector + Zig hash engine, and groups a and b were run again in full (the table above).
