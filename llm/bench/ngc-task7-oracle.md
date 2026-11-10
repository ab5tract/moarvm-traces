# ngc Task 7 oracle: groups (a) and (b), 16/16 cells exit 0, raw logs byte-identical

```
ngc oracle record (Task 7, step 5, groups (a) and (b))
Date:          2026-11-10 15:47:58-16:20:12 CET (the matrix: start to last cell)
MoarVM:        zig-native-gc at eed1eb72b ("GC native: wb, objectid, finalize, debug"); traces 4f0e4dd before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Prefixes:      group (a) ng-c-oracle (C collector + Zig hash engine, -Dzig-gc=false -Dgc-debug=1, Task 1) against
               ng-n-oracle (native head, -Dgc-debug=1, rebuilt at eed1eb72b); group (b) ng-f-oracle (faithful port,
               Task 1) against ng-n-oracle; versions 2026.09-270-gf0582f365 / 2026.09-285-geed1eb72b (equal length),
               paths 11 characters; builds ngc-task7-raw/builds.tsv, build.sh
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (rakudo zig-build-spec 042608fb82; execs
               /tmp/claude-1000/tune-zig-prefix/bin/moar, libmoar from LD_LIBRARY_PATH); nqp 41e7210ba
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Environment:   MVM_SPESH_DISABLE=1 RAKUDO_NO_PRECOMPILATION=1 MVM_GC_LOG; tier 2 adds MVM_GC_DEBUG_RSS=104857600;
               each cell under systemd-run --user --scope -q -p MemoryMax=8G
Command:       sh ngc-oracle-driver.sh /tmp/claude-1000/ngc/t7/oracle a b
               per cell: tools/bench/gc/oracle.sh --base=B --head=H --volume=V [--bad-packages] --tier=T --out=...
               (three logged runs of crc-sequential.raku per side; each side repeatable, base-1 vs head-1)
Volumes:       10000 and 100000 only (the 1M and 10M volumes stay excluded, user 2026-11-08 and 2026-11-10)
Load:          1-minute load before each cell 0.31-1.30 (matrix column 7)
Raw:           ngc-task7-oracle-raw/matrix.tsv (group volume set tier exit seconds load lines raw_cmp),
               <cell>-{base,head}.log (base-1.log and head-1.log of each cell), driver.out (driver exit 0)
```

| group | volume | set | tier | exit | seconds | log lines | raw cmp base-1/head-1 |
|---|---:|---|---:|---:|---:|---:|---|
| a | 10000 | plain | 1 | 0 | 37 | 55 | same |
| a | 10000 | plain | 2 | 0 | 39 | 55 | same |
| a | 10000 | bad | 1 | 0 | 37 | 55 | same |
| a | 10000 | bad | 2 | 0 | 37 | 55 | same |
| a | 100000 | plain | 1 | 0 | 201 | 361 | same |
| a | 100000 | plain | 2 | 0 | 203 | 361 | same |
| a | 100000 | bad | 1 | 0 | 205 | 361 | same |
| a | 100000 | bad | 2 | 0 | 205 | 361 | same |
| b | 10000 | plain | 1 | 0 | 37 | 55 | same |
| b | 10000 | plain | 2 | 0 | 37 | 55 | same |
| b | 10000 | bad | 1 | 0 | 38 | 55 | same |
| b | 10000 | bad | 2 | 0 | 38 | 55 | same |
| b | 100000 | plain | 1 | 0 | 205 | 361 | same |
| b | 100000 | plain | 2 | 0 | 205 | 361 | same |
| b | 100000 | bad | 1 | 0 | 203 | 361 | same |
| b | 100000 | bad | 2 | 0 | 207 | 361 | same |

**16/16 cells exit 0, every raw base-1/head-1 pair byte-identical**, against the C control (a) and the faithful port
(b). The log is written by the native `debug.zig` (format string and arguments unchanged byte for byte; still reached
through the exported `MVM_gc_debug_log_collection` from orchestrate.zig until Task 8), and every line it records
passes through the rewritten object-id promotion (`objectid.useAllocation`, now called as Zig from collect.zig), the
inlined post-promotion write barrier (`wb.noUpdateReferenced`), the finalize queue walk (`finalize.walkQueues`, which
starts the finalizing run through `collect.collect` as Zig) and the allocator's `finalize.addToQueue`.

Also from this build (ngc-task7-raw/): exported names of ng-n-base equal ng-c-base's (2850, `exports.diff` empty).

## Re-run after review fix round 1 (use_allocation keeps the C NULL contract, MoarVM 6366ac33c)

`objectid.useAllocation` returns `?*anyopaque` again (null for the hash's 0), the export passes it through, and
collect.zig unwraps it with `.?` as the faithful port did. ng-n-oracle rebuilt at 6366ac33c (2026.09-287-g6366ac33c,
ngc-task7-fix-raw/builds.tsv), same driver and command (`sh ngc-oracle-driver.sh /tmp/claude-1000/ngc/t7/fix/oracle a
b`), 2026-11-10 16:35:07-17:07:16 CET, load before each cell 1.00-1.38, driver exit 0; raw ngc-task7-fix-raw/oracle/.
Exported names of ng-n-base 2850, diff against ng-c-base empty (ngc-task7-fix-raw/exports.diff).

| group | volume | set | tier | exit | seconds | log lines | raw cmp base-1/head-1 |
|---|---:|---|---:|---:|---:|---:|---|
| a | 10000 | plain | 1 | 0 | 37 | 55 | same |
| a | 10000 | plain | 2 | 0 | 37 | 55 | same |
| a | 10000 | bad | 1 | 0 | 37 | 55 | same |
| a | 10000 | bad | 2 | 0 | 37 | 55 | same |
| a | 100000 | plain | 1 | 0 | 204 | 361 | same |
| a | 100000 | plain | 2 | 0 | 202 | 361 | same |
| a | 100000 | bad | 1 | 0 | 203 | 361 | same |
| a | 100000 | bad | 2 | 0 | 204 | 361 | same |
| b | 10000 | plain | 1 | 0 | 37 | 55 | same |
| b | 10000 | plain | 2 | 0 | 39 | 55 | same |
| b | 10000 | bad | 1 | 0 | 37 | 55 | same |
| b | 10000 | bad | 2 | 0 | 39 | 55 | same |
| b | 100000 | plain | 1 | 0 | 203 | 361 | same |
| b | 100000 | plain | 2 | 0 | 204 | 361 | same |
| b | 100000 | bad | 1 | 0 | 204 | 361 | same |
| b | 100000 | bad | 2 | 0 | 205 | 361 | same |

**16/16 cells exit 0, every raw base-1/head-1 pair byte-identical.**
