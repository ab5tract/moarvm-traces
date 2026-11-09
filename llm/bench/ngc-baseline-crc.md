# ngc fixed baseline (Task 1, Step 8): F/C 1.028 / 0.991 plain, 1.033 / 0.993 bad; tripwire stops above wall 1.032, RSS 1.027

```
ngc crc-getter baseline record (Task 1, step 8)
Date:          2026-11-09, 10:05-10:24 CET (plain 10:05:33-10:14:22, --bad-packages 10:14:22-10:23:46)
MoarVM:        zig-native-gc at f0582f365; traces fb6346e before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Pair:          base ng-c-base (C collector + Zig hash engine, -Dzig-gc=false), head ng-f-base (the faithful Zig port);
               ngc-prefixes.md; default options (LTO, ReleaseFast, x86-64-v3, -Dgc-debug=0, nursery 16 MiB);
               2850 exported names on both sides
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (rakudo zig-build-spec 042608fb82; execs
               /tmp/claude-1000/tune-zig-prefix/bin/moar, libmoar from LD_LIBRARY_PATH); nqp 41e7210ba
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Program:       tools/bench/gc/crc-getter.raku, spesh and precompilation on
Commands:      systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/ab.sh --base=/tmp/claude-1000/ng-c-base/lib \
                   --head=/tmp/claude-1000/ng-f-base/lib --rounds=7 --runs=5 --volume=100000 [--bad-packages] --out=...
               plain, then --bad-packages (one untimed warm-up per side; side order rotated per round; load < 2.0
               before every run)
Load:          1-minute load logged before each run (load.log): plain 0.80-1.29, bad 1.02-1.30
Raw:           ngc-baseline-crc-raw/{plain,bad}/ (<side>-r<round>-<run>.time, .out, load.log, summary.md),
               {plain,bad}.stderr, runs.log (its "exit" column prints date's status, not ab.sh's: read summary.md and
               the .time files). All 140 timed runs exit 0.
```

## Result

Cells: median of the 7 round medians [min-max of the round medians]; each round median over 5 runs.

| setting | ng-c-base wall s | ng-c-base RSS kB | ng-f-base wall s | ng-f-base RSS kB |
|---|---:|---:|---:|---:|
| plain | 7.42 [7.40-7.43] | 342064 [334688-346936] | 7.63 [7.59-7.71] | 338896 [334780-345140] |
| --bad-packages | 7.86 [7.84-7.95] | 345232 [338836-351072] | 8.12 [8.03-8.23] | 342896 [337220-347236] |

Campaign 5's Z17/C17 under the same recipe was 1.022 / 0.994 plain, 1.027 / 1.001 bad (z017-crc-ab.md); C17 7.38 s
there against ng-c-base 7.42 s here.

## The fixed baseline and the tripwire thresholds (spec 6)

The tripwire (`ab.sh --rounds=3 --runs=5 --volume=100000`, plain, ng-n-base against ng-c-base) stops a task when its
ratio exceeds the fixed baseline ratio below by more than the C control's spread (max minus min of ng-c-base's round
medians, over their median).

- Baseline ratio ng-f-base/ng-c-base, plain: wall 1.0283, RSS 0.9907.
- C spread, plain: wall (7.43 - 7.40) / 7.42 = 0.0040; RSS (346936 - 334688) / 342064 = 0.0358.
- Tripwire stop thresholds, plain: wall above 1.0323 (1.032), RSS above 1.0265 (1.027).
- For reference, --bad-packages (acceptance only): ratio wall 1.0331, RSS 0.9932; C spread wall 0.0140, RSS 0.0354;
  thresholds wall 1.0471, RSS 1.0287.
