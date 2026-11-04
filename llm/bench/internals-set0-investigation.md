# Set 0 investigation: where does Small-then-Swiss lose the spectest? (Task 9c, 2026-11-04)

```
Task 9c of the internal-tables campaign. Investigation only: no MoarVM source changed.
Date:          2026-11-04, 11:10-13:15 CET
MoarVM:        zig-hash-internals; head 0b581f32e (engine tree identical to eb1537039's, plus the Swiss noinline comment
               and the Small-to-Robin-Hood migration test), base 1478311f6 (Small then Robin Hood), pre-flip 6bbd4612e
               (= eb1537039^, Small then Robin Hood with every other campaign change). moar --version: 2026.09-195-g0b581f32e
nqp:           zig-hash-strategies at 287d13264; rakudo 3d626b9b24 (v2026.09-233); roast fb1d87214 (verified before every run)
Build flags:   default `zig build install --prefix <P>` (zig impl, LTO, ReleaseFast, x86-64-v3, stripped, stats off);
               symbol builds add -Dstrip=false, stats builds -Dhash-stats=true (own prefixes, used only where stated)
CPU:           AMD Ryzen 9 5900X (12 cores, 24 threads), 32 GB, no swap
Prefixes:      base /tmp/claude-1000/internals-base-prefix, head /tmp/claude-1000/tune-zig-prefix, pre-flip /tmp/claude-1000/preflip-prefix,
               symbols /tmp/claude-1000/sym-{base,head}, stats /tmp/claude-1000/stats-{preflip,head}
               (rebuilt: the reboot of 2026-11-04 wiped /tmp/claude-1000). Build times: head 1:46, base 1:02, nqp `make install` 17 s;
               rakudo-m needed no rebuild. The base hash-bench exe is the head's (the `hash-bench-exe` step postdates 1478311f6);
               it links libmoar dynamically and `ldd` with the base LD_LIBRARY_PATH resolves the base lib.
Spectest:      `TEST_JOBS=24 make -o spectest_update spectest` (the `-o spectest_update` keeps roast pinned; plain `make spectest`
               pulls roast to origin/master), .precomp removed before every run, load under 2.0 and no eval-server bench running
               before every run (checked by the runner), timed by tools/bench/timev.py, harness per-file timer on (see methods)
Load:          1-minute load at run starts 1.28-1.85 (internals-set0-inv-spectest-load.log); solo runs 0.6-1.1
Raw files:     traces/llm/bench/internals-set0-inv-* (scripts in internals-set0-inv-scripts/)
```

Methods note. The first attempt at Step 1 was OOM-killed at 11:17: the per-file timer shim (`HarnessTimer.pm`, loaded with
`PERL5OPT=-MHarnessTimer` to set `timer => 1` on TAP::Harness) took `\&TAP::Harness::new`, which is the inherited
`TAP::Object::new` stub resolving back to the override by name, so the harness recursed until memory ran out (29.8 GB). The shim was
corrected to `TAP::Harness->can('new')` and checked under `ulimit -v 400000` before the runs; the check printed `timer=1 jobs=2`
with no "Out of memory". The four Step 1 runs below are all with the corrected shim (the per-file timer line costs nothing measurable;
the walls sit within 3 percent of the pre-reboot ones, see the caveat in Step 1).

## Headline

- The shortfall is real and bigger than Task 9b's: head is 1.031 of base on the combined timev walls (1.035 on the harness's own
  clock), spreads disjoint. Peak RSS is not worse (0.997).
- The flip is the cause. A build of 6bbd4612e (the parent of the flip: Small then Robin Hood, every other campaign change in) times
  like the base on the two heaviest sprintf files (34.3 s vs 34.3 s on sprintf-f, 54.9 s vs 53.6 s on sprintf-x) and the head is 10-14 percent
  slower on them. Not the 22 other commits between 1478311f6 and the flip.
- The loss concentrates in a few long CPU-bound files that sit on the parallel run's critical path: sprintf-f/b/x/e/a/c/u/d, and
  S17-supply/batch.t. 739 of 1365 files are slower, the 20 largest deltas hold 74 percent of the summed delta.
