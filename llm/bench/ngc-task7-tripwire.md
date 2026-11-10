# ngc Task 7 tripwire: N/C wall 1.019, RSS 1.006 plain; under the stop thresholds (wall 1.0323, RSS 1.0265)

```
ngc crc-getter tripwire record (Task 7, step 5)
Date:          2026-11-10, 16:20:26-16:24:14 CET
MoarVM:        zig-native-gc at eed1eb72b; traces 4f0e4dd before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Pair:          base ng-c-base (C collector + Zig hash engine, -Dzig-gc=false, Task 1), head ng-n-base (native head,
               rebuilt at eed1eb72b); default options (LTO, ReleaseFast, x86-64-v3, -Dgc-debug=0, nursery 16 MiB);
               2850 exported names on both sides, identical sets
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (rakudo zig-build-spec 042608fb82; execs
               /tmp/claude-1000/tune-zig-prefix/bin/moar, libmoar from LD_LIBRARY_PATH); nqp 41e7210ba
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Program:       tools/bench/gc/crc-getter.raku, spesh and precompilation on
Command:       systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/ab.sh --base=/tmp/claude-1000/ng-c-base/lib \
                   --head=/tmp/claude-1000/ng-n-base/lib --rounds=3 --runs=5 --volume=100000 --out=...
               plain (one untimed warm-up per side; side order rotated per round; load < 2.0 before every run);
               wrapper ngc-task7-tripwire-raw/tripwire.sh
Load:          1-minute load logged before each run (load.log): 0.90-1.34
Raw:           ngc-task7-tripwire-raw/plain/ (<side>-r<round>-<run>.time, .out, load.log, summary.md), plain.stderr,
               driver.out. All 30 timed runs exit 0.
```

## Result

Cells: median of the 3 round medians [min-max of the round medians]; each round median over 5 runs.

| side | wall s | peak RSS kB |
|---|---:|---:|
| ng-c-base | 7.49 [7.47-7.52] | 341008 [338944-348360] |
| ng-n-base | 7.63 [7.63-7.63] | 343128 [342704-344792] |

Ratio ng-n-base/ng-c-base: **wall 1.019, RSS 1.006**.

Against ngc-baseline-crc.md: the stop thresholds are wall above 1.0323 and RSS above 1.0265. Neither is crossed, so no
7-round re-run is needed. A 3-round tripwire, not an acceptance measurement. The earlier file tasks read wall 1.001
(Task 5), 1.008 and 1.016 (Task 6 and its R10 re-run); this one is 1.019, within the faithful port's fixed baseline
ratio plus the C spread. The base side's round medians (7.47-7.52) sit lower than in Task 6 (7.54-7.64) while the head's
(7.63) are where Task 6's were, so part of the movement is the control's run-to-run level; the head's spread is zero
to two decimals. Nothing is claimed from the difference to Task 6: it lies inside the noise floor of spec 11.
