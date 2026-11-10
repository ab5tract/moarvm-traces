# ngc Task 6 full-cleanup runs: 120 of 120 on ng-n-base and ng-n-stress

```
ngc full-cleanup record (Task 6, step 5)
Date:          2026-11-10 14:33:48-14:34:23 CET
MoarVM:        zig-native-gc at 2f6736cdf; traces bed47ea before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Prefixes:      ng-n-base, ng-n-stress (-Dgc-debug=1 -Dnursery-size=524288), rebuilt at 2f6736cdf; 2850 exported names at -base
Runner:        nqp of /tmp/claude-1000/tune-zig-prefix (41e7210ba), share/nqp/lib
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Command:       tools/bench/gc/cleanup.sh --prefix=/tmp/claude-1000/<P> --runs=20, per prefix in the order above, after
               load < 2.0; each run systemd-run --user --scope -q -p MemoryMax=8G timeout 60 <P>/bin/moar
               --full-cleanup --libpath=<nqp lib> <nqp lib>/nqp.moarvm tools/bench/gc/cleanup/<program>.nqp
Load:          before each prefix: 1.63, 1.45
Raw:           ngc-task6-cleanup-raw/cleanup-<prefix>.txt (load line, the script's per-run table and total, exit)
```

| prefix | running.nqp | blocked.nqp | three.nqp | total |
|---|---:|---:|---:|---:|
| ng-n-base | 20/20 | 20/20 | 20/20 | 60/60 |
| ng-n-stress | 20/20 | 20/20 | 20/20 | 60/60 |

A run passes when it exits 0 and its last line is `main returning`: 120 of 120, every exit code 0 (the controls,
ngc-cleanup.md: 240 of 240). The three-thread program's peak RSS against the C control (spec 8 h) is in
ngc-task6-tripwire.md.
