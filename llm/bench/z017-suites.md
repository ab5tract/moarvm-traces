# zig-017 suites under the 0.17 prefixes (Task 5, Step 5): per-file lists identical to Campaign 4

```
zig-017 suites record (Task 5, step 5)
Date:          2026-11-08 23:4x (z-stress, z-base, all-C c-stress) and 2026-11-09 00:42 (rebuilt c-stress) CET
MoarVM:        zig-017 at b1bbb9dd4; traces 175921d before this record
Prefixes:      z017-prefixes.md; the collector chosen by LD_LIBRARY_PATH=<prefix>/lib against the moar, nqp
               (zig-hash-strategies 41e7210ba) and rakudo (zig-build-spec 042608fb82) of /tmp/claude-1000/tune-zig-prefix
Driver:        z017-maketest-driver.sh (gc-final-maketest-driver.sh re-pointed: nqp:c-stress nqp:z-stress rakudo:z-base;
               load < 2.0 before each, each make test under systemd-run --user --scope -q -p MemoryMax=8G); the
               nqp c-stress re-run after the g7-c-stress rebuild used the same recipe (in the measurement chain)
Raw:           z017-suites-raw/: maketest-summary.tsv, <project>-<prefix>.list (sorted per-file verdicts),
               rakudo-z-base.out, nqp-c-stress-allc.list (the superseded all-C prefix)
Zig suites:    zig build unit-test / test / all-C / check-jit-tools / prove are Task 3 and Task 4's records
               (task-3-report.md, task-4-report.md); not repeated here
```

| project | prefix | exit | seconds | load before | Files / Tests | Result | list vs gc-final-suites-raw |
|---|---|---:|---:|---:|---|---|---|
| nqp | g7-c-stress (C collector + Zig hash) | 0 | 20 | 1.63 | 150 / 13746 | PASS | identical to nqp-c-stress.list |
| nqp | g7-z-stress | 0 | 20 | 1.31 | 150 / 13746 | PASS | identical to nqp-z-stress.list |
| rakudo | g7-z-base | 2 | 125 | 1.21 | 599 / 11162 | FAIL (1 file) | identical to rakudo-z-base.list |
| nqp | g7-c-stress, superseded all-C build | 0 | 36 | 0.97 | 150 / 13746 | PASS | identical to nqp-c-stress.list |

The one failing rakudo file is the pre-existing `t/04-nativecall/02-simple-args.t` subtests 17-18 (unsigned
uint8/uint16 arguments), as under every prefix in Campaign 4. The rakudo Test Summary Report otherwise lists the
same two TODO-passed files (t/09-moar/Line_Break__LineBreak.t, t/12-rakuast/xx-fixed-in-rakuast.rakutest).

Verdict: the same per-file pass/fail lists as Campaign 4 under the stress configuration of both collectors and
under the Zig collector in the normal configuration.
