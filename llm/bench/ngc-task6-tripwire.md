# ngc Task 6 tripwire: N/C wall 1.008, RSS 1.005 plain; under the stop thresholds (wall 1.0323, RSS 1.0265); spec 8 h evidence

```
ngc crc-getter tripwire record (Task 6, step 5)
Date:          2026-11-10, 14:15:15-14:19:05 CET
MoarVM:        zig-native-gc at 2f6736cdf; traces bed47ea before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Pair:          base ng-c-base (C collector + Zig hash engine, -Dzig-gc=false, Task 1), head ng-n-base (native head,
               rebuilt at 2f6736cdf); default options (LTO, ReleaseFast, x86-64-v3, -Dgc-debug=0, nursery 16 MiB);
               2850 exported names on both sides, identical sets
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (rakudo zig-build-spec 042608fb82; execs
               /tmp/claude-1000/tune-zig-prefix/bin/moar, libmoar from LD_LIBRARY_PATH); nqp 41e7210ba
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Program:       tools/bench/gc/crc-getter.raku, spesh and precompilation on
Command:       systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/ab.sh --base=/tmp/claude-1000/ng-c-base/lib \
                   --head=/tmp/claude-1000/ng-n-base/lib --rounds=3 --runs=5 --volume=100000 --out=...
               plain (one untimed warm-up per side; side order rotated per round; load < 2.0 before every run);
               wrapper ngc-task6-tripwire-raw/tripwire.sh
Load:          1-minute load logged before each run (load.log): 0.96-1.41
Raw:           ngc-task6-tripwire-raw/plain/ (<side>-r<round>-<run>.time, .out, load.log, summary.md), plain.stderr,
               driver.out. All 30 timed runs exit 0.
```

## Result

Cells: median of the 3 round medians [min-max of the round medians]; each round median over 5 runs.

| side | wall s | peak RSS kB |
|---|---:|---:|
| ng-c-base | 7.58 [7.54-7.64] | 342656 [342288-344404] |
| ng-n-base | 7.64 [7.64-7.71] | 344360 [340704-344968] |

Ratio ng-n-base/ng-c-base: **wall 1.008, RSS 1.005**.

Against ngc-baseline-crc.md: the stop thresholds are wall above 1.0323 and RSS above 1.0265. Neither is crossed, so no
7-round re-run is needed. A 3-round tripwire, not an acceptance measurement; the wall ratio is the largest of the file
tasks so far (Task 5: 1.001) but sits within the faithful port's fixed baseline ratio plus the C spread.

## Spec 8 h evidence (the work-passing list)

Task 6 replaces the C's hand-rolled `ThreadWork` array (`MVM_realloc(target_work, num_target_threads *
sizeof(ThreadWork))` per new target, `MVM_free` at the end of the run) with `std.ArrayList(ThreadWork)` over
`moar.mvm_allocator`, grown with `ensureTotalCapacityPrecise(len + 1)`. The requested sizes are the C's (16, 32, 48, ...
bytes); `mvm_allocator` has no realloc path (resize false, remap null), so each growth is `MVM_malloc(16 n)` + copy +
`MVM_free(old)` in place of `MVM_realloc`. The oracle is single-threaded and cannot see this path, so the evidence is
peak RSS on threaded programs:

1. The full crc-getter (above) runs its supplies, `react` and `start` blocks on the thread pool, so work passing is
   reached in its collections. **RSS ratio 1.005** against a C spread of **0.0358** of the median
   (ngc-baseline-crc.md): within the spread. The head's round-median range [340704-344968] overlaps the base's
   [342288-344404].
2. The three-thread full-cleanup program (tools/bench/gc/cleanup/three.nqp, `--full-cleanup`; three app-lifetime
   threads allocate while the main thread returns; each thread's frames reference the main thread's code objects,
   so every child-thread collection passes work), ng-c-base against ng-n-base, 3 interleaved rounds x 10 runs per side,
   side order rotated, load < 2.0 before each run (0.60-1.08), peak RSS from timev.py (wait4 rusage), wrapper
   ngc-task6-raw/rss-three.sh, raw ngc-task6-raw/rss-three/runs.tsv; all 60 runs exit 0 with `main returning`:

| side | peak RSS kB, median [min-max of round medians] |
|---|---:|
| ng-c-base | 297628 [296388-300360] |
| ng-n-base | 294562 [294554-296836] |

   **RSS ratio 0.990**, the C spread of this program 0.0133: within it (below the C's median).

Neither program shows a memory cost from the allocation change.