- It is not the hash operations. In the sprintf-f run the head executes 12-14 percent more instructions at the same IPC (242.6-246.9 G vs
  216.1-218.3 G user instructions), with the compile phase identical (5.19-5.25 G) and all hash-op counts per site rising by the same 15-18 percent
  (stats build). The hash symbols hold 2.2-2.5 percent of samples on both builds; the 28 G extra instructions are spread over the interpreter,
  dispatch, spesh guards and JIT code. The program is doing more work under the flipped ladder; this record does not find which
  work. Memory is excluded (Swiss blocks are 0.29-0.67 of Robin Hood's at every size from 65, RSS 0.997).
- The nqp lookup_hit-at-65 loss (1.26) is a harness artifact of the `--nth=all` + large `--sizes` combination: it reproduces under the
  exact Task 9b command (1.28, 1.31, 1.23) and disappears (0.92-0.95) when either the nth setting or the largest size changes; the C-API
  cell is 0.72-0.77 everywhere.

## Step 1: confirm the shortfall (order base, head, head, base)

| run | wall (timev) | harness "wallclock secs" | user s | system s | peak RSS kB | exit |
|---|---:|---:|---:|---:|---:|---:|
| base 1 | 4:51.71 = 291.71 s | 268 | 4610.77 | 391.01 | 1025136 | 0 |
| head 1 | 4:59.67 = 299.67 s | 277 | 4676.07 | 384.23 | 1023324 | 0 |
| head 2 | 4:59.95 = 299.95 s | 277 | 4676.90 | 381.60 | 1020988 | 0 |
| base 2 | 4:49.81 = 289.81 s | 267 | 4609.83 | 390.71 | 1026560 | 0 |

Roast fb1d87214 on all four, `Result: PASS` on all four (Files=1365, Tests=138715). Combined medians (two per side): wall base 290.76 s,
head 299.81 s = 1.031 (harness clock 267.5 vs 277 = 1.035); user 1.014; peak RSS 1025848 vs 1022156 kB = 0.996. Spreads: base 289.81-291.71,
head 299.67-299.95: disjoint, gap 8 s. Against Task 9b's six (base 350.20, head 356.45 s, 1.018, RSS 1.015): the 1.8 percent holds
and is, if anything, larger (3.1 percent) in this session. Caveat: the absolute walls are 17 percent lower than Task 9b's (system
time 390 s here against about 2470 s there) and peak RSS is 1.0 GB against 0.68 GB, so the session conditions differ (the harness
timer, a freshly rebooted machine, no leftover state); the ratio, not the absolute, is the comparable.

## Step 2: the 65-entry nqp hit regression

`hash-ab.sh --rounds=5 --runs=5 --sizes=65,66,70,80,96,112,113,128,200,256 --nth=threshold`, base vs head, both levels (raw
`internals-set0-inv-ladder-s2-*`; the ratios below are median of the round medians, head/base; the brackets are min-max of the round medians).

### lookup_hit by size (the brief's command, 5 rounds)

Level nqp:
| op | 65 | 66 | 70 | 80 | 96 | 112 | 113 | 128 | 200 | 256 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| lookup_hit | 0.92 [17.2-51.3 / 14.9-47.8] | 0.90 [13.2-13.6 / 11.8-12.9] | 1.10 [13.6-20.5 / 15.1-16.8] | 0.84 [14.8-15.2 / 12.1-13.1] | 0.72 [16.4-16.8 / 11.8-12.4] | 0.93 [12.5-12.9 / 11.5-12.1] | 0.95 [12.4-12.6 / 11.8-13.0] | 0.92 [13.2-13.4 / 11.5-13.1] | 0.97 [12.1-12.3 / 11.7-12.2] | 0.89 [13.2-13.5 / 11.5-12.1] |

Level capi:
| op | 65 | 66 | 70 | 80 | 96 | 112 | 113 | 128 | 200 | 256 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| lookup_hit | 0.72 [7.8-8.2 / 5.6-6.0] | 0.71 [8.0-8.2 / 5.4-6.0] | 0.67 [8.3-8.9 / 5.2-6.1] | 0.59 [9.7-10.2 / 5.6-6.1] | 0.49 [11.7-12.2 / 5.6-6.2] | 0.76 [6.9-7.3 / 5.2-5.5] | 0.82 [6.9-7.4 / 5.4-5.9] | 0.70 [7.7-8.0 / 5.3-5.8] | 0.84 [6.5-6.6 / 5.3-5.9] | 0.70 [7.8-8.0 / 5.3-6.0] |

