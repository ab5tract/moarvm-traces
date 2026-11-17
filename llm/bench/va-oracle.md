# va oracle: group a, 8 of 8 cells exit 0, raw logs byte-identical (C array vs Zig array)

```
va oracle record (Task 8, Step 2; spec 7 item 4)
Date:          2026-11-17 13:38:20-13:54:25 CET
MoarVM:        zig-vmarray at bea13d101; both prefixes built at 472cf7e92 (va-prefixes.md, Task 8)
Prefixes:      base va-c-oracle (C array, -Dzig-reprs=false -Dgc-debug=1), head va-n-oracle (Zig array, -Dgc-debug=1);
               version 2026.09-327-g472cf7e92 on both, paths of equal length, 2,852 exports each, the same list
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (execs /tmp/claude-1000/tune-zig-prefix/bin/moar,
               libmoar from LD_LIBRARY_PATH)
Environment:   MVM_SPESH_DISABLE=1 RAKUDO_NO_PRECOMPILATION=1 MVM_GC_LOG; tier 2 adds MVM_GC_DEBUG_RSS=104857600;
               each cell under systemd-run --user --scope -q -p MemoryMax=8G
Command:       sh traces/llm/bench/va-oracle-driver.sh /tmp/claude-1000/va/t8/ev/oracle (first stage of
               va-evidence-master.sh); per cell tools/bench/gc/oracle.sh --base=B --head=H --volume=V [--bad-packages]
               --tier=T --out=... (three logged runs of crc-sequential.raku per side; each side repeatable, then
               base-1 vs head-1)
Load:          1-minute load before each cell 0.80-1.55 (matrix column 7); no raku or moar process before the stage
Raw:           va-oracle-raw/matrix.tsv (group volume set tier exit seconds load lines raw_cmp),
               <cell>-{base,head}.log (base-1.log and head-1.log of each cell), oracle-driver.out
```

| group | volume | set | tier | exit | seconds | load before | log lines | raw cmp base-1/head-1 |
|---|---:|---|---:|---:|---:|---:|---:|---|
| a | 10000 | plain | 1 | 0 | 39 | 0.80 | 55 | same |
| a | 10000 | plain | 2 | 0 | 38 | 1.40 | 55 | same |
| a | 10000 | bad | 1 | 0 | 38 | 1.47 | 55 | same |
| a | 10000 | bad | 2 | 0 | 38 | 1.55 | 55 | same |
| a | 100000 | plain | 1 | 0 | 206 | 1.28 | 361 | same |
| a | 100000 | plain | 2 | 0 | 205 | 1.44 | 361 | same |
| a | 100000 | bad | 1 | 0 | 200 | 1.18 | 361 | same |
| a | 100000 | bad | 2 | 0 | 200 | 1.18 | 361 | same |

Every cell: oracle.sh exit 0 ("identical", 55 lines at volume 10,000, 361 at
100,000), each side repeatable over its three runs, and the raw per-collection
logs of base run 1 and head run 1 byte-identical (`cmp`), tier-2 fields
(`full=`, `gen2_freed=`) included. The driver exited 0.

**Verdict: 8 of 8, pass.** The array's mark (`gc_mark`, `gc_mark_repr_data`)
feeds the collector exactly as the C's does: the same collections, the same
promoted byte counts, the same frees, at both volumes and with
`--bad-packages`.
