# ngc Task 5 oracle: groups (a) and (b), 16/16 cells exit 0, raw logs byte-identical

```
ngc oracle record (Task 5, step 5, groups (a) and (b))
Date:          2026-11-10 12:39:45-13:11:34 CET (the matrix: start to last cell)
MoarVM:        zig-native-gc at 45a5575cb ("GC native: roots"); traces 841a787 before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Prefixes:      group (a) ng-c-oracle (C collector + Zig hash engine, -Dzig-gc=false -Dgc-debug=1, Task 1) against
               ng-n-oracle (native head, -Dgc-debug=1, rebuilt at 45a5575cb); group (b) ng-f-oracle (faithful port,
               Task 1) against ng-n-oracle; versions 2026.09-270-gf0582f365 / 2026.09-279-g45a5575cb (equal length),
               paths 11 characters; builds ngc-task5-raw/builds.tsv, build.sh
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (rakudo zig-build-spec 042608fb82; execs
               /tmp/claude-1000/tune-zig-prefix/bin/moar, libmoar from LD_LIBRARY_PATH); nqp 41e7210ba
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Environment:   MVM_SPESH_DISABLE=1 RAKUDO_NO_PRECOMPILATION=1 MVM_GC_LOG; tier 2 adds MVM_GC_DEBUG_RSS=104857600;
               each cell under systemd-run --user --scope -q -p MemoryMax=8G
Command:       sh ngc-oracle-driver.sh /tmp/claude-1000/ngc/t5/oracle a b
               per cell: tools/bench/gc/oracle.sh --base=B --head=H --volume=V [--bad-packages] --tier=T --out=...
               (three logged runs of crc-sequential.raku per side; each side repeatable, base-1 vs head-1)
Volumes:       10000 and 100000 only (the 1M and 10M volumes stay excluded, user 2026-11-08 and 2026-11-10)
Load:          1-minute load before each cell 0.76-1.27 (matrix column 7)
Raw:           ngc-task5-oracle-raw/matrix.tsv (group volume set tier exit seconds load lines raw_cmp),
               <cell>-{base,head}.log (base-1.log and head-1.log of each cell), driver.out (driver exit 0)
```

| group | volume | set | tier | exit | seconds | log lines | raw cmp base-1/head-1 |
|---|---:|---|---:|---:|---:|---:|---|
| a | 10000 | plain | 1 | 0 | 37 | 55 | same |
| a | 10000 | plain | 2 | 0 | 37 | 55 | same |
| a | 10000 | bad | 1 | 0 | 36 | 55 | same |
| a | 10000 | bad | 2 | 0 | 37 | 55 | same |
| a | 100000 | plain | 1 | 0 | 199 | 361 | same |
| a | 100000 | plain | 2 | 0 | 200 | 361 | same |
| a | 100000 | bad | 1 | 0 | 201 | 361 | same |
| a | 100000 | bad | 2 | 0 | 201 | 361 | same |
| b | 10000 | plain | 1 | 0 | 37 | 55 | same |
| b | 10000 | plain | 2 | 0 | 37 | 55 | same |
| b | 10000 | bad | 1 | 0 | 38 | 55 | same |
| b | 10000 | bad | 2 | 0 | 37 | 55 | same |
| b | 100000 | plain | 1 | 0 | 201 | 361 | same |
| b | 100000 | plain | 2 | 0 | 205 | 361 | same |
| b | 100000 | bad | 1 | 0 | 202 | 361 | same |
| b | 100000 | bad | 2 | 0 | 204 | 361 | same |

Every cell exits 0 (each side repeatable, base and head identical) and the raw base-1/head-1 logs are byte-identical:
the native roots (typed signatures, the comptime `instance_roots` and `thread_roots` tables walked with `inline for`
in the C order, slices over the permanent, temporary and gen2 root lists, the frame register and lexical scans over
`work[0..num_locals]`/`types[0..num_locals]`) change no decision the per-collection log records, against the C
control (a) or the faithful port (b). The roots order is the load-bearing part: a reordered entry would move every
copied address, and the logs would differ.

Also from this build (ngc-task5-raw/): exported names of ng-n-base equal ng-c-base's (2850, `exports.diff` empty);
`walk-codegen.txt` compares the instance and thread walks of ng-f-syms and ng-n-syms (`-Dstrip=false`, from the
same commit as the oracle prefixes): instance walk 1876 vs 1873 instructions, 27 snapshot calls each, 74 vs 73
backward jumps; the `inline for` tables compile to the same straight sequence the faithful port wrote by hand.
