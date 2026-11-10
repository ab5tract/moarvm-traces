# ngc Task 8 oracle: groups (a) and (b), 16/16 cells exit 0, raw logs byte-identical

```
ngc oracle record (Task 8, step 5, groups (a) and (b))
Date:          2026-11-10 17:39:20-18:12:14 CET (the matrix: start to last cell)
MoarVM:        zig-native-gc at b0b3a48d6 ("GC native: orchestrate"); traces 5ac8b7b before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Prefixes:      group (a) ng-c-oracle (C collector + Zig hash engine, -Dzig-gc=false -Dgc-debug=1, Task 1) against
               ng-n-oracle (native head, -Dgc-debug=1, rebuilt at b0b3a48d6); group (b) ng-f-oracle (faithful port,
               Task 1) against ng-n-oracle; versions 2026.09-270-gf0582f365 / 2026.09-270-gf0582f365 / 2026.09-289-gb0b3a48d6 (equal
               length), paths 11 characters; builds ngc-task8-raw/builds.tsv, build.sh
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (rakudo zig-build-spec 042608fb82; execs
               /tmp/claude-1000/tune-zig-prefix/bin/moar, libmoar from LD_LIBRARY_PATH); nqp 41e7210ba
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Environment:   MVM_SPESH_DISABLE=1 RAKUDO_NO_PRECOMPILATION=1 MVM_GC_LOG; tier 2 adds MVM_GC_DEBUG_RSS=104857600;
               each cell under systemd-run --user --scope -q -p MemoryMax=8G
Command:       sh ngc-oracle-driver.sh /tmp/claude-1000/ngc/t8/oracle a b
               per cell: tools/bench/gc/oracle.sh --base=B --head=H --volume=V [--bad-packages] --tier=T --out=...
               (three logged runs of crc-sequential.raku per side; each side repeatable, base-1 vs head-1)
Volumes:       10000 and 100000 only (the 1M and 10M volumes stay excluded, user 2026-11-08 and 2026-11-10)
Load:          1-minute load before each cell 0.87-1.48 (matrix column 7)
Raw:           ngc-task8-oracle-raw/matrix.tsv (group volume set tier exit seconds load lines raw_cmp),
               <cell>-{base,head}.log (base-1.log and head-1.log of each cell), driver.out (driver exit 0)
```

| group | volume | set | tier | exit | seconds | log lines | raw cmp base-1/head-1 |
|---|---:|---|---:|---:|---:|---:|---|
| a | 10000 | plain | 1 | 0 | 36 | 55 | same |
| a | 10000 | plain | 2 | 0 | 36 | 55 | same |
| a | 10000 | bad | 1 | 0 | 37 | 55 | same |
| a | 10000 | bad | 2 | 0 | 36 | 55 | same |
| a | 100000 | plain | 1 | 0 | 199 | 361 | same |
| a | 100000 | plain | 2 | 0 | 199 | 361 | same |
| a | 100000 | bad | 1 | 0 | 200 | 361 | same |
| a | 100000 | bad | 2 | 0 | 200 | 361 | same |
| b | 10000 | plain | 1 | 0 | 37 | 55 | same |
| b | 10000 | plain | 2 | 0 | 37 | 55 | same |
| b | 10000 | bad | 1 | 0 | 39 | 55 | same |
| b | 10000 | bad | 2 | 0 | 37 | 55 | same |
| b | 100000 | plain | 1 | 0 | 214 | 361 | same |
| b | 100000 | plain | 2 | 0 | 202 | 361 | same |
| b | 100000 | bad | 1 | 0 | 202 | 361 | same |
| b | 100000 | bad | 2 | 0 | 203 | 361 | same |

**16/16 cells exit 0, every raw base-1/head-1 pair byte-identical**, against the C control (a) and the faithful port
(b). This is the first oracle run in which every line of the log is produced by a collector whose orchestration is
the native orchestrate.zig: the run is started by `enterFromAllocator` called as Zig from allocation.zig, the
coordinator's own work entry is collected through `collect.collect` as Zig, the end of the run (`finishGc`) calls
`finalize.walkQueues`, `roots.gen2Cleanup`, `collect.freeGen2Unmarked`, `collect.freeNurseryUncopied` and
`debug.logCollection` as Zig, and every `gc_status` transition on the way goes through the typed `atomic.casStatus`
/`loadStatus` sites. The single-threaded program also exercises the second thread context the booted VM carries
(the per-run lines with coord=0), so the work-list and release paths of a stolen/exited thread are in the log too.

Also from this build (ngc-task8-raw/): exported names of ng-n-base equal ng-c-base's (2850 each, `exports.diff`
empty); `objdump -d` of ng-n-base's libmoar.so finds 0 `mfence` (Ruling R5 holds).
