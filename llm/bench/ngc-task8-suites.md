# ngc Task 8 suites: nqp and rakudo make test under ng-n-base and ng-n-stress, per-file lists identical to the C control's

```
ngc suites record (Task 8, step 5)
Date:          2026-11-10 18:16:39-18:23:46 CET
MoarVM:        zig-native-gc at b0b3a48d6 ("GC native: orchestrate"); traces 5ac8b7b before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Prefixes:      ng-n-base and ng-n-stress (-Dgc-debug=1 -Dnursery-size=524288) rebuilt at b0b3a48d6 (ngc-task8-raw/builds.tsv);
               C controls ng-c-base and ng-c-stress (Task 1); the collector chosen by LD_LIBRARY_PATH=<prefix>/lib against
               the moar, nqp (zig-hash-strategies 41e7210ba) and rakudo (zig-build-spec 042608fb82) of
               /tmp/claude-1000/tune-zig-prefix
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Driver:        sh ngc-maketest-driver.sh /tmp/claude-1000/ngc/t8/suites nqp:n-base nqp:n-stress rakudo:n-base
               rakudo:n-stress (serial; load < 2.0 before each; each make test under
               systemd-run --user --scope -q -p MemoryMax=8G), right after the tripwire with nothing else running.
               Controls: the C lists of Task 1 (ngc-suites-raw/) and Task 6 (ngc-task6-suites-raw/).
Raw:           ngc-task8-suites-raw/: summary.tsv, <project>-<prefix>.list (sorted per-file verdicts), rakudo-*.out
```

| project | prefix | exit | seconds | load before | Files / Tests | Result | list compared with | same |
|---|---|---:|---:|---:|---|---|---|---|
| nqp | ng-n-base | 0 | 18 | 0.71 | 150 / 13746 | PASS | ngc-task6-suites-raw/nqp-c-base.list | yes |
| nqp | ng-n-stress | 0 | 19 | 0.85 | 150 / 13746 | PASS | ngc-suites-raw/nqp-c-stress.list (Task 1) | yes |
| rakudo | ng-n-base | 2 | 122 | 1.08 | 599 / 11162 | FAIL (1 file) | ngc-suites-raw/rakudo-c-base.list (Task 1) | yes |
| rakudo | ng-n-stress | 2 | 147 | 0.85 | 599 / 11162 | FAIL (1 file) | ngc-task6-suites-raw/rakudo-c-stress.list | yes |

"same" is `cmp` of the sorted per-file verdict lists. The failing rakudo file is the pre-existing
`t/04-nativecall/02-simple-args.t` subtests 17-18, under the C control as under the native head (the Test Summary
Report of both .out files names only that file). The nqp lists carry the three skipped `t/hll/0[234]-*.t` entries as
"notok", as every earlier list does; `Result: PASS`. These suites start threads (the spesh worker, the event loop,
`Thread`/`Promise` tests), so the signalling, stealing and release paths of the native orchestrate.zig run under them
with the 512 KiB nursery of the stress prefix forcing collections every few allocations.
