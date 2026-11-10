# ngc Task 5 tripwire: N/C wall 1.001, RSS 0.988 plain; under the stop thresholds (wall 1.0323, RSS 1.0265)

```
ngc crc-getter tripwire record (Task 5, step 5)
Date:          2026-11-10, 13:11:57-13:15:45 CET
MoarVM:        zig-native-gc at 45a5575cb; traces 841a787 before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Pair:          base ng-c-base (C collector + Zig hash engine, -Dzig-gc=false, Task 1), head ng-n-base (native head,
               rebuilt at 45a5575cb); default options (LTO, ReleaseFast, x86-64-v3, -Dgc-debug=0, nursery 16 MiB);
               2850 exported names on both sides, identical sets
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (rakudo zig-build-spec 042608fb82; execs
               /tmp/claude-1000/tune-zig-prefix/bin/moar, libmoar from LD_LIBRARY_PATH); nqp 41e7210ba
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Program:       tools/bench/gc/crc-getter.raku, spesh and precompilation on
Command:       systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/ab.sh --base=/tmp/claude-1000/ng-c-base/lib \
                   --head=/tmp/claude-1000/ng-n-base/lib --rounds=3 --runs=5 --volume=100000 --out=...
               plain (one untimed warm-up per side; side order rotated per round; load < 2.0 before every run);
               wrapper ngc-task5-tripwire-raw/tripwire.sh
Load:          1-minute load logged before each run (load.log): 0.70-1.28
Raw:           ngc-task5-tripwire-raw/plain/ (<side>-r<round>-<run>.time, .out, load.log, summary.md), plain.stderr.
               All 30 timed runs exit 0.
```

## Result

Cells: median of the 3 round medians [min-max of the round medians]; each round median over 5 runs.

| side | wall s | peak RSS kB |
|---|---:|---:|
| ng-c-base | 7.56 [7.55-7.60] | 340800 [336672-344664] |
| ng-n-base | 7.57 [7.57-7.59] | 336652 [336504-348760] |

Ratio ng-n-base/ng-c-base: **wall 1.001, RSS 0.988**.

Against ngc-baseline-crc.md: the stop thresholds are wall above 1.0323 and RSS above 1.0265. Neither is crossed, so no
7-round re-run is needed. Both ratios are inside the spreads (the round-median ranges overlap); roots changes no
allocation and the oracle's logs are identical, so nothing is claimed as an effect. A 3-round tripwire, not an
acceptance measurement.
