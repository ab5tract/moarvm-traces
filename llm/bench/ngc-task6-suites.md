# ngc Task 6 suites: nqp and rakudo make test under ng-n-base and ng-n-stress, per-file lists identical to the C control's

```
ngc suites record (Task 6, step 5)
Date:          2026-11-10 14:20:24-14:32:16 CET
MoarVM:        zig-native-gc at 2f6736cdf ("GC native: collect"); traces bed47ea before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Prefixes:      ng-n-base and ng-n-stress (-Dgc-debug=1 -Dnursery-size=524288) rebuilt at 2f6736cdf (ngc-task6-raw/builds.tsv);
               C controls ng-c-base and ng-c-stress (Task 1); the collector chosen by LD_LIBRARY_PATH=<prefix>/lib against
               the moar, nqp (zig-hash-strategies 41e7210ba) and rakudo (zig-build-spec 042608fb82) of
               /tmp/claude-1000/tune-zig-prefix
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Driver:        sh ngc-maketest-driver.sh /tmp/claude-1000/ngc/t6/suites nqp:n-base nqp:n-stress nqp:c-base rakudo:n-base
               rakudo:n-stress rakudo:c-stress (serial; load < 2.0 before each; each make test under
               systemd-run --user --scope -q -p MemoryMax=8G). nqp:c-base and rakudo:c-stress are run as controls here
               because Task 1 recorded only nqp:c-stress and rakudo:c-base (ngc-suites-raw/); both match Campaign 4's
               gc-final-suites-raw lists byte for byte.
Raw:           ngc-task6-suites-raw/: summary.tsv, <project>-<prefix>.list (sorted per-file verdicts), rakudo-*.out
```

| project | prefix | exit | seconds | load before | Files / Tests | Result | list compared with | same |
|---|---|---:|---:|---:|---|---|---|---|
| nqp | ng-n-base | 0 | 18 | 0.91 | 150 / 13746 | PASS | nqp-c-base.list (this run) | yes |
| nqp | ng-n-stress | 0 | 20 | 0.86 | 150 / 13746 | PASS | ngc-suites-raw/nqp-c-stress.list (Task 1) | yes |
| nqp | ng-c-base | 0 | 17 | 1.13 | 150 / 13746 | PASS | gc-final-suites-raw/nqp-c-base.list | yes |
| rakudo | ng-n-base | 2 | 124 | 1.07 | 599 / 11162 | FAIL (1 file) | ngc-suites-raw/rakudo-c-base.list (Task 1) | yes |
| rakudo | ng-n-stress | 2 | 145 | 1.35 | 599 / 11162 | FAIL (1 file) | rakudo-c-stress.list (this run) | yes |
| rakudo | ng-c-stress | 2 | 148 | 0.99 | 599 / 11162 | FAIL (1 file) | gc-final-suites-raw/rakudo-c-stress.list | yes |

"same" is `cmp` of the sorted per-file verdict lists. The failing rakudo file is the pre-existing
`t/04-nativecall/02-simple-args.t` subtests 17-18, under the C control as under the native head; the Test Summary
Report lists the same two TODO-passed files on both. The nqp lists carry the three skipped `t/hll/0[234]-*.t` entries
as "notok", as every earlier list does; `Result: PASS`.
