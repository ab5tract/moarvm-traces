# ngc acceptance oracle: groups (a), (b), (c), 24/24 cells exit 0, raw logs byte-identical

```
ngc oracle record (Task 9, step 2, groups (a), (b) and (c))
Date:          2026-11-10 18:36:24-19:24:00 CET (the matrix: start to last cell)
MoarVM:        zig-native-gc at 1a70642f9 ("Bench: three-sided ab.sh"); src/zig identical to b0b3a48d6, where ng-n-* were
               built (ac196f5eb and 1a70642f9 changed only the traces pointer, tools/bench/gc/ab.sh and its README, so
               ng-n-* were not rebuilt); traces 1b65cba before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Prefixes:      (a) ng-c-oracle (C collector + Zig hash engine, -Dzig-gc=false -Dgc-debug=1, Task 1) against ng-n-oracle
               (native, -Dgc-debug=1, built at b0b3a48d6); (b) ng-f-oracle (faithful port, Task 1) against ng-n-oracle;
               (c) ng-c-oracle against ng-f-oracle (the controls, as at Task 1); versions 2026.09-270-gf0582f365 /
               2026.09-270-gf0582f365 / 2026.09-289-gb0b3a48d6 (equal length), paths of equal length
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (rakudo zig-build-spec 042608fb82; execs
               /tmp/claude-1000/tune-zig-prefix/bin/moar, libmoar from LD_LIBRARY_PATH); nqp 41e7210ba
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Environment:   MVM_SPESH_DISABLE=1 RAKUDO_NO_PRECOMPILATION=1 MVM_GC_LOG; tier 2 adds MVM_GC_DEBUG_RSS=104857600;
               each cell under systemd-run --user --scope -q -p MemoryMax=8G
Command:       sh ngc-oracle-driver.sh /tmp/claude-1000/ngc/acc/oracle a b c (first stage of ngc-acceptance-master.sh)
               per cell: tools/bench/gc/oracle.sh --base=B --head=H --volume=V [--bad-packages] --tier=T --out=...
               (three logged runs of crc-sequential.raku per side; each side repeatable, then base-1 vs head-1)
Volumes:       10000 and 100000 only (1M and 10M excluded by the user, 2026-11-08 and 2026-11-10)
Load:          1-minute load before each cell 0.34-1.66 (matrix column 7)
Raw:           ngc-oracle-raw/matrix.tsv (group volume set tier exit seconds load lines raw_cmp), <cell>-{base,head}.log
               (base-1.log and head-1.log of each cell), oracle-driver.out (driver exit 0)
```

| group | volume | set | tier | exit | seconds | load before | log lines | raw cmp base-1/head-1 |
|---|---:|---|---:|---:|---:|---:|---:|---|
| a | 10000 | plain | 1 | 0 | 36 | 0.34 | 55 | same |
| a | 10000 | plain | 2 | 0 | 37 | 0.66 | 55 | same |
| a | 10000 | bad | 1 | 0 | 36 | 0.87 | 55 | same |
| a | 10000 | bad | 2 | 0 | 37 | 0.93 | 55 | same |
| a | 100000 | plain | 1 | 0 | 198 | 0.96 | 361 | same |
| a | 100000 | plain | 2 | 0 | 198 | 1.27 | 361 | same |
| a | 100000 | bad | 1 | 0 | 200 | 1.04 | 361 | same |
| a | 100000 | bad | 2 | 0 | 203 | 1.19 | 361 | same |
| b | 10000 | plain | 1 | 0 | 37 | 1.66 | 55 | same |
| b | 10000 | plain | 2 | 0 | 36 | 1.45 | 55 | same |
| b | 10000 | bad | 1 | 0 | 36 | 1.44 | 55 | same |
| b | 10000 | bad | 2 | 0 | 37 | 1.37 | 55 | same |
| b | 100000 | plain | 1 | 0 | 200 | 1.19 | 361 | same |
| b | 100000 | plain | 2 | 0 | 199 | 1.07 | 361 | same |
| b | 100000 | bad | 1 | 0 | 200 | 1.17 | 361 | same |
| b | 100000 | bad | 2 | 0 | 202 | 1.25 | 361 | same |
| c | 10000 | plain | 1 | 0 | 37 | 1.10 | 55 | same |
| c | 10000 | plain | 2 | 0 | 37 | 1.10 | 55 | same |
| c | 10000 | bad | 1 | 0 | 37 | 1.21 | 55 | same |
| c | 10000 | bad | 2 | 0 | 37 | 1.17 | 55 | same |
| c | 100000 | plain | 1 | 0 | 215 | 1.22 | 361 | same |
| c | 100000 | plain | 2 | 0 | 199 | 1.18 | 361 | same |
| c | 100000 | bad | 1 | 0 | 199 | 1.11 | 361 | same |
| c | 100000 | bad | 2 | 0 | 202 | 1.34 | 361 | same |

**24/24 cells exit 0, every raw base-1/head-1 pair byte-identical**: the native collector's per-collection log equals
the C control's (a) and the faithful port's (b) in every line at both tiers, and the two controls still equal each
other (c), as at Task 1 (ngc-oracle-c.md). A cell is 2 volumes x 2 settings x 2 tiers per group, 8 per group, 24 over
the three groups; the brief's "48 cells" is the number of logs compared (one per side per cell). Every oracle.sh
also checked each side's three runs for repeatability before comparing.
