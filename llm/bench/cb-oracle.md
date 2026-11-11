# cb oracle: group (a), 8/8 cells exit 0, raw logs byte-identical

```
cb oracle record (Task 2, step 3, group (a))
Date:          2026-11-11 18:36:03-18:51:57 CET (group a: start to last cell); driver stopped 18:53:28 (see "Stress pair")
MoarVM:        gc-call-boundary at 6cfbe7e3f ("traces: cb call-boundary audit"); src/ as at c5aebb78a; traces 0e384b9
               before this record
Toolchain:     Zig 0.17.1 (/usr/bin/zig)
Prefixes:      ng-c-oracle (C collector + Zig hash engine, -Dzig-gc=false -Dgc-debug=1, Campaign 6 Task 1) against
               cb-n-oracle (native, -Dgc-debug=1, built at 6cfbe7e3f, cb-prefixes.md); versions 2026.09-270-gf0582f365 /
               2026.09-301-g6cfbe7e3f (equal length), paths of equal length
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (rakudo zig-build-spec 042608fb82; libmoar from
               LD_LIBRARY_PATH); nqp 41e7210ba
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Environment:   MVM_SPESH_DISABLE=1 RAKUDO_NO_PRECOMPILATION=1 MVM_GC_LOG; tier 2 adds MVM_GC_DEBUG_RSS=104857600;
               the driver and each cell under systemd-run --user --scope -q -p MemoryMax=8G
Command:       systemd-run --user --scope -q -p MemoryMax=8G sh traces/llm/bench/cb-oracle-driver.sh /tmp/claude-1000/cb/oracle
               per cell: tools/bench/gc/oracle.sh --base=B --head=H --volume=V [--bad-packages] --tier=T --out=...
               (three logged runs of crc-sequential.raku per side; each side repeatable, then base-1 vs head-1)
Volumes:       10000 and 100000
Load:          1-minute load before each cell of group a 1.04-1.38 (matrix column 7)
Raw:           cb-oracle-raw/matrix.tsv (group volume set tier exit seconds load lines raw_cmp), <cell>-{base,head}.log
               (base-1.log and head-1.log of each cell), <cell>.stderr, oracle-driver.out
```

| group | volume | set | tier | exit | seconds | load before | log lines | raw cmp base-1/head-1 |
|---|---:|---|---:|---:|---:|---:|---:|---|
| a | 10000 | plain | 1 | 0 | 37 | 1.04 | 55 | same |
| a | 10000 | plain | 2 | 0 | 37 | 1.15 | 55 | same |
| a | 10000 | bad | 1 | 0 | 37 | 1.26 | 55 | same |
| a | 10000 | bad | 2 | 0 | 37 | 1.38 | 55 | same |
| a | 100000 | plain | 1 | 0 | 198 | 1.28 | 361 | same |
| a | 100000 | plain | 2 | 0 | 202 | 1.21 | 361 | same |
| a | 100000 | bad | 1 | 0 | 205 | 1.26 | 361 | same |
| a | 100000 | bad | 2 | 0 | 201 | 1.24 | 361 | same |

**8/8 cells exit 0, every raw base-1/head-1 pair byte-identical** (16 logs compared): with gen2Add, addToQueue and the
worklist growth, create, presizeFor and walkQueues kept out of line, and markCollectable and gen2Add reached as Zig
imports, the native collector's per-collection log still equals the C control's in every line at both tiers. The
line counts (55, 361) equal ngc-oracle.md's group (a). Every oracle.sh also checked each side's three runs for
repeatability before comparing.

## Stress pair (group s): not usable as an oracle, the C control does not repeat

The driver also carries a group s, ng-c-stress against cb-n-stress (-Dgc-debug=1 -Dnursery-size=524288, both sides),
run after group a. Neither Campaign 6 nor this brief ran the oracle on the stress prefixes. Its first two cells
exited 2, "base not repeatable": the C control, run three times, gives three different logs. At the 512 KiB nursery
the promoted bytes vary from run to run, starting at line 12 or 13 of 1806. The cause was not investigated; it is
not the precompilation variation that RAKUDO_NO_PRECOMPILATION=1 already removes (gc-oracle-repeatability.md), since
that is set here too:

| cell | exit | load before | lines | oracle.sh verdict |
|---|---:|---:|---:|---|
| s 10000 plain 1 | 2 | 1.05 | 1806 | base not repeatable: base-1 vs base-2 line 13, `promoted=109524 since_full=5251861` vs `promoted=109348 since_full=5251685` |
| s 10000 plain 2 | 2 | 1.13 | 1806 | base not repeatable: base-1 vs base-2 line 13, `promoted=109476 since_full=5252141` vs `promoted=109340 since_full=5252005` |

The head side is just as unrepeatable (s 10000 plain 2: head-1 vs head-2 and head-1 vs head-3 differ at line 12), and
in s 10000 plain 1 the three base/head pairs differ at lines 13, 13 and 12. So this is a property of the workload at
that nursery size, not of either build. The driver was stopped by PID during the third cell (s 10000 bad 1,
oracle-driver.out "driver exit 143"), because the remaining cells could not pass. Raw: cb-oracle-raw/s-v10000-plain-t1-{base,head}.log,
s-v10000-plain-t{1,2}.stderr, s-v10000-bad-t1-killed.stderr. To re-run only the meaningful group: `sh cb-oracle-driver.sh OUT a`.
