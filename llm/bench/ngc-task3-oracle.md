# ngc Task 3 oracle: groups (a) and (b), 16/16 cells exit 0, raw logs byte-identical

```
ngc oracle record (Task 3, step 5, groups (a) and (b))
Date:          2026-11-10 10:32:38-11:05:05 CET (the matrix: start to last cell)
MoarVM:        zig-native-gc at 8f7c9a77a ("GC native: view module, typed atomics, worklist and allocation");
               traces 63fdc23 before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Prefixes:      group (a) ng-c-oracle (C collector + Zig hash engine, -Dzig-gc=false -Dgc-debug=1, Task 1) against
               ng-n-oracle (native head, -Dgc-debug=1, rebuilt at 8f7c9a77a); group (b) ng-f-oracle (faithful port,
               Task 1) against ng-n-oracle; versions 2026.09-270-gf0582f365 / 2026.09-275-g8f7c9a77a (equal length),
               paths 11 characters; builds ngc-task3-raw/builds.tsv, build.sh
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (rakudo zig-build-spec 042608fb82; execs
               /tmp/claude-1000/tune-zig-prefix/bin/moar, libmoar from LD_LIBRARY_PATH); nqp 41e7210ba
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Environment:   MVM_SPESH_DISABLE=1 RAKUDO_NO_PRECOMPILATION=1 MVM_GC_LOG; tier 2 adds MVM_GC_DEBUG_RSS=104857600;
               each cell under systemd-run --user --scope -q -p MemoryMax=8G
Command:       sh ngc-oracle-driver.sh /tmp/claude-1000/ngc/t3/oracle a b
               per cell: tools/bench/gc/oracle.sh --base=B --head=H --volume=V [--bad-packages] --tier=T --out=...
               (three logged runs of crc-sequential.raku per side; each side repeatable, base-1 vs head-1)
Volumes:       10000 and 100000 only (the 1M and 10M volumes stay excluded, user 2026-11-08 and 2026-11-10)
Load:          1-minute load before each cell 0.86-1.34 (matrix column 7)
Raw:           ngc-task3-oracle-raw/matrix.tsv (group volume set tier exit seconds load lines raw_cmp),
               <cell>-{base,head}.log (base-1.log and head-1.log of each cell), driver.out (driver exit 0)
```

| group | volume | set | tier | exit | seconds | log lines | raw cmp base-1/head-1 |
|---|---:|---|---:|---:|---:|---:|---|
| a | 10000 | plain | 1 | 0 | 38 | 55 | same |
| a | 10000 | plain | 2 | 0 | 37 | 55 | same |
| a | 10000 | bad | 1 | 0 | 37 | 55 | same |
| a | 10000 | bad | 2 | 0 | 38 | 55 | same |
| a | 100000 | plain | 1 | 0 | 205 | 361 | same |
| a | 100000 | plain | 2 | 0 | 204 | 361 | same |
| a | 100000 | bad | 1 | 0 | 208 | 361 | same |
| a | 100000 | bad | 2 | 0 | 205 | 361 | same |
| b | 10000 | plain | 1 | 0 | 38 | 55 | same |
| b | 10000 | plain | 2 | 0 | 38 | 55 | same |
| b | 10000 | bad | 1 | 0 | 38 | 55 | same |
| b | 10000 | bad | 2 | 0 | 38 | 55 | same |
| b | 100000 | plain | 1 | 0 | 206 | 361 | same |
| b | 100000 | plain | 2 | 0 | 205 | 361 | same |
| b | 100000 | bad | 1 | 0 | 206 | 361 | same |
| b | 100000 | bad | 2 | 0 | 206 | 361 | same |

Every cell exits 0 (each side repeatable, base and head identical) and the raw base-1/head-1 logs are byte-identical:
the native worklist and allocation, the inlined temp-root push and the `lock orl` fence change no decision the
per-collection log records, against the C control (a) or the faithful port (b).

Also from this build (ngc-task3-raw/): exported names of ng-n-base equal ng-c-base's (2850, `exports.diff` empty);
`mfence` 0 / 3 / 0 and `lock orl $0x0,-0x40(%rsp)` 37 / 34 / 37 in the whole libmoar of ng-c-base / ng-f-base /
ng-n-base (`fence-counts.txt`); `gc.collect.processWorklist` in ng-n-syms (same source, -Dstrip=false) holds three
`lock orl` and no `mfence`; `MVM_gc_allocate_object` in ng-n-base calls no out-of-line temp-root push (only
`MVM_gc_root_temp_push_slow`), where ng-f-syms's calls `moar_c.MVM_gc_root_temp_push` (the `.dis` files).
