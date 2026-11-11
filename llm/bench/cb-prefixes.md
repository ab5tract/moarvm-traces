# cb prefixes: the builds of the call-boundary campaign

```
Toolchain:  Zig 0.17.1 (/usr/bin/zig)
Memory:     every build under systemd-run --user --scope -q -p MemoryMax=8G
Hygiene:    rm -f src/gen/config.h src/gen/config.c src/gen/config.o before every zig build; 1-minute load under 2.0
Controls:   ng-c-syms, ng-n-syms (and the -base prefixes) as they stand from Campaign 6 (ngc-prefixes.md)
```

| prefix | built | from | options | 1-min load before | notes |
|---|---|---|---|---|---|
| cb-n-syms | 2026-11-11 18:18 CET, about 70 s | gc-call-boundary at c5aebb78a ("GC: keep the worklist growth and walkQueues out of line as the C does"; built from the working tree whose src/ equalled that commit, committed straight after) | `zig build install --prefix /tmp/claude-1000/cb-n-syms -Dstrip=false` | 0.37 | Task 1. `nm -D --defined-only`: 2850 names, the same set as ng-n-syms and ng-c-syms. `tools/bench/gc/call-boundary.sh /tmp/claude-1000/cb-n-syms/lib`: exit 0, 18 of 18 rows. An earlier build of the same prefix at 782a56faa (the four edits only, 18:09, load 0.84) was overwritten; its size join is in cb-audit.md. |
| cb-n-oracle | 2026-11-11 18:32:24 CET, 48 s | gc-call-boundary at 6cfbe7e3f ("traces: cb call-boundary audit"; src/ as at c5aebb78a) | `zig build install --prefix /tmp/claude-1000/cb-n-oracle -Dgc-debug=1` | 0.25 | Task 2, cb-prefixes-raw/build.sh. Native Zig GC. `moar --version`: "This is MoarVM version 2026.09-301-g6cfbe7e3f built with JIT support" (same length as ng-c-oracle's 2026.09-270-gf0582f365). Oracle head against ng-c-oracle (cb-oracle.md group a). |
| cb-n-base | 2026-11-11 18:33:12 CET, 47 s | gc-call-boundary at 6cfbe7e3f | `zig build install --prefix /tmp/claude-1000/cb-n-base` | 1.72 | Task 2. `moar --version`: "This is MoarVM version 2026.09-301-g6cfbe7e3f built with JIT support". `nm -D --defined-only`: 2850 names, the same set as ng-c-base (diff empty). Unit tests at the same tip, after the three builds: `zig build test` 105/105 steps (176/188 tests, 12 skipped; load 0.75; shim, hash-str and gc tests run genuinely, the 16 small per-file tests cached) and `zig build unit-test -Dgc-debug=1` gc-test 66 pass (66 total; load 1.61; compiled and run genuinely); logs cb-prefixes-raw/zig-build-{test,unit-test}.log. |
| cb-n-stress | 2026-11-11 18:34:59 CET, 48 s | gc-call-boundary at 6cfbe7e3f | `zig build install --prefix /tmp/claude-1000/cb-n-stress -Dgc-debug=1 -Dnursery-size=524288` | 0.89 (after one 60 s wait at 2.21) | Task 2. `moar --version`: "This is MoarVM version 2026.09-301-g6cfbe7e3f built with JIT support". Oracle head against ng-c-stress (cb-oracle.md group s). |