The ratio is below 1 at every size from 65 to 256 on both levels (nqp 0.72-1.10, capi 0.49-0.84; the nqp 65 and 70 cells are the noisy ones, the run's first size is the 65 warm-up cell). The 1.26 does not appear.

### Where 1.26 comes from: the same cell under eight harness shapes (7 rounds, runs=5)

| sizes | --nth | nqp hit 65 (head/base) [base min-max / head min-max] | capi hit 65 | raw |
|---|---|---|---|---|
| 4,16,32,63,64,65,128,256,1024,16384 | all | 1.28 [13.3-14.0 / 15.9-18.3] | 0.74 [7.8-8.1 / 5.3-6.4] | internals-set0-inv-ladder-s2c-*-raw.tsv |
| 4,16,32,63,64,65,128,256,1024,16384 | all | 1.23 [13.2-13.4 / 15.8-18.5] | 0.76 [7.9-8.1 / 5.5-6.5] | internals-set0-inv-ladder-s2j-*-raw.tsv |
| 4,16,32,63,64,65,128,256,1024,16384 | threshold | 0.94 [13.2-13.7 / 12.2-13.9] | 0.72 [7.9-8.2 / 5.5-6.2] | internals-set0-inv-ladder-s2d-*-raw.tsv |
| 4,16,32,63,64,65,16384 | all | 1.31 [13.3-13.7 / 15.7-18.7] | 0.73 [7.8-8.1 / 5.5-6.6] | internals-set0-inv-ladder-s2g-*-raw.tsv |
| 4,16,32,63,64,65,16384 | threshold | 0.95 [13.2-13.6 / 11.6-12.8] | 0.72 [7.7-8.1 / 5.4-6.3] | internals-set0-inv-ladder-s2i-*-raw.tsv |
| 4,16,32,63,64,65 | all | 0.98 [13.2-13.6 / 12.3-13.5] | 0.77 [7.8-8.1 / 5.7-6.4] | internals-set0-inv-ladder-s2h-*-raw.tsv |
| 4,16,32,63,64,65,66,128,256,1024,16384 | threshold | 0.92 [13.2-14.1 / 11.7-13.7] | 0.73 [7.9-8.2 / 5.3-6.5] | internals-set0-inv-ladder-s2f-*-raw.tsv |
| 65 alone, runs=20 | threshold | 0.95 [13.2-13.4 / 12.3-13.1] | 0.77 [7.9-8.1 / 5.7-6.3] | internals-set0-inv-ladder-s2e-*-raw.tsv |

Rows 1 and 2 are the Task 9b shape (nth=all, sizes up to 16384): 1.28 and 1.23 (Task 9b: 1.26, 1.29). Switching nth to threshold (row 3) or dropping the sizes above 65 (row 6) removes it; sizes up to 16384 with nth=all (row 4) keeps it (1.31). The effect needs both, which points at harness process state (what the earlier sizes' insert_nth phase and the large key array leave behind for the specialised time_hit loop), not at an engine function: the C-API bench, which has no such state, reads 0.72-0.77 in every row, and a perf profile of the nqp bench at 65 (below) shows the same functions on both builds.

### perf record -g (user space), top 15 symbols, --no-children

Commands (`internals-set0-inv-scripts/s2p.sh`): `LD_LIBRARY_PATH=<prefix>/lib perf record -g -- nqp-m tools/bench/hash-bench.nqp --sizes=65 --runs=20 --nth=threshold` per prefix; the same with `--sizes=4,16,32,63,64,65 --runs=20 --nth=all` (the closest shape to the artifact that fits a perf run); and `<prefix>/bin/hash-bench --sizes=65 --runs=20` for the C-API. The prefixes' libmoar is stripped, so most library functions print as their exported name and the rest as bare addresses; hex rows are libmoar internals.

nqp65 base:
```
    13.50%  [.] MVM_interp_run
     7.25%  [.] MVM_spesh_inline
     3.96%  [.] MVM_disp_program_run
     3.66%  [.] MVMHash_bind_key
     3.21%  [.] MVM_str_hash_fetch
     2.19%  [.] MVM_str_hash_delete
     1.65%  [.] MVM_repr_at_pos_o
     1.47%  [.] 0x00000000008e66fa
     1.40%  [.] MVM_VMArray_at_pos
     0.92%  [.] MVM_spesh_stats_update
     0.92%  [.] MVM_args_set_result_int
     0.89%  [.] MVM_frame_dispatch
     0.88%  [.] MVM_repr_shift_o
     0.79%  [.] 0x00000000008e10a6
     0.73%  [.] MVM_iterkey_s
```

nqp65 head:
```
    15.06%  [.] MVM_interp_run
     5.04%  [.] MVM_spesh_inline
     4.24%  [.] MVM_str_hash_fetch
     4.19%  [.] MVM_str_hash_delete
     4.13%  [.] MVM_disp_program_run
     3.61%  [.] MVMHash_bind_key
     1.80%  [.] 0x00000000008e720a
     1.76%  [.] MVM_VMArray_at_pos
     1.73%  [.] MVM_repr_at_pos_o
     1.24%  [.] MVM_spesh_stats_update
     1.07%  [.] MVM_frame_dispatch
     1.06%  [.] 0x00000000008e1bb6
     1.06%  [.] MVM_args_set_dispatch_result_obj
     0.95%  [.] 0x00000000007c2f71
     0.82%  [.] MVM_args_set_result_int
```

nqpseq base:
```
    18.94%  [.] MVM_interp_run
     5.54%  [.] MVMHash_bind_key
     5.42%  [.] MVM_str_hash_delete
     5.07%  [.] MVM_str_hash_fetch
     3.03%  [.] MVM_disp_program_run
     2.90%  [.] MVM_repr_at_pos_o
     2.22%  [.] MVM_VMArray_at_pos
     2.22%  [.] MVM_spesh_inline
     1.59%  [.] MVM_args_set_result_int
     1.54%  [.] MVM_iterkey_s
     1.24%  [.] __tls_get_addr
     1.16%  [.] MVM_repr_bind_key_o
     0.98%  [.] mi_free
     0.97%  [.] MVM_str_hash_demolish
     0.89%  [.] MVM_repr_shift_o
```

nqpseq head:
```
    18.90%  [.] MVM_interp_run
     5.58%  [.] MVM_str_hash_delete
     5.17%  [.] MVM_str_hash_fetch
     4.68%  [.] MVMHash_bind_key
     3.71%  [.] MVM_disp_program_run
     2.82%  [.] MVM_repr_at_pos_o
     2.24%  [.] MVM_spesh_inline
     2.22%  [.] MVM_VMArray_at_pos
     1.52%  [.] MVM_iterkey_s
     1.35%  [.] MVM_repr_bind_key_o
     1.31%  [.] MVM_repr_shift_o
     1.12%  [.] MVM_args_set_result_int
     1.10%  [.] mi_free
     1.06%  [.] __tls_get_addr
     1.05%  [.] MVM_str_hash_demolish
```

capi65 base:
```
    16.06%  [.] MVM_str_hash_fetch_nocheck
     9.18%  [.] MVM_str_hash_delete_nocheck
     5.61%  [.] MVM_str_hash_next_nocheck
     5.27%  [.] bench.main
     2.34%  [.] __tls_get_addr
     2.02%  [.] mi_free
     1.88%  [.] MVM_str_hash_current_nocheck
     1.67%  [.] 0x00000000007c1b3e
     1.62%  [.] 0x00000000007c0bd8
     1.60%  [.] bench_str_at_end
     1.52%  [.] 0x00000000007c0d5e
     1.50%  [.] bench_str_current_nocheck
     1.42%  [.] MVM_str_hash_lvalue_fetch_nocheck
     1.37%  [.] 0x00000000007c0ef0
     1.31%  [.] 0x00000000007991b9
```

capi65 head:
```
     7.23%  [.] MVM_str_hash_fetch_nocheck
     6.45%  [.] MVM_str_hash_fetch_nocheck
     5.85%  [.] MVM_str_hash_delete_nocheck
     4.50%  [.] MVM_str_hash_next_nocheck
     3.75%  [.] bench.main
     3.65%  [.] MVM_str_hash_delete_nocheck
     3.31%  [.] MVM_str_hash_next_nocheck
     2.88%  [.] mi_free
     2.76%  [.] 0x00000000007c1ff1
     2.37%  [.] 0x00000000007c1fcd
     2.21%  [.] 0x00000000007c202a
     2.14%  [.] 0x00000000007c1fd4
     1.89%  [.] 0x0000000000799467
     1.68%  [.] MVM_string_substrings_equal_nocheck
     1.52%  [.] 0x00000000007c2001
```

Per-cell timings of those runs (ns per op, 65 entries): nqp --sizes=65: hit base 13.47 / head 12.29, miss 13.22 / 11.00; nqp sequence with nth=all and no larger size: hit 13.41 / 12.49, miss 13.44 / 10.07; capi: hit 7.87 / 6.41, miss 8.26 / 4.91 (internals-set0-inv-perf-*.out).

What differs: (1) The nqp path reaches the checked entry `MVM_str_hash_fetch` (MVMHash.c `exists_key`/`at_key` call it: `checkKey` then the inlined lookup) and `MVM_str_hash_delete`; the C-API bench calls `MVM_str_hash_fetch_nocheck`/`_delete_nocheck`, the same lookup without the key validation and without the interpreter around it. The head's C-API profile splits `fetch_nocheck` into two symbols (7.23 + 6.45 percent), the base's has one (16.06): the LTO duplicated the Swiss lookup into two partitions (hot loop and a tail), the sum 13.7 percent against 16.1. (2) In the nqp profiles the engine functions are 3-5 percent of the process, as in the C-API they are 35-40; the interpreter (`MVM_interp_run`, `MVM_disp_program_run`, spesh inlining) is the rest, and it is the same on both builds. (3) No symbol appears on one build only apart from the LTO partitioning above. The percentages are shares of a whole process (startup and compile included), so `MVM_str_hash_fetch` at 4.24 (head) against 3.21 (base) percent and `MVM_str_hash_delete` at 4.19 against 2.19 are not per-op costs; the per-op timings printed by the same runs (above) give the head the faster hit and miss cells. Nothing in the profiles explains a slower hit; the 1.26 cell is the harness artifact above.

## Step 3: which spectest files lose

Source: the four Step 1 runs (the harness's per-file timer, mean of two runs per side; `internals-set0-inv-spectest-{1-base,2-head,3-head,4-base}.log`, table by `internals-set0-inv-scripts/perfile.py`, full output `internals-set0-inv-perfile.md`). Per-file wall is under 24-way contention, so it runs about 2.2 times the solo time (sprintf-f 75-84 s here, 34-39 s alone). The two-run spread columns show the noise: per-file base-vs-base differences sum to 268 s over 1365 files against a summed head-minus-base delta of 74 s, so single mid-table rows are not readable; the aggregate and the long files are. (The harness's cusr/csys columns are cumulative over the parallel children and were not used.)

files 1365: sum of per-file wall deltas 74278 ms (base sum of walls 5120374 ms)
sum |base1-base2| 268023 ms, sum |head1-head2| 259902 ms

Top 20 by wall delta (mean of 2 runs per side)
| file | base ms | head ms | delta ms | ratio | base spread ms | head spread ms |
|---|---:|---:|---:|---:|---:|---:|
| t/spec/S32-str/sprintf-f.t | 74634 | 83770 | +9136 | 1.12 | 195 | 653 |
| t/spec/S32-str/sprintf-b.t | 94734 | 103551 | +8816 | 1.09 | 2123 | 1740 |
| t/spec/S32-str/sprintf-x.t | 96192 | 104037 | +7845 | 1.08 | 1960 | 126 |
| t/spec/S32-str/sprintf-e.t | 62944 | 67734 | +4790 | 1.08 | 814 | 1654 |
| t/spec/S17-supply/batch.t | 39172 | 42657 | +3486 | 1.09 | 1127 | 478 |
| t/spec/S32-str/sprintf-a.t | 38340 | 41446 | +3106 | 1.08 | 841 | 1220 |
| t/spec/S32-str/sprintf-c.t | 23334 | 25224 | +1890 | 1.08 | 1175 | 336 |
| t/spec/S06-operator-overloading/infix.rakudo.moar | 49836 | 51475 | +1640 | 1.03 | 2443 | 1008 |
| t/spec/6.c/APPENDICES/A03-older-specs/01-misc.rakudo.moar | 18864 | 20358 | +1494 | 1.08 | 171 | 223 |
| t/spec/S32-str/sprintf-u.t | 17216 | 18624 | +1408 | 1.08 | 467 | 434 |
| t/spec/S32-str/val.t | 17365 | 18752 | +1386 | 1.08 | 704 | 487 |
| t/spec/S32-exceptions/misc.rakudo.moar | 35589 | 36846 | +1257 | 1.04 | 512 | 1192 |
| t/spec/S10-packages/precompilation.t | 80444 | 81670 | +1226 | 1.02 | 12 | 415 |
| t/spec/S03-metaops/hyper.rakudo.moar | 23146 | 24364 | +1218 | 1.05 | 100 | 1184 |
| t/spec/S17-procasync/no-runaway-file-limit.t | 39852 | 41011 | +1160 | 1.03 | 1919 | 74 |
| t/spec/S03-junctions/misc.t | 14190 | 15334 | +1144 | 1.08 | 543 | 472 |
| t/spec/S04-declarations/my-6e.rakudo.moar | 5656 | 6746 | +1090 | 1.19 | 96 | 1810 |
| t/spec/6.c/MISC/bug-coverage.t | 16346 | 17388 | +1042 | 1.06 | 940 | 437 |
| t/spec/S32-str/sprintf-d.t | 49540 | 50552 | +1012 | 1.02 | 227 | 516 |
| t/spec/S04-exception-handlers/catch.t | 17666 | 18661 | +996 | 1.06 | 373 | 238 |
sum of top-20 deltas 55140 ms of total 74278

Top 20 by ratio (base >= 500 ms)
| file | base ms | head ms | delta ms | ratio | base spread ms | head spread ms |
|---|---:|---:|---:|---:|---:|---:|
| t/spec/S07-iterationbuffer/iterationbuffer.t | 1130 | 1500 | +370 | 1.33 | 29 | 251 |
| t/spec/S02-lexical-conventions/unicode-whitespace.t | 2706 | 3546 | +840 | 1.31 | 193 | 269 |
| t/spec/S03-operators/orelse.t | 1168 | 1525 | +358 | 1.31 | 97 | 450 |
| t/spec/S32-str/tclc.t | 710 | 924 | +215 | 1.30 | 69 | 167 |
| t/spec/S32-str/lc.t | 1082 | 1398 | +316 | 1.29 | 88 | 56 |
| t/spec/S02-magicals/GROUP.t | 1097 | 1410 | +313 | 1.29 | 346 | 174 |
| t/spec/S14-roles/composition.t | 3362 | 4292 | +930 | 1.28 | 280 | 32 |
| t/spec/S03-smartmatch/array-hash.t | 950 | 1208 | +258 | 1.27 | 14 | 36 |
| t/spec/S03-smartmatch/00-sanity.t | 1744 | 2216 | +472 | 1.27 | 348 | 185 |
| t/spec/S12-meta/primitives.t | 1580 | 1954 | +374 | 1.24 | 105 | 116 |
| t/spec/S12-methods/chaining.t | 1216 | 1490 | +275 | 1.23 | 135 | 35 |
| t/spec/S03-metaops/eager-hyper.t | 1182 | 1450 | +268 | 1.23 | 309 | 158 |
| t/spec/S04-statements/quietly.t | 2760 | 3358 | +598 | 1.22 | 552 | 75 |
| t/spec/S03-operators/spaceship-and-containers.t | 1038 | 1255 | +216 | 1.21 | 265 | 154 |
| t/spec/S02-types/hyperwhatever.t | 997 | 1196 | +200 | 1.20 | 0 | 87 |
| t/spec/S04-phasers/init.t | 1144 | 1371 | +226 | 1.20 | 193 | 106 |
| t/spec/S02-literals/listquote.rakudo.moar | 1574 | 1877 | +304 | 1.19 | 67 | 358 |
| t/spec/S04-declarations/my-6e.rakudo.moar | 5656 | 6746 | +1090 | 1.19 | 96 | 1810 |
| t/spec/integration/advent2013-day20.t | 1352 | 1612 | +260 | 1.19 | 25 | 141 |
| t/spec/S09-subscript/multidim-assignment.t | 1463 | 1744 | +281 | 1.19 | 104 | 262 |
sum of top-20 ratio deltas 8164 ms


positive deltas sum 152792, negative -78514, files slower 739

Reading: 739 of 1365 files are slower, the positive deltas sum to +152.8 s and the negative to -78.5 s, net +74.3 s (1.45 percent of the summed file walls, which is the contention-weighted version of the 3.1 percent wall: the run is bounded by its longest files, and those are the losers). The 20 largest deltas sum to 55.1 s of the 74.3 s (74 percent); seven of the top ten are the S32-str/sprintf-* files, four of which (x, b, f, e) are among the eight slowest files of the suite (the slowest, S15-normalization/nfc-concat.t at 198 s, is unchanged: 197.9 vs 198.6 s). The one non-sprintf file among the top five, S17-supply/batch.t (+3.5 s, 1.09), was not profiled. The 20 largest ratios (base at least 0.5 s) are all short files (1-5 s, ratios 1.19-1.33) whose two-run spreads are as large as their deltas, and they sum to 8.2 s; they are noise-dominated.

### perf of the top 3 files (sprintf-f, sprintf-b, sprintf-x), solo, one process

Solo wall and peak RSS (`internals-set0-inv-solo-*.time`, `-solo-summary.log`; order base head head base per file, `RAKULIB=lib ./rakudo-m t/spec/S32-str/<f>.t`, load 0.97-1.13):

| file | base s (2 runs) | head s (2 runs) | ratio | base RSS kB | head RSS kB |
|---|---|---|---:|---|---|
| sprintf-f | 34.37, 33.86 | 38.42, 39.31 | 1.14 | 428676, 430940 | 422524, 420380 |
| sprintf-b | 54.50, 55.50 | 58.11, 57.72 | 1.05 | 454460, 451388 | 454604, 450872 |
| sprintf-x | 56.28, 54.02 | 59.06, 59.75 | 1.08 | 458336, 456132 | 449460, 446180 |

A second interleaved set with three builds (`-preflip-summary.log`, order base, pre-flip, head, three rounds): sprintf-f base 34.54 / 34.73 / 33.69, pre-flip 33.87 / 34.67 / 34.54, head 40.38 / 38.22 / 39.23; sprintf-x base 54.09 / 53.66 / 53.13, pre-flip 54.56 / 53.83 / 56.20, head 59.91 / 59.59 / 60.40. The pre-flip build (Small then Robin Hood, all other campaign changes in) equals the base; the flip is what costs 10-14 percent here.

perf record -F 499 -g per file and build (raw: `internals-set0-inv-solo-sprintf-{f,b,x}-{base,head}.top80`, first 80 symbol rows; the stripped libmoar leaves bare addresses). Shares by symbol family, percent of samples (hash = `MVM_str_hash_*`, `MVM_string_compute_hash_code`, `*_hash_*`; gc = `MVM_gc_*`; disp = `MVM_frame_dispatch`, `MVM_disp_*`; hex = libmoar internals with no name):

| file | build | hash | gc (named) | interp | disp | spesh | callstack | hex rows |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| sprintf-f | base | 2.21 | 3.43 | 6.33 | 18.27 | 5.97 | 1.53 | 60.46 |
| sprintf-f | head | 2.17 | 3.34 | 6.38 | 18.67 | 6.19 | 1.66 | 62.41 |
| sprintf-b | base | 2.29 | 3.44 | 6.58 | 18.17 | 5.45 | 1.70 | 31.99 |
| sprintf-b | head | 2.34 | 3.48 | 6.27 | 18.48 | 5.27 | 1.81 | 33.32 |
| sprintf-x | base | 2.29 | 3.31 | 6.01 | 17.87 | 5.45 | 1.66 | 32.40 |
| sprintf-x | head | 2.45 | 3.30 | 6.80 | 18.34 | 5.42 | 1.66 | 33.82 |

(Columns sum over the 15-25 symbols in each file's first rows, so they are lower bounds; the top-80 lists are in the raw files.) The hash engine is 2.2-2.5 percent of samples on both builds. With the head's wall 5-14 percent longer, the hash family's absolute time rises by about 0.1 s of sprintf-f's extra 4.8 s.

Symbolised run (`-Dstrip=false` builds of both trees, sprintf-f, perf -F 999; `internals-set0-inv-sym-f-{base,head}.syms`, `.dso`): 34,218 samples (base) against 38,499 (head), +4,281; by symbol the largest increases are `MVM_disp_program_run` +333, `MVM_spesh_arg_guard_run` +314, `compiler_rt.memset` +311, `MVM_interp_run` +301, `MVM_frame_dispatch` +262, `MVM_6model_try_cache_type_check` +193, then `MVM_str_hash_fetch` +105 (518 to 623), `go_to_first_inline` +101, `dispatch_polymorphic` +80 ...; the hash-family symbols together are +97 of the +4,281 (2.3 percent), the GC family +184 (4.3 percent), the JIT-compiled code region +863 samples (6,116 to 6,979, +14 percent). The whole profile is about 12 percent heavier, symbol by symbol, in code that does not touch a hash. `core.hash.table.Table(StrSpec).lvalue` disappears (-57: inlined elsewhere by the LTO in the head).

## Step 4: memory

Peak RSS per build: Step 1 (whole spectest) base 1025136 / 1026560 kB, head 1023324 / 1020988 kB: 0.996. Solo top 3 files (table in Step 3): head equals or is below base on sprintf-f (422.5 / 420.4 against 428.7 / 430.9 MB) and sprintf-x (449.5 / 446.2 against 458.3 / 456.1) and equal on sprintf-b (454.6 / 450.9 against 454.5 / 451.4). Task 9b's +1.5 percent (about 10 MB) does not reproduce.

Block sizes, from `swiss.zig`/`robinhood.zig` (entry 16 bytes: key and value; control block 32 bytes; Swiss block = 32 + slots + 16 x slots, load limit 7/8, so 65-112 entries sit in 128 slots, 113-224 in 256, 225-448 in 512; Robin Hood block = 16 x (official + probe limit - 1) + 32 + round8(allocated + 1), load limit 3/4; the 65-entry values 3824 and 2208 bytes are the `hash-bench` RSS column of the perf runs above, so the formulas are checked against the built engines):

| entries | RH slots-block bytes | Swiss bytes | Swiss/RH |
|---:|---:|---:|---:|
| 65 | 3824 | 2208 | 0.58 |
| 80 | 3824 | 2208 | 0.58 |
| 96 | 3824 | 2208 | 0.58 |
| 97 | 7632 | 2208 | 0.29 |
| 112 | 7632 | 2208 | 0.29 |
| 113 | 7632 | 4384 | 0.57 |
| 128 | 7632 | 4384 | 0.57 |
| 129 | 7632 | 4384 | 0.57 |
| 192 | 7632 | 4384 | 0.57 |
| 193 | 13056 | 4384 | 0.34 |
| 224 | 13056 | 4384 | 0.34 |
| 225 | 13056 | 8736 | 0.67 |
| 256 | 13056 | 8736 | 0.67 |
| 384 | 13056 | 8736 | 0.67 |
| 385 | 21760 | 8736 | 0.40 |
| 448 | 21760 | 8736 | 0.40 |
| 449 | 21760 | 17440 | 0.80 |
| 1024 | 39168 | 34848 | 0.89 |
| 16384 | 561408 | 557088 | 0.99 |

Weighted by Task 5's W3 survey for s5 (`internals-survey-w3-report.md`: demolished tables at 65 / 66-128 / 129-256 / 257-1024 / 1025-16384 entries = 213 / 80,532 / 4,686 / 3,574 / 6 over the whole spectest; sizes within a bin sampled at its listed points):

| bin | tables demolished (W3) | RH bytes/table range | Swiss bytes/table range | total RH | total Swiss (mid-range sample, mean over sample sizes) |
|---|---:|---|---|---:|---:|
| 65 | 213 | 3824-3824 | 2208-2208 | 0.8 MB | 0.5 MB |
| 66-128 | 80532 | 3824-7632 | 2208-4384 | 430.6 MB | 212.9 MB |
| 129-256 | 4686 | 7632-13056 | 4384-8736 | 44.2 MB | 27.3 MB |
| 257-1024 | 3574 | 13056-39168 | 8736-34848 | 88.1 MB | 72.7 MB |
| 1025-16384 | 6 | 73984-561408 | 69664-557088 | 1.9 MB | 1.9 MB |

Cumulative bytes allocated by final-size blocks over the whole spectest: RH 565.7 MB, Swiss 315.3 MB

So the head's tables are smaller than the base's in every bin from 65 up (0.29-0.67 at 65-448 entries, 0.80-0.99 above) and identical below, by 250 MB of cumulative allocation over the whole spectest (this is bytes allocated over the suite, not live at once). Blocks cannot explain a higher RSS; the implied RSS delta is negative. Also in the sprintf-f stats run the 66-128-entry tables demolished are 7,987 (pre-flip) against 9,414 (head): +17.9 percent, the same factor as every other count (Step 5, work table), i.e. more tables of that size are built because the program builds more of everything, not because the head builds them larger.

## Step 5: what the extra work is, diagnosis, recommendation

### Instruction counts: the head runs more program, not slower hash operations

`perf stat` (user space, `internals-set0-inv-perfstat-*.csv`), `rakudo-m t/spec/S32-str/sprintf-f.t`, solo, two runs per build, builds interleaved:

| build | instructions G | cycles G | IPC | branch-miss G | L1d-miss G | cache-miss G | dTLB-miss M | task-clock s |
|---|---|---|---|---|---|---|---|---|
| base 1478311f6 | 216.06, 218.27 | 165.36, 171.87 | 1.31, 1.27 | 1.21, 1.23 | 5.16, 5.21 | 3.15, 3.18 | 26.8, 28.7 | 34.9, 36.3 |
| pre-flip 6bbd4612e | 216.52, 216.48 | 166.59, 167.37 | 1.30, 1.29 | 1.23, 1.24 | 5.20, 5.19 | 3.24, 3.20 | 25.0, 25.1 | 35.2, 35.4 |
| head 0b581f32e | 242.58, 246.93 | 187.37, 189.23 | 1.29, 1.31 | 1.38, 1.41 | 5.84, 5.92 | 3.63, 3.64 | 30.5, 30.9 | 39.6, 40.0 |

Every counter rises 12-17 percent together and the IPC does not move: the head executes more instructions, it does not execute them worse (no cache, TLB or branch effect that is out of proportion). Narrowing it down (`internals-set0-inv-stat2-env-nospesh.txt`, `-stat3-micro.txt`, `-stat4-compile.txt`, `-stat5-micro.txt`; user instructions, G):

| probe | base or pre-flip | head | note |
|---|---|---|---|
| `-e 'say 1'` (startup) | 0.997 (base), 0.997 (pre-flip) | 0.995 | equal |
| `--target=parse` / `--target=optimize` of sprintf-f.t (the compile phase) | 5.225 / 5.244 | 5.250 / 5.190 | equal |
| five micro-workloads (6000 sprintf, 3000 is-deeply sprintf, 3000 ok, 300 subtests, 3000 permutations) | 2.23-4.43 | 2.25-4.44 | equal within 1 percent |
| whole sprintf-f.t, default | 216.1-218.3 | 242.6-246.9 | +12-14 percent, so the extra work is in the run phase of this test file |
| whole sprintf-f.t, `MVM_SPESH_DISABLE=1` | 377.1 | 435.7 | +15.5 percent: not a specialisation decision |
| whole sprintf-f.t, `MVM_HASH_STRATEGY=1` (all hashes bare Swiss) | 249.7 (pre-flip) | 248.0 | both at the head's level |
| whole sprintf-f.t, `MVM_HASH_STRATEGY=2` (all hashes append-ordered) | 249.9 (pre-flip) | 249.9 | both at the head's level |

The test output is byte-identical between the builds (sprintf-c.t, 8,953 lines compared), and the test is deterministic, so the run executes the same Raku statements; the difference is in how much MoarVM-level work some of them cost.

The statistics build (`-Dhash-stats=true`, `internals-set0-inv-stats-{preflip,head}-report.md`; 220.5 G against 254.1 G instructions, the same +15 percent) counts every hash operation in that run:

| site and op | pre-flip | head | head/pre-flip |
|---|---:|---:|---:|
| s5 MVMHash build | 940,330 | 1,099,125 | 1.169 |
| s5 insert | 3,315,921 | 3,856,064 | 1.163 |
| s5 overwrite | 437,246 | 501,267 | 1.146 |
| s5 fetch_hit | 27,713,269 | 32,074,233 | 1.157 |
| s5 fetch_miss | 6,486,974 | 7,477,189 | 1.153 |
| s5 iter_step | 4,262,868 | 4,874,198 | 1.143 |
| s5 grow | 150,751 | 176,518 | 1.171 |
| s5 tables demolished at 66-128 entries | 7,987 | 9,414 | 1.179 |
| i2 build (frames finished) | 8,810 | 10,283 | 1.167 |
| i2 fetch_hit | 4,210,549 | 4,840,752 | 1.150 |
| p1 object-id insert | 788,128 | 915,850 | 1.162 |
| s6 deserialize fetch_hit | 125,951 | 148,450 | 1.179 |

Cycles per op (stats build, rdtsc, solo): s5 fetch_hit 88.6 (pre-flip) against 86.9 (head), fetch_miss 77.8 / 76.0, insert 252.9 / 238.7, migrate 4,504 / 2,943, grow 323 / 334. 45.7 percent of s5 fetches are on tables of 65 or more entries on both builds (53.0 vs 54.7 percent of fetch cycles), and hash cycles are 3.9 percent of all cycles in both. Counts and instructions grow together; per-op engine cost does not grow.

### Diagnosis

What the data supports. (1) The loss is real: 3.1 percent of spectest wall on four interleaved runs, 5-14 percent on the long CPU-bound sprintf files, disjoint spreads, RSS not worse. (2) It comes from the flip itself: the pre-flip build equals the base, so neither the 22 other commits nor the build/layout noise of a rebuild account for it. (3) It is not a slower hash operation: per-op cycles in the stats build are equal or lower on the head, the engine symbols are 2.2-2.5 percent of samples on both builds, every counter rises together at constant IPC, and the A/B ladder shows the head faster above 64 entries. (4) It is not memory: the head's blocks are smaller from 65 entries up and RSS is equal. (5) It is not the Small rung, GC, specialisation or the compile phase: Small is unchanged by the flip, the named GC symbols grow 7 percent against 12 overall (4 percent of the extra samples), `MVM_SPESH_DISABLE=1` leaves the gap at 15.5 percent, and compile and startup instruction counts are equal. (6) What changes is the amount of work the run phase of this test file does: every hash-operation count and every instruction counter is 12-18 percent higher on the head, including operations on frames, object ids and deserialised hashes that the engine does not influence, and the test output is identical. What the data does not show: which work. The only variable the flip changes for the program is the iteration order (and the placement) of hashes of 65 or more entries, and the env-override probes land at the head's level for both Swiss and append order, away from the Robin Hood level; that fits an order-dependent code path in rakudo or nqp (something that scans a large hash and stops at a first match, or picks a victim, or sorts ties by iteration order) but it does not prove one, and the run-to-run variation of the head (242.6 and 246.9 G against 216.5 and 216.5 G) fits a per-table random Swiss salt where Robin Hood order is repeatable. The nqp lookup_hit-at-65 loss (1.26) is a separate, harness-state artifact (Step 2) and does not bear on the spectest.

### Recommendation

**Recommendation: revert the flip** (set 0 back to Small then Robin Hood; keep Swiss as LOOKUP and as the `large_only`/uni rung, keep the four new str tests and the Small-to-Robin-Hood migration test, which already pins the old ladder as `standard_rh_test_set`). Reasons: the flip buys no end-to-end win (the engine is 3.9 percent of cycles and 65-and-up tables are a small share of the operations, so even the measured 0.7-0.9 ladder ratios cannot move the suite by more than a fraction of a percent), it costs 3.1 percent of spectest wall through a mechanism this investigation could not isolate, and the user's gate (not slower beyond spread) fails. A fix-then-remeasure is not nameable from this data: there is no engine function to change. If the user wants the cause chased before the revert, the next measurement is to find the ≥65-entry hash whose order matters: on the head, run sprintf-f.t under a diagnostic build where `MVMHash` iteration of tables over 64 entries is logged by site (the stats build already has per-site table-size histograms: s5 is the site), then replay with that table's order forced to the Robin Hood order; one build and one solo run per order. That is a research task, not a prerequisite for the revert.
