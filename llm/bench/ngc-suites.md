# ngc suites under the controls (Task 1, Step 8): per-file lists identical to Campaign 5

```
ngc suites record (Task 1, step 8)
Date:          2026-11-09 09:57-10:03 CET
MoarVM:        zig-native-gc at f0582f365; traces fb6346e before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Prefixes:      ngc-prefixes.md; the collector chosen by LD_LIBRARY_PATH=<prefix>/lib against the moar, nqp
               (zig-hash-strategies 41e7210ba) and rakudo (zig-build-spec 042608fb82) of /tmp/claude-1000/tune-zig-prefix
Exports:       2850 names (-base), 2852 (-stress), Zig hash engine on every prefix
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Driver:        sh ngc-maketest-driver.sh /tmp/claude-1000/ngc/suites (z017-maketest-driver.sh re-pointed: nqp:c-stress
               nqp:f-stress rakudo:f-base rakudo:c-base; load < 2.0 before each, each make test under
               systemd-run --user --scope -q -p MemoryMax=8G)
Raw:           ngc-suites-raw/: summary.tsv, <project>-<prefix>.list (sorted per-file verdicts), rakudo-*.out
```

| project | prefix | exit | seconds | load before | Files / Tests | Result | list vs z017-suites-raw |
|---|---|---:|---:|---:|---|---|---|
| nqp | ng-c-stress | 0 | 20 | 0.72 | 150 / 13746 | PASS | identical to nqp-c-stress.list |
| nqp | ng-f-stress | 0 | 20 | 0.79 | 150 / 13746 | PASS | identical to nqp-z-stress.list |
| rakudo | ng-f-base | 2 | 126 | 0.76 | 599 / 11162 | FAIL (1 file) | identical to rakudo-z-base.list |
| rakudo | ng-c-base | 2 | 122 | 0.98 | 599 / 11162 | FAIL (1 file) | identical to rakudo-z-base.list |

The failing rakudo file is the pre-existing `t/04-nativecall/02-simple-args.t` subtests 17-18, as under every prefix
of Campaigns 4 and 5; the Test Summary Report lists the same two TODO-passed files. The nqp lists carry the same three
`t/hll/0[234]-*.t` "notok" entries as z017's: those files are skipped ("design changes, need re-work"), which the
list's verdict column reads as notok; `Result: PASS`.
