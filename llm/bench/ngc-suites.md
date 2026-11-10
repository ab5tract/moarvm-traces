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

## Acceptance (Task 9, Step 5): C control and native, base and stress, per-file lists identical

```
ngc suites record (Task 9, step 5)
Date:          2026-11-10 20:32:19-20:50:35 CET
MoarVM:        zig-native-gc at 1a70642f9; ng-n-base and ng-n-stress built at b0b3a48d6 (src/zig unchanged since, not
               rebuilt); ng-c-base and ng-c-stress from Task 1; libmoar chosen by LD_LIBRARY_PATH=<prefix>/lib against the
               moar, nqp (41e7210ba) and rakudo (042608fb82) of /tmp/claude-1000/tune-zig-prefix
Driver:        sh ngc-maketest-driver.sh /tmp/claude-1000/ngc/acc/suites nqp:c-base nqp:n-base nqp:c-stress nqp:n-stress
               rakudo:c-base rakudo:n-base rakudo:c-stress rakudo:n-stress (fourth stage of ngc-acceptance-master.sh;
               serial, C and native interleaved, load < 2.0 before each, each make test under MemoryMax=8G). All eight
               run fresh at Task 9 (the ng-n-* sides were also run at Task 8 on the same binaries, ngc-task8-suites.md;
               not cited in place of a fresh run). A controller probe of one spectest file ran 20:41:53-20:42:36,
               between rakudo n-base (ended 20:41:43) and c-stress (started about 20:43:43, the driver waiting for load);
               these suites are not timed.
Raw:           ngc-suites-acc-raw/: summary.tsv, <project>-<prefix>.list (sorted per-file verdicts), .out, suites-driver.out
```

| project | prefix | exit | seconds | load before | Files / Tests | Result | same list as the C side |
|---|---|---:|---:|---:|---|---|---|
| nqp | ng-c-base | 0 | 17 | 1.97 | 150 / 13746 | PASS | (control) |
| nqp | ng-n-base | 0 | 18 | 1.89 | 150 / 13746 | PASS | yes |
| nqp | ng-c-stress | 0 | 20 | 1.68 | 150 / 13746 | PASS | (control) |
| nqp | ng-n-stress | 0 | 20 | 1.40 | 150 / 13746 | PASS | yes |
| rakudo | ng-c-base | 2 | 124 | 1.42 | 599 / 11162 | FAIL | (control) |
| rakudo | ng-n-base | 2 | 124 | 1.13 | 599 / 11162 | FAIL | yes |
| rakudo | ng-c-stress | 2 | 145 | 1.13 | 599 / 11162 | FAIL | (control) |
| rakudo | ng-n-stress | 2 | 147 | 1.02 | 599 / 11162 | FAIL | yes |

"same" is `cmp` of the sorted per-file verdict lists of ng-n-<x> against ng-c-<x>: identical for all four pairs (nqp
base, nqp stress, rakudo base, rakudo stress). The lists also equal the earlier controls: nqp-c-stress and
rakudo-c-base equal Task 1's (ngc-suites-raw/), nqp-c-base equals Task 8's nqp-n-base, rakudo-n-stress equals Task
8's. The four rakudo runs fail only on the pre-existing `t/04-nativecall/02-simple-args.t` subtests 17-18 (Wstat 512),
and the Test Summary Reports of c and n are identical line for line at both nursery sizes except the wallclock
figure (the same file, the same failed subtests, the same two TODO-passed files
t/09-moar/Line_Break__LineBreak.t 1-2 and t/12-rakuast/xx-fixed-in-rakuast.rakutest 76). The nqp lists carry the
three skipped `t/hll/0[234]-*.t` as "notok" on every side, `Result: PASS`.
