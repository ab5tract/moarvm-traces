# ngc Task 8 stress: the full crc-getter under ng-n-stress, five runs, exit 0 each

```
ngc stress record (Task 8, step 5; spec 9, threaded evidence for the orchestration task)
Date:          2026-11-10 18:26:21-18:27:00 CET
MoarVM:        zig-native-gc at b0b3a48d6 ("GC native: orchestrate"); traces 5ac8b7b before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Prefix:        ng-n-stress (native head, -Dgc-debug=1 -Dnursery-size=524288), rebuilt at b0b3a48d6
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (rakudo zig-build-spec 042608fb82; execs
               /tmp/claude-1000/tune-zig-prefix/bin/moar, libmoar from LD_LIBRARY_PATH); nqp 41e7210ba
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Program:       tools/bench/gc/crc-getter.raku --volume=100000 --runs=5 (the full program: supplies, react and start
               blocks on the thread pool), spesh and precompilation on, as ab.sh runs it
Command:       LD_LIBRARY_PATH=/tmp/claude-1000/ng-n-stress/lib RAKULIB=<MoarVM>/tools/bench/gc/lib,<rakudo>/lib
               systemd-run --user --scope -q -p MemoryMax=8G python3 tools/bench/timev.py run-<i>.time rakudo-m
               tools/bench/gc/crc-getter.raku --volume=100000 --runs=5, five times, load < 2.0 before each
               (wrapper ngc-task8-stress-raw/stage2.sh, its last loop)
Raw:           ngc-task8-stress-raw/runs.tsv, run-<i>.time (timev.py), run-<i>.out.tail (the program's last lines)
```

| run | exit | load before | wall | peak RSS kB | timev exit status |
|---:|---:|---:|---:|---:|---:|
| 1 | 0 | 1.83 | 0:07.58 | 252432 | 0 |
| 2 | 0 | 1.70 | 0:08.02 | 250980 | 0 |
| 3 | 0 | 1.65 | 0:07.59 | 253100 | 0 |
| 4 | 0 | 1.62 | 0:07.57 | 251240 | 0 |
| 5 | 0 | 1.57 | 0:07.65 | 248576 | 0 |

**Five of five runs exit 0.** With the 512 KiB nursery the program collects a few hundred times per run with the thread
pool's workers signalled, stolen (when blocked) and released by the native orchestration, which is the multi-threaded
path the single-threaded oracle cannot see. Wall times (7.57-8.02 s) are not a measurement (one side, debug level 1,
no interleaving) and are recorded only as the runs' durations.
