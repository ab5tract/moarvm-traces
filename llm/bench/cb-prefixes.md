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
