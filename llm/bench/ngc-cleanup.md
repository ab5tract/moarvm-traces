# ngc full-cleanup runs under the controls (Task 1, Step 8): 240 of 240

```
ngc full-cleanup record (Task 1, step 8)
Date:          2026-11-09 10:04-10:05 CET
MoarVM:        zig-native-gc at f0582f365; traces fb6346e before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Prefixes:      ng-c-base, ng-f-base, ng-c-stress, ng-f-stress (ngc-prefixes.md); 2850 exported names at -base, 2852 at -stress
Runner:        nqp of /tmp/claude-1000/tune-zig-prefix (41e7210ba), share/nqp/lib
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Command:       tools/bench/gc/cleanup.sh --prefix=/tmp/claude-1000/<P> --runs=20, per prefix in the order above, after
               load < 2.0; each run systemd-run --user --scope -q -p MemoryMax=8G timeout 60 <P>/bin/moar
               --full-cleanup --libpath=<nqp lib> <nqp lib>/nqp.moarvm tools/bench/gc/cleanup/<program>.nqp
Load:          before each prefix: 1.52, 1.25, 1.19, 1.28
Raw:           ngc-cleanup-raw/cleanup-<prefix>.txt (load line, the script's per-run table and total)
```

| prefix | running.nqp | blocked.nqp | three.nqp | total |
|---|---:|---:|---:|---:|
| ng-c-base | 20/20 | 20/20 | 20/20 | 60/60 |
| ng-f-base | 20/20 | 20/20 | 20/20 | 60/60 |
| ng-c-stress | 20/20 | 20/20 | 20/20 | 60/60 |
| ng-f-stress | 20/20 | 20/20 | 20/20 | 60/60 |

A run passes when it exits 0 and its last line is `main returning`: 240 of 240, every exit code 0.

## Acceptance (Task 9, Step 5): 240 of 240 on ng-c-base, ng-n-base, ng-c-stress, ng-n-stress

```
ngc full-cleanup record (Task 9, step 5)
Date:          2026-11-10 20:52:35-20:53:46 CET
MoarVM:        zig-native-gc at 1a70642f9; ng-n-* built at b0b3a48d6 (not rebuilt), ng-c-* from Task 1
Runner:        nqp of /tmp/claude-1000/tune-zig-prefix (41e7210ba), share/nqp/lib
Command:       tools/bench/gc/cleanup.sh --prefix=/tmp/claude-1000/<P> --runs=20 per prefix in the order ng-c-base,
               ng-n-base, ng-c-stress, ng-n-stress, after load < 2.0 (fifth stage of ngc-acceptance-master.sh); each run
               systemd-run --user --scope -q -p MemoryMax=8G timeout 60 <P>/bin/moar --full-cleanup ... cleanup/<program>.nqp
Load:          before each prefix: 1.03, 1.15, 1.40, 1.38
Raw:           ngc-cleanup-acc-raw/cleanup-<prefix>.txt (load line, the script's per-run table and total, exit)
```

| prefix | running.nqp | blocked.nqp | three.nqp | total |
|---|---:|---:|---:|---:|
| ng-c-base | 20/20 | 20/20 | 20/20 | 60/60 |
| ng-n-base | 20/20 | 20/20 | 20/20 | 60/60 |
| ng-c-stress | 20/20 | 20/20 | 20/20 | 60/60 |
| ng-n-stress | 20/20 | 20/20 | 20/20 | 60/60 |

A run passes when it exits 0 and its last line is `main returning`: **240 of 240**, every exit code 0, cleanup.sh exit
0 on all four prefixes.

## Acceptance (Task 9): the full crc-getter under both stress prefixes (spec 9's threaded evidence)

Five runs each of `crc-getter.raku --volume=100000 --runs=5` under ng-c-stress and ng-n-stress (-Dgc-debug=1
-Dnursery-size=524288), alternating c n, load < 2.0 before each (0.98-1.21), MemoryMax=8G, 2026-11-10 21:10-21:12 CET,
after the master script (ngc-acceptance-stress.sh; raw ngc-stress-raw/: runs.tsv, <side>-run-<i>.time, .out.tail).
**10 of 10 runs exit 0** (c wall 7.41-7.97 s, RSS 248324-256700 kB; n wall 7.61-7.76 s, RSS 248348-253080 kB). One
side per run at debug level 1, five runs: the durations are not a measurement and no ratio is read from them.
