# GC suites, final (Task 10, Step 5)

```
GC final suites record (Task 10, step 5)
Date:          2026-11-08, 14:07-14:37 CET
MoarVM:        zig-gc-port at e0444fc47 (the last port commit is 5abaf4507); traces 3349236 before this record
Prefixes:      gc-c-base, gc-c-stress (139d404ed: the C collector with the Zig hash engine);
               gc-z-base (e0444fc47), gc-z-stress (5abaf4507, the same MoarVM sources as e0444fc47), all under /tmp/claude-1000;
               base = default options, stress = -Dgc-debug=1 -Dnursery-size=524288
Runner:        nqp zig-hash-strategies 287d13264 and rakudo zig-build-spec 3d626b9b24, installed against
               /tmp/claude-1000/tune-zig-prefix; the collector chosen by LD_LIBRARY_PATH=<prefix>/lib
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap; Zig 0.16.0
Drivers:       gc-final-suites-driver.sh (Zig suites and script checks; load < 2.0 before each),
               gc-final-maketest-driver.sh (make test per project and prefix; load < 2.0 before each)
Raw:           gc-final-suites-raw/: zig-suites.tsv, maketest-summary.tsv, <project>-<prefix>.list (sorted per-file
               verdicts), the --summary all outputs, prove.out, perl-c.out, allc-test.out
```

## Zig suites (MoarVM checkout at e0444fc47)

| command | exit | output | summary |
|---|---:|---|---|
| `zig build unit-test` | 0 | 0 bytes | 68/68 steps; 328/342 tests (14 skipped); gc-test 45 pass, 3 skip |
| `zig build -Dgc-debug=1 unit-test` | 0 | 0 bytes | 68/68 steps; 331/342 tests (11 skipped); gc-test 48/48 |
| `zig build test --prefix /tmp/claude-1000/gc-t10-check` | 0 | 0 bytes | 81/81 steps; 328/342 (14 skipped) |
| `zig build -Dgc-debug=1 test --prefix /tmp/claude-1000/gc-t10-check` | 0 | 0 bytes | 81/81 steps; 331/342 (11 skipped) |
| `zig build strategy-test -Dnqp-prefix=/tmp/claude-1000/tune-zig-prefix` | 0 | (with --summary all) | 2/2 steps, strategy.nqp success |
| `zig build -Dzig-impl=false install` + `test --prefix /tmp/claude-1000/gc-allc-check` | 0 | | all-C fallback: 67/67 steps; 170/174 (4 skipped); 51 `MVM_gc_` exports; prefix deleted |
| `prove tools/bench/t/` (with /tmp/claude-1000/gc-c-oracle present) | 0 | | Files=6, Tests=107, PASS; `gc-oracle.t` ran its 22 tests (not skipped); hash-bench-hint.t and uni-bench.t skip without their nqp variables, as before this campaign |
| `zig fmt --check src/zig` | 0 | 0 bytes | |
| `perl -c` on tools/bench/t/*.t and tools/bench/*.pl | 0 | | 10 files, syntax OK |
| `sh -n` on tools/bench/gc/*.sh and tools/bench/*.sh | 0 | 0 bytes | |
| `python3 -m py_compile tools/bench/timev.py` | 0 | 0 bytes | |

The three gc-test skips at debug level 0 are tests that apply only at `-Dgc-debug=1` (they run there: 48/48). The all-C fallback build was started at a 1-minute load of 4.63 (the tail of the rakudo stress run), against the rule of load under 2.0 before a build; it is a pass/fail check, not a timing, and passed.

## nqp and rakudo `make test` under both collectors

| project | prefix | exit | seconds | load before | Files / Tests | Result |
|---|---|---:|---:|---:|---|---|
| nqp | gc-c-base | 0 | 19 | 0.90 | 150 / 13746 | PASS |
| nqp | gc-z-base | 0 | 18 | 0.84 | 150 / 13746 | PASS |
| rakudo | gc-c-base | 2 | 124 | 0.73 | 599 / 11162 | FAIL (1 file) |
| rakudo | gc-z-base | 2 | 129 | 0.93 | 599 / 11162 | FAIL (1 file) |
| nqp | gc-c-stress | 0 | 20 | 0.87 | 150 / 13746 | PASS |
| nqp | gc-z-stress | 0 | 21 | 0.83 | 150 / 13746 | PASS |
| rakudo | gc-c-stress | 2 | 151 | 0.91 | 599 / 11162 | FAIL (1 file) |
| rakudo | gc-z-stress | 2 | 154 | 0.81 | 599 / 11162 | FAIL (1 file) |

The per-file verdict lists are identical between the C and the Zig collector in each of the four pairs (`diff` empty). The one failing rakudo file is the same everywhere: `t/04-nativecall/02-simple-args.t`, subtests 17-18 (the unsigned uint8/uint16 arguments), under the plain C collector as under every other prefix; it was recorded as pre-existing and unrelated to the GC in Task 9. The Test Summary Reports of the four rakudo runs are otherwise identical (two TODO-passed files). The nqp `t/hll/02-modules.t`, `03-exports.t` and `04-import.t` are skipped by nqp itself ("design changes, need re-work") under every prefix.

Verdict: suites green, test output pristine, and identical pass/fail lists under both collectors in the normal and the stress configuration.
