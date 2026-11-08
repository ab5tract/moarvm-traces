# GC oracle: repeatability of the C collector against itself (Task 2)

```
GC oracle repeatability record (Task 2, step 4)
Date:          2026-11-04, 19:55-22:17 CET
MoarVM:        zig-gc-port at 96d049123 (Task 1: -Dgc-debug, -Dnursery-size, MVM_GC_LOG, MVM_GC_DEBUG_RSS);
               scripts from the Task 2 commit (tools/bench/gc/oracle.sh, crc-sequential.raku)
Prefixes:      base = head = /tmp/claude-1000/gc-c-oracle (zig build install, -Dgc-debug=1, C collector,
               LTO, ReleaseFast, x86-64-v3; built by Task 1 from 96d049123)
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (in-tree rakudo, branch zig-build-spec
               at 042608fb82; execs /tmp/claude-1000/tune-zig-prefix/bin/moar, libmoar from LD_LIBRARY_PATH);
               nqp zig-hash-strategies at 41e7210ba (installed in /tmp/claude-1000/tune-zig-prefix)
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Environment:   MVM_SPESH_DISABLE=1 RAKUDO_NO_PRECOMPILATION=1 MVM_GC_LOG=<out>/<side>-<i>.log
               RAKULIB=tools/bench/gc/lib,/home/longwalker/code/raku/x.core/zmoarz/rakudo/lib
               tier 2 adds MVM_GC_DEBUG_RSS=104857600
Commands:      sh gc-oracle-repeatability-matrix.sh /tmp/claude-1000/gc-oracle-rep 10000,100000,1000000
               which per cell waits for load < 2.0 and runs
               tools/bench/gc/oracle.sh --base=/tmp/claude-1000/gc-c-oracle --head=/tmp/claude-1000/gc-c-oracle \
                   --volume=V [--bad-packages] --tier=T --out=/tmp/claude-1000/gc-oracle-rep/vV-<set>-tT
               (six logged runs per cell: three base, three head, each crc-sequential.raku --runs=5)
Load:          1-minute load before each cell 0.81-1.69 (the load column of the matrix)
Raw:           gc-oracle-repeatability-matrix.tsv (volume, set, tier, exit, seconds, load, log lines),
               gc-oracle-repeatability-logs/vV-<set>-tT.log (base-1.log of each cell; the other five runs of
               each cell were byte-identical), gc-oracle-repeatability-matrix.sh (the driver)
```

## Result: twelve cells, exit 0 everywhere

| volume | set | tier | exit | verdict | log lines | full runs (seq) | wall s |
|---:|---|---:|---:|---|---:|---|---:|
| 10 000 | plain | 1 | 0 | identical | 55 | none | 37 |
| 10 000 | plain | 2 | 0 | identical | 55 | 13 | 37 |
| 10 000 | bad-packages | 1 | 0 | identical | 55 | none | 37 |
| 10 000 | bad-packages | 2 | 0 | identical | 55 | 13 | 39 |
| 100 000 | plain | 1 | 0 | identical | 361 | none | 206 |
| 100 000 | plain | 2 | 0 | identical | 361 | 13, 27 | 204 |
| 100 000 | bad-packages | 1 | 0 | identical | 361 | none | 205 |
| 100 000 | bad-packages | 2 | 0 | identical | 361 | 13, 27 | 207 |
| 1 000 000 | plain | 1 | 0 | identical | 3415 | 30, 53 | 1900 |
| 1 000 000 | plain | 2 | 0 | identical | 3415 | 13, 27, 34, 41, 48, 55, 57, 60 | 1915 |
| 1 000 000 | bad-packages | 1 | 0 | identical | 3419 | 30, 53 | 1894 |
| 1 000 000 | bad-packages | 2 | 0 | identical | 3419 | 13, 27, 34, 41, 48, 55, 59, 2566 | 1868 |

Every log carries only `tid=1`: with spesh disabled and the supplies gone, no other
thread collects. In the tier 1 cells the unfiltered logs (with `full=` and
`gen2_freed=`) were also byte-identical across all six runs, so on this machine the
real-RSS decision did not move either; the tier 1 filter stays as the spec defines it.

## What was needed to make the log repeatable

Two sources of run-to-run variation were found on the main thread (the only thread
in the log) before the matrix ran, at volume 10 000, tier 2, 6-8 repeats each:

1. **Loading a precompiled module.** With precompilation on, the first collection's
   `promoted` was bimodal, 4 589 000 or 4 589 168 bytes (168 apart), and the shift
   carried through the rest of the log. It shows for `use NativeCall` alone and for
   `use String::CRC32` alone, and not for `-e` programs without a `use`, nor with
   `RAKUDO_NO_PRECOMPILATION=1` (8 of 8 identical). Not investigated further (it is
   in rakudo's precompiled-unit loading path). Fix: `oracle.sh` runs with
   `RAKUDO_NO_PRECOMPILATION=1`, so the modules are compiled from source in every
   run, which is deterministic.
2. **`now - $time`.** With (1) fixed, one collection late in the run promoted 1032
   then 912 bytes instead of 864 and 864, at a collection that moved from run to run
   (seq 13, 46 or 53): a time-dependent allocation. Experiments (8 runs each):
   durations as `now - $time` printed via `.Num`: varies; no `now` at all: identical;
   `now` taken but never subtracted: identical; `now.Num - $time.Num`: identical. So
   the Duration (Rat) arithmetic on clock values allocates differently with the
   value. Fix in the reduction: `crc-sequential.raku` computes durations as
   `now.Num - $time.Num` (the INIT note and each `RUN $n:` line); `now` is still taken
   where the user's program takes it. The user's `crc-getter.raku` is unchanged.

Nothing else was changed: the `Package` class, the `xx $volume` construction with the
90/10 `--bad-packages` split, the per-batch `map` with the crc32 comparison and
`$bad-count` are as in the user's program (5000 bad of 10 000 x 5 runs at 10 000,
500 000 at 1 000 000, matching `crc-getter.raku`).

Not part of the oracle: the in-tree rakudo has no core modules installed, so
`use NativeCall` needs the rakudo checkout's `lib/` on `RAKULIB` beside
`tools/bench/gc/lib` (both runners default to that).
