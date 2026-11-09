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
