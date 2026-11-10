# ngc Task 3 tripwire: N/C wall 1.005, RSS 1.002 plain; under the stop thresholds (wall 1.0323, RSS 1.0265)

```
ngc crc-getter tripwire record (Task 3, step 5)
Date:          2026-11-10, 11:05:26-11:09:15 CET
MoarVM:        zig-native-gc at 8f7c9a77a; traces 63fdc23 before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Pair:          base ng-c-base (C collector + Zig hash engine, -Dzig-gc=false, Task 1), head ng-n-base (native head,
               rebuilt at 8f7c9a77a); default options (LTO, ReleaseFast, x86-64-v3, -Dgc-debug=0, nursery 16 MiB);
               2850 exported names on both sides, identical sets
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (rakudo zig-build-spec 042608fb82; execs
               /tmp/claude-1000/tune-zig-prefix/bin/moar, libmoar from LD_LIBRARY_PATH); nqp 41e7210ba
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Program:       tools/bench/gc/crc-getter.raku, spesh and precompilation on
Command:       systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/ab.sh --base=/tmp/claude-1000/ng-c-base/lib \
                   --head=/tmp/claude-1000/ng-n-base/lib --rounds=3 --runs=5 --volume=100000 --out=...
               plain (one untimed warm-up per side; side order rotated per round; load < 2.0 before every run);
               wrapper ngc-task3-tripwire-raw/tripwire.sh
Load:          1-minute load logged before each run (load.log): 0.77-1.34
Raw:           ngc-task3-tripwire-raw/plain/ (<side>-r<round>-<run>.time, .out, load.log, summary.md), plain.stderr.
               All 30 timed runs exit 0.
```

## Result

Cells: median of the 3 round medians [min-max of the round medians]; each round median over 5 runs.

| side | wall s | peak RSS kB |
|---|---:|---:|
| ng-c-base | 7.54 [7.53-7.60] | 342408 [341036-342860] |
| ng-n-base | 7.58 [7.56-7.59] | 343016 [336748-344848] |

Ratio ng-n-base/ng-c-base: **wall 1.005, RSS 1.002**.

Against ngc-baseline-crc.md: the stop thresholds are wall above 1.0323 and RSS above 1.0265 (the fixed baseline
ng-f-base/ng-c-base 1.0283 / 0.9907 plus the C control's spread). Neither is crossed, so no 7-round re-run is needed.
The wall ratio is 0.023 below the faithful port's baseline 1.0283. It is a 3-round tripwire, not an acceptance
measurement, and it is consistent with the profile's two collector costs (the `mfence` and the out-of-line
temp-root push) that this task removed.
