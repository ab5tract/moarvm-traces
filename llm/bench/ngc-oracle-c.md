# ngc oracle group (c): ng-c-oracle vs ng-f-oracle identical, 8/8 cells, raw logs byte-identical

```
ngc oracle record (Task 1, step 8, group (c))
Date:          2026-11-09 09:48-09:55 CET (the matrix: start to last cell)
MoarVM:        zig-native-gc at f0582f365; traces fb6346e before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Prefixes:      ng-c-oracle (C collector + Zig hash engine, -Dzig-gc=false -Dgc-debug=1) against ng-f-oracle (faithful
               Zig port, -Dgc-debug=1); ngc-prefixes.md; version strings 2026.09-270-gf0582f365, paths 11 characters
Exports:       2852 names on both sides (gc-debug 1; 2850 at -base)
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (rakudo zig-build-spec 042608fb82; execs
               /tmp/claude-1000/tune-zig-prefix/bin/moar, libmoar from LD_LIBRARY_PATH); nqp 41e7210ba
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Environment:   MVM_SPESH_DISABLE=1 RAKUDO_NO_PRECOMPILATION=1 MVM_GC_LOG; tier 2 adds MVM_GC_DEBUG_RSS=104857600;
               each cell under systemd-run --user --scope -q -p MemoryMax=8G
Command:       sh ngc-oracle-driver.sh /tmp/claude-1000/ngc/oracle-c c
               per cell: tools/bench/gc/oracle.sh --base=B --head=H --volume=V [--bad-packages] --tier=T --out=...
               (three logged runs of crc-sequential.raku per side; each side repeatable, base-1 vs head-1)
Load:          1-minute load before each cell 0.66-1.18 (matrix column 7)
Raw:           ngc-oracle-c-raw/matrix.tsv (group volume set tier exit seconds load lines raw_cmp),
               ngc-oracle-c-raw/<cell>-{base,head}.log (base-1.log and head-1.log of each cell)
```

| volume | set | tier | exit | seconds | log lines | raw cmp base-1/head-1 |
|---:|---|---:|---:|---:|---:|---|
| 10000 | plain | 1 | 0 | 37 | 55 | same |
| 10000 | plain | 2 | 0 | 37 | 55 | same |
| 10000 | bad | 1 | 0 | 36 | 55 | same |
| 10000 | bad | 2 | 0 | 37 | 55 | same |
| 100000 | plain | 1 | 0 | 202 | 361 | same |
| 100000 | plain | 2 | 0 | 199 | 361 | same |
| 100000 | bad | 1 | 0 | 198 | 361 | same |
| 100000 | bad | 2 | 0 | 199 | 361 | same |

Line counts equal Campaign 4's and 5's (55 and 361). The controls agree: the C collector built from the tree with
-Dzig-gc=false and the faithful port make the same collections. Group (c) has 8 cells (2 volumes x 2 sets x 2 tiers);
the spec's "16 cells per group" counts both groups (a) and (b) of a file task.
