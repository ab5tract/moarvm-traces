# ngc Task 8 tripwire: N/C wall 1.003, RSS 1.013 plain; under the stop thresholds (wall 1.0323, RSS 1.0265)

```
ngc crc-getter tripwire record (Task 8, step 5)
Date:          2026-11-10, 18:12:14-18:16:00 CET
MoarVM:        zig-native-gc at b0b3a48d6 ("GC native: orchestrate"); traces 5ac8b7b before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Pair:          base ng-c-base (C collector + Zig hash engine, -Dzig-gc=false, Task 1), head ng-n-base (native head,
               rebuilt at b0b3a48d6); default options (LTO, ReleaseFast, x86-64-v3, -Dgc-debug=0, nursery 16 MiB);
               2850 exported names on both sides, identical sets (ngc-task8-raw/exports.diff empty); 0 mfence in the head
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (rakudo zig-build-spec 042608fb82; execs
               /tmp/claude-1000/tune-zig-prefix/bin/moar, libmoar from LD_LIBRARY_PATH); nqp 41e7210ba
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Program:       tools/bench/gc/crc-getter.raku, spesh and precompilation on
Command:       systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/ab.sh --base=/tmp/claude-1000/ng-c-base/lib \
                   --head=/tmp/claude-1000/ng-n-base/lib --rounds=3 --runs=5 --volume=100000 --out=...
               plain (one untimed warm-up per side; side order rotated per round; load < 2.0 before every run);
               wrapper ngc-task8-tripwire-raw/tripwire.sh, run right after the oracle matrix with nothing else running
Load:          1-minute load logged before each run (load.log): 1.02-1.25
Raw:           ngc-task8-tripwire-raw/plain/ (<side>-r<round>-<run>.time, .out, load.log, summary.md), plain.stderr,
               driver.out. All 30 timed runs exit 0.
```

## Result

Cells: median of the 3 round medians [min-max of the round medians]; each round median over 5 runs.

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| ng-c-base | 7.48 [7.44-7.49] | 342920 [340844-344772] | 7.48 7.49 7.44 | 344772 340844 342920 |
| ng-n-base | 7.50 [7.49-7.50] | 347224 [346528-349056] | 7.50 7.49 7.50 | 346528 349056 347224 |

Ratio ng-n-base/ng-c-base: **wall 1.003, RSS 1.013**.

Against ngc-baseline-crc.md: the stop thresholds are wall above 1.0323 and RSS above 1.0265. Neither is crossed, so no
7-round re-run is needed. A 3-round tripwire, not an acceptance measurement. The earlier file tasks read wall 1.001
(Task 5), 1.016 (Task 6), 1.019 and 1.024 (Task 7 and its fix re-run); this one is 1.003: the head's round medians
(7.49-7.50) are 0.13 s below Task 7's (7.58-7.70) while the base is where it was (7.44-7.49). The change of this task
is the orchestration, which runs once per collection, plus the allocator's slow path (`enterFromAllocator` and
`enterFromInterrupt` now called as Zig from `allocateNursery`, so LTO sees them whole); whether that is the cause or
the noise floor of spec 11 (about 1 percent) moved, a 3-round run cannot say and nothing is claimed from it. The RSS
ratio (1.013) is the highest of the file tasks so far (1.006 at Task 7) but inside its threshold; the head's round
medians (346528-349056) all lie above the base's (340844-344772), about 4 MB, which the acceptance's seven rounds
should confirm or dissolve.
