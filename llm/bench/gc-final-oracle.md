# GC oracle, final: the C collector against the Zig collector at HEAD (Task 10, Step 1)

```
GC final oracle record (Task 10, step 1)
Date:          2026-11-08, 12:47-13:04 CET
MoarVM:        zig-gc-port at e0444fc47 (the last port commit is 5abaf4507; e0444fc47 adds only a traces pointer)
Traces:        3349236 (before this record)
Prefixes:      base = /tmp/claude-1000/gc-c-oracle (139d404ed, the C collector with the Zig hash engine;
               zig build install, -Dgc-debug=1, LTO, ReleaseFast, x86-64-v3; rebuilt 2026-11-08 after the reboot)
               head = /tmp/claude-1000/gc-z-oracle (e0444fc47, the Zig collector; zig build install -Dgc-debug=1,
               otherwise the same options; rebuilt by this task from HEAD, 59 s)
               (paths of equal length; both version strings 22 characters: 2026.09-211-g139d404ed, 2026.09-228-ge0444fc47)
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (rakudo zig-build-spec at 3d626b9b24;
               execs /tmp/claude-1000/tune-zig-prefix/bin/moar, libmoar from LD_LIBRARY_PATH);
               nqp zig-hash-strategies at 287d13264 (installed in /tmp/claude-1000/tune-zig-prefix)
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap; Zig 0.16.0
Environment:   MVM_SPESH_DISABLE=1 RAKUDO_NO_PRECOMPILATION=1 MVM_GC_LOG=<out>/<side>-<i>.log
               RAKULIB=tools/bench/gc/lib,/home/longwalker/code/raku/x.core/zmoarz/rakudo/lib
               tier 2 adds MVM_GC_DEBUG_RSS=104857600
Commands:      sh gc-final-oracle-matrix.sh /tmp/claude-1000/gc-t10-oracle
               which per cell waits for load < 2.0 and runs
               tools/bench/gc/oracle.sh --base=/tmp/claude-1000/gc-c-oracle --head=/tmp/claude-1000/gc-z-oracle \
                   --volume=V [--bad-packages] --tier=T --out=/tmp/claude-1000/gc-t10-oracle/vV-<set>-tT
               (six logged runs per cell: three base, three head, each crc-sequential.raku --runs=5)
Load:          1-minute load before each cell 0.60-1.35 (matrix column 6)
Raw:           gc-final-oracle-matrix.tsv (volume, set, tier, exit, seconds, load, log lines),
               gc-final-oracle-logs/vV-<set>-tT-{base,head}.log (base-1.log and head-1.log of each cell; oracle.sh
               checked the three logs of each side identical), gc-final-oracle-matrix.sh (the driver)
```

Sizes: 10 000 and 100 000 (the 1 000 000 size was struck on 2026-11-08 by the user's ruling: the crc-getter workload is capped at 100 000 objects for this campaign).

## Result: eight cells, exit 0 everywhere

| volume | set | tier | exit | verdict | log lines | full runs (seq) | wall s |
|---:|---|---:|---:|---|---:|---|---:|
| 10 000 | plain | 1 | 0 | identical | 55 | none | 37 |
| 10 000 | plain | 2 | 0 | identical | 55 | 13 | 38 |
| 10 000 | bad-packages | 1 | 0 | identical | 55 | none | 38 |
| 10 000 | bad-packages | 2 | 0 | identical | 55 | 13 | 38 |
| 100 000 | plain | 1 | 0 | identical | 361 | none | 206 |
| 100 000 | plain | 2 | 0 | identical | 361 | 13, 27 | 207 |
| 100 000 | bad-packages | 1 | 0 | identical | 361 | none | 209 |
| 100 000 | bad-packages | 2 | 0 | identical | 361 | 13, 27 | 211 |

Every cell: each side's three logs identical (repeatable), base-1 and head-1 identical after the tier filter, and also byte-identical before it (`cmp` of the raw `base-1.log` and `head-1.log` of every cell: no difference, every field including `full=` and `gen2_freed=` at tier 1). Every line is `tid=1`; the oracle compares every thread's lines in order, and this workload has only the main thread. The line counts and the full-run sequence numbers are those of the C collector against itself in `gc-oracle-repeatability.md`.

Verdict: the Zig collector makes the C collector's decisions collection by collection on the deterministic workload, at both sizes, both settings and both tiers.
