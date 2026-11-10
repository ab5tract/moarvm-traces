# ngc Task 8 full-cleanup runs: 120 of 120 on ng-n-base and ng-n-stress

```
ngc full-cleanup record (Task 8, step 5)
Date:          2026-11-10 18:25:46-18:26:21 CET
MoarVM:        zig-native-gc at b0b3a48d6 ("GC native: orchestrate"); traces 5ac8b7b before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Prefixes:      ng-n-base, ng-n-stress (-Dgc-debug=1 -Dnursery-size=524288), rebuilt at b0b3a48d6; 2850 exported names at -base
Runner:        nqp of /tmp/claude-1000/tune-zig-prefix (41e7210ba), share/nqp/lib
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Command:       tools/bench/gc/cleanup.sh --prefix=/tmp/claude-1000/<P> --runs=20, per prefix in the order above, after
               load < 2.0; each run systemd-run --user --scope -q -p MemoryMax=8G timeout 60 <P>/bin/moar
               --full-cleanup --libpath=<nqp lib> <nqp lib>/nqp.moarvm tools/bench/gc/cleanup/<program>.nqp
Load:          before each prefix: 1.39, 1.78
Raw:           ngc-task8-cleanup-raw/cleanup-<prefix>.txt (load line, the script's per-run table and total, exit)
```

| prefix | running.nqp | blocked.nqp | three.nqp | total |
|---|---:|---:|---:|---:|
| ng-n-base | 20/20 | 20/20 | 20/20 | 60/60 |
| ng-n-stress | 20/20 | 20/20 | 20/20 | 60/60 |

A run passes when it exits 0 and its last line is `main returning`: **120 of 120**, every exit code 0 (the controls,
ngc-cleanup.md: 240 of 240). These three programs are the ones whose global destruction the native
`globalDestruction` now runs (a thread allocating while the main thread returns; a thread blocked in `nqp::sleep`,
which takes the UNABLE -> UNABLE | SUSPEND_REQUEST path; three threads), so the suspend-request pass over the threads
list, the park in `enterFromInterrupt` without a debugserver and the bounded wait are exercised 120 times under both
nursery sizes.
