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

## Re-run after ruling R10 (mvm_allocator remap over MVM_realloc, MoarVM c17926d6d)

The controller ruled (R10) to keep the `std.ArrayList` and give `moar.mvm_allocator` a real `remap` over
`MVM_realloc`. `ensureTotalCapacityPrecise` tries `remap` first (std/array_list.zig:1371, quoted in
ngc-task6-fix-raw/ensure-precise.txt), so each new target is now one `MVM_realloc(old, 16 k)`, the C's operation
sequence. The first entry still comes from `alloc` (`Allocator.remap` returns null for an empty slice without calling
the vtable, std/mem/Allocator.zig:389-391), `MVM_malloc(16)`, equal to the C's `MVM_realloc(NULL, 16)`.
ng-n-base rebuilt at c17926d6d (ngc-task6-fix-raw/builds.tsv, 2026.09-283-gc17926d6d); exported names 2850, diff
against ng-c-base empty (ngc-task6-fix-raw/exports.diff).

Tripwire, same command, 2026-11-10 14:44:04-14:47:53 CET, load 0.84-1.25, 30/30 runs exit 0
(ngc-task6-fix-raw/tripwire/):

| side | wall s | peak RSS kB |
|---|---:|---:|
| ng-c-base | 7.50 [7.44-7.51] | 342696 [342188-346356] |
| ng-n-base | 7.62 [7.61-7.63] | 343876 [337004-345876] |

Ratio: **wall 1.016, RSS 1.003**; thresholds 1.0323 and 1.0265 not crossed, so no 7-round re-run, and the suites and
full-cleanup runs above (on 2f6736cdf) were not repeated for this change. h evidence on the final code: crc-getter RSS
1.003 against the C spread 0.0358; three-thread full-cleanup program (same protocol as above, 60/60 runs exit 0 with
`main returning`, load 0.96-1.12, ngc-task6-fix-raw/rss-three/runs.tsv) ng-c-base 300388 [298472-300458] kB,
ng-n-base 296520 [296392-302704] kB, **RSS 0.987**, C spread 0.0066 (the head's median below the C's; its round
medians overlap the C's range).

The wall ratio is the third rising value of this task's file (1.001 at Task 5, 1.008 at 2f6736cdf, 1.016 here); this
run's base was 0.08 s faster than the first run's while the head stayed at 7.62-7.64, so a 3-round tripwire cannot
separate the trend from the base's run-to-run spread. Under the threshold; for the acceptance measurement to settle.
