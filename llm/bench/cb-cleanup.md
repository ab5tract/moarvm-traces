# cb full-cleanup runs (Task 3, Step 3): 120 of 120, cb-n-base 60/60, cb-n-stress --stress 60/60

```
cb full-cleanup record (Task 3, step 3; spec 8)
Date:          2026-11-11 19:44:48-19:45:23 CET
MoarVM:        gc-call-boundary at 11a2e2e84; cb-n-base and cb-n-stress built at 6cfbe7e3f (cb-prefixes.md), not rebuilt;
               traces e4758f9 before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Prefixes:      cb-n-base (defaults), cb-n-stress (-Dgc-debug=1 -Dnursery-size=524288)
Runner:        nqp of /tmp/claude-1000/tune-zig-prefix (41e7210ba), share/nqp/lib
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Command:       sh traces/llm/bench/cb-cleanup-raw/run.sh /tmp/claude-1000/cb/cleanup, which waits for load < 2.0 and runs
               systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/cleanup.sh --prefix=/tmp/claude-1000/cb-n-base --runs=20
               systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/cleanup.sh --prefix=/tmp/claude-1000/cb-n-stress --runs=20 --stress
               (each run timeout 60 <P>/bin/moar --full-cleanup --libpath=<nqp lib> <nqp lib>/nqp.moarvm
               tools/bench/gc/cleanup/<program>.nqp; --stress multiplies each inner loop bound by 20)
Load:          before each prefix: 0.80, 0.80
Raw:           cb-cleanup-raw/cleanup-<prefix>.txt (load line, the script's per-run table and total, exit, end time),
               cb-cleanup-raw/run.sh
```

| prefix | programs | running.nqp | blocked.nqp | three.nqp | total |
|---|---|---:|---:|---:|---:|
| cb-n-base | plain | 20/20 | 20/20 | 20/20 | 60/60 |
| cb-n-stress | --stress (20x allocation variants) | 20/20 | 20/20 | 20/20 | 60/60 |

A run passes when it exits 0 and its last line is `main returning`: **120 of 120**, every exit code 0, cleanup.sh exit
0 on both prefixes. Campaign 6's acceptance ran its -stress prefixes with the plain program set (ngc-cleanup.md,
Ruling R4); this campaign's plan names `--stress` for cb-n-stress, so the stress prefix ran the heavier variants,
which is the stronger of the two.
