# ngc Task 6 oracle: groups (a) and (b), 16/16 cells exit 0, raw logs byte-identical

```
ngc oracle record (Task 6, step 5, groups (a) and (b))
Date:          2026-11-10 13:42:51-14:15:06 CET (the matrix: start to last cell)
MoarVM:        zig-native-gc at 2f6736cdf ("GC native: collect"); traces bed47ea before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Prefixes:      group (a) ng-c-oracle (C collector + Zig hash engine, -Dzig-gc=false -Dgc-debug=1, Task 1) against
               ng-n-oracle (native head, -Dgc-debug=1, rebuilt at 2f6736cdf); group (b) ng-f-oracle (faithful port,
               Task 1) against ng-n-oracle; versions 2026.09-270-gf0582f365 / 2026.09-281-g2f6736cdf (equal length),
               paths 11 characters; builds ngc-task6-raw/builds.tsv, build.sh
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (rakudo zig-build-spec 042608fb82; execs
               /tmp/claude-1000/tune-zig-prefix/bin/moar, libmoar from LD_LIBRARY_PATH); nqp 41e7210ba
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Environment:   MVM_SPESH_DISABLE=1 RAKUDO_NO_PRECOMPILATION=1 MVM_GC_LOG; tier 2 adds MVM_GC_DEBUG_RSS=104857600;
               each cell under systemd-run --user --scope -q -p MemoryMax=8G
Command:       sh ngc-oracle-driver.sh /tmp/claude-1000/ngc/t6/oracle a b
               per cell: tools/bench/gc/oracle.sh --base=B --head=H --volume=V [--bad-packages] --tier=T --out=...
               (three logged runs of crc-sequential.raku per side; each side repeatable, base-1 vs head-1)
Volumes:       10000 and 100000 only (the 1M and 10M volumes stay excluded, user 2026-11-08 and 2026-11-10)
Load:          1-minute load before each cell 0.89-1.39 (matrix column 7)
Raw:           ngc-task6-oracle-raw/matrix.tsv (group volume set tier exit seconds load lines raw_cmp),
               <cell>-{base,head}.log (base-1.log and head-1.log of each cell), driver.out (driver exit 0)
```

| group | volume | set | tier | exit | seconds | log lines | raw cmp base-1/head-1 |
|---|---:|---|---:|---:|---:|---:|---|
| a | 10000 | plain | 1 | 0 | 38 | 55 | same |
| a | 10000 | plain | 2 | 0 | 37 | 55 | same |
| a | 10000 | bad | 1 | 0 | 38 | 55 | same |
| a | 10000 | bad | 2 | 0 | 38 | 55 | same |
| a | 100000 | plain | 1 | 0 | 204 | 361 | same |
| a | 100000 | plain | 2 | 0 | 204 | 361 | same |
| a | 100000 | bad | 1 | 0 | 201 | 361 | same |
| a | 100000 | bad | 2 | 0 | 205 | 361 | same |
| b | 10000 | plain | 1 | 0 | 37 | 55 | same |
| b | 10000 | plain | 2 | 0 | 38 | 55 | same |
| b | 10000 | bad | 1 | 0 | 37 | 55 | same |
| b | 10000 | bad | 2 | 0 | 38 | 55 | same |
| b | 100000 | plain | 1 | 0 | 203 | 361 | same |
| b | 100000 | plain | 2 | 0 | 206 | 361 | same |
| b | 100000 | bad | 1 | 0 | 206 | 361 | same |
| b | 100000 | bad | 2 | 0 | 205 | 361 | same |

Every cell exits 0 (each side repeatable, base and head identical) and the raw base-1/head-1 logs are byte-identical:
the native collector proper (typed signatures; the roots, gen2 and worklist ports called as Zig; `switch` on
`view.kind` in the C's flag precedence in the marking and both sweeps; the fromspace scan as a cursor over
`fromspace[0..used]`; the gen2 sweep over `size_classes[0..MVM_GEN2_BINS]` and gen2.zig's `pageItems`; the
non-exhaustive `WhatToDo`/`Generations` enums) changes no decision the per-collection log records, against the C
control (a) or the faithful port (b). The oracle is single-threaded: the work-passing path (`WorkToPass` over
`std.ArrayList`) is not exercised here; its evidence is the RSS column of ngc-task6-tripwire.md and the three-thread
full-cleanup measurement recorded there.

Also from this build (ngc-task6-raw/): exported names of ng-n-base equal ng-c-base's (2850, `exports.diff` empty).
