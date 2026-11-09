# ngc Task 2: profile before; collector share of the cycle gap 0.21 plain (bad: not resolvable at this volume): under a quarter, the stop rule fires

```
ngc profile record (Task 2, spec 7)
Date:          2026-11-09, 10:28-10:52 CET (builds 10:28-10:33, profile 10:34:26-10:43:09, .text A/B 10:43:09-10:51:45)
MoarVM:        zig-native-gc at e20b27af9 ("traces: ngc controls"; src identical to f0582f365, where the -base prefixes
               were built); traces fe2c335 before this record; version line 2026.09-271-ge20b27af9 (68 characters, the
               same length as the -base prefixes' 2026.09-270-gf0582f365)
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8; perf 7.2.9, perf_event_paranoid 2 (every event :u)
Pair:          ng-c-syms (C collector + Zig hash engine, -Dzig-gc=false -Dstrip=false) against ng-f-syms (faithful Zig
               port, -Dstrip=false); attribution pass ng-c-nlto / ng-f-nlto (-Dlto=false -Dstrip=false, -Dzig-gc=false
               on the c side); otherwise defaults (ReleaseFast, x86-64-v3, -Dgc-debug=0, nursery 16 MiB); 2850 exported
               names in all four
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (execs /tmp/claude-1000/tune-zig-prefix/bin/moar,
               libmoar from LD_LIBRARY_PATH); nqp 41e7210ba; RAKULIB tools/bench/gc/lib plus the rakudo lib/
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Program:       tools/bench/gc/crc-getter.raku --volume=100000 --runs=5 [--bad-packages], spesh and precompilation on
Script:        tools/bench/gc/profile.sh as committed in b5f7e6894 ("Bench: perf profile runner for the GC A/B")
Commands:      tools/bench/gc/profile.sh --lib=<P>/lib --out=<dir> --stat-runs=5 [--record] [--bad-packages], each under
               systemd-run --user --scope -q -p MemoryMax=8G, from ngc-profile-driver.sh: per setting the rounds
               c f / f c / c f (three invocations per side, five perf stat runs each), --record in round 1; then
               --stat-runs=0 --record on ng-c-nlto, ng-f-nlto (plain); then ab.sh --rounds=3 --runs=5 --volume=100000
               of each -syms against its -base
Load:          1-minute load before every run (load.log per invocation): profile 0.29-1.31, .text A/B 1.07-1.75
Raw:           ngc-profile-raw/: build4.sh, builds.tsv, text-compare.txt, {plain,bad}/{c,f}-r{1,2,3}/ (stat-<n>.csv,
               stat.tsv, load.log; report.txt in r1), nlto/{c,f}/ (report.txt, load.log), textab-{c,f}/ (summary.md,
               load.log), driver.log, c-gc-statics.txt, analyze.pl and its full output analysis-output.md (top-40 and
               delta tables of all three passes), hot-spots.txt (perf annotate and objdump excerpts). perf.data files
               are not kept (/tmp/claude-1000/ngc/profile/). All 60 counted runs, 6 sampled runs and 2 nlto runs printed
               "RUN 5".
```

## Builds

| prefix | options | exit | seconds | load before |
|---|---|---:|---:|---:|
| ng-c-syms | -Dzig-gc=false -Dstrip=false | 0 | 67 | 0.05 |
| ng-f-syms | -Dstrip=false | 0 | 59 | 1.23 |
| ng-c-nlto | -Dzig-gc=false -Dlto=false -Dstrip=false | 0 | 22 | 1.29 |
| ng-f-nlto | -Dlto=false -Dstrip=false | 0 | 11 | 1.46 |

Same recipe as ngc-prefixes-raw/build9.sh (`rm -f src/gen/config.{h,c,o}`, `zig build install --prefix ...`, load
< 2.0, MemoryMax=8G); all four print "This is MoarVM version 2026.09-271-ge20b27af9 built with JIT support".
Smoke of the script: `sh -n` clean, `--help` exit 0, unknown argument / missing lib / `--stat-runs=0` without
`--record` exit 64; `--stat-runs=1` on ng-c-syms wrote stat.tsv (cycles:u 35729838579), `--stat-runs=0 --record`
wrote report.txt (30K samples).

## The .text of -syms against -base (spec 7): different; profiled anyway

`objcopy -O binary --only-section=.text` and `cmp` (text-compare.txt): **both pairs differ**, at byte 4.

| prefix | .text bytes | .rodata bytes |
|---|---:|---:|
| ng-c-base | 2392021 | 5194684 |
| ng-c-syms | 2657221 | 5212348 |
| ng-f-base | 2392517 | 5194684 |
| ng-f-syms | 2657717 | 5212412 |

Both -syms builds carry 265200 more bytes of .text, the same amount on both sides: with `-Dstrip=false` the Zig
object keeps Zig's stack-trace machinery (`debug.writeCurrentStackTrace`, `debug.printSourceAtAddress`, `Io.*`,
`fmt.*`; 248 `std`-family functions, 241933 bytes in ng-c-syms), which shifts every later address. The exported
functions are the same code: of the 2850 `nm -D -S` sizes, 2848 are equal and two (`MVM_index_hash_build`,
`s_mp_toom_mul`) are 4 bytes shorter in -syms, on both sides alike (alignment-dependent encodings).

Spec 7's fallback, a three-round crc-getter A/B of each -syms against its -base (textab-{c,f}/summary.md):

| pair | -base wall s | -syms wall s | ratio wall | ratio RSS | within spread |
|---|---:|---:|---:|---:|---|
| ng-c | 7.47 [7.42-7.48] | 7.36 [7.35-7.41] | 0.985 | 0.987 | **no**: the ranges do not overlap; ng-c-syms is 1.5 % faster |
| ng-f | 7.66 [7.63-7.72] | 7.68 [7.65-7.80] | 1.003 | 0.994 | yes |

So, per spec 7, **the C side of this profile is labelled as taken on a different binary**: ng-c-syms runs 1.5 %
faster than the shipped ng-c-base, ng-f-syms like ng-f-base. The profiled pair's gap is correspondingly wider than
the shipped one: wall f-syms/c-syms 7.68/7.36 = 1.043 here (cycles:u 1.042 below) against 1.028 for -base/-base in
ngc-baseline-crc.md. A 1.5 % move from code placement alone is itself a finding: it is half the shipped gap.

## Counters (perf stat, medians)

Cells: median of the three round medians [min-max of the round medians]; each round median over 5 runs (15 runs
per side and setting). Last two columns: min-max over all 15 runs.

### plain

| event | c (ng-c-syms) | f (ng-f-syms) | f/c | c 15 runs | f 15 runs |
|---|---:|---:|---:|---:|---:|
| cycles:u | 35527891606 [35383237665-35547590081] | 37017096437 [36954975837-37396141875] | 1.0419 | 35091686431-35924225030 | 36650070950-37757010672 |
| instructions:u | 68896244986 [68893561275-68904054451] | 69589523829 [69441335107-69598735286] | 1.0101 | 68577836258-69050522172 | 69172737403-69610710303 |
| branch-misses:u | 48565860 [48413195-49060819] | 48889564 [48753481-49053814] | 1.0067 | 46906373-51672144 | 47482757-50838344 |
| cache-misses:u | 130289415 [130047785-130502899] | 129059552 [127474634-133052907] | 0.9906 | 124022356-165027884 | 119043370-151321078 |
| L1-dcache-load-misses:u | 1104520995 [1101542045-1109093013] | 1110353175 [1102865693-1121737351] | 1.0053 | 1070574168-1148755756 | 1090693699-1305234797 |

### --bad-packages

| event | c (ng-c-syms) | f (ng-f-syms) | f/c | c 15 runs | f 15 runs |
|---|---:|---:|---:|---:|---:|
| cycles:u | 37803121150 [37738629592-37948962299] | 39618532654 [39491249122-40420980136] | 1.0480 | 37324957502-38369092038 | 38805290827-41147179487 |
| instructions:u | 70926799873 [70920235611-70931510683] | 71610845585 [71596328139-71620286675] | 1.0096 | 70582119383-70963778112 | 71287560904-71634793621 |
| branch-misses:u | 52039725 [51700001-52633260] | 51859961 [51549248-52990080] | 0.9965 | 50244570-53904772 | 50431124-56509079 |
| cache-misses:u | 155453085 [150726035-157073643] | 154810461 [149640893-155765258] | 0.9959 | 141617735-168209773 | 142817144-171130480 |
| L1-dcache-load-misses:u | 1214248850 [1214204730-1225048914] | 1212195310 [1206065066-1243476246] | 0.9983 | 1191443540-1296409463 | 1189000511-1302710322 |

The f side executes 1.0 % more instructions and takes 4.2 % (plain) / 4.8 % (bad) more cycles; branch, cache and
L1 misses are within noise of each other (cache-misses f/c 0.99 plain, 1.00 bad). The extra cycles are not
explained by misses counted here; the per-symbol view below finds a stall instruction.

## Samples, LTO (the -syms binaries), plain: top 40 per side

`perf record -e cycles:u -F 4000`, one run per side and setting (round 1); `perf report --sort dso,symbol -n`.
Every per-symbol share and delta in this record rests on that one sampled run per side and setting, scaled by
the stat medians.
Share % is perf's period-weighted overhead. JIT-compiled code (`[JIT] tid N`, one row per address in report.txt)
and libc addresses without symbols are merged into one row per dso here. The --bad-packages and non-LTO top-40
tables are in ngc-profile-raw/analysis-output.md.

### top 40, c

| # | share % | samples | dso | symbol |
|---:|---:|---:|---|---|
| 1 | 26.57 | 8494 | [JIT] | (unresolved) |
| 2 | 9.49 | 2881 | libmoar.so | compiler_rt.fastMemset |
| 3 | 5.84 | 1758 | libmoar.so | MVM_frame_dispatch |
| 4 | 3.37 | 1014 | libmoar.so | MVM_bigint_xor |
| 5 | 3.35 | 1037 | libc.so.6 | (unresolved) |
| 6 | 2.50 | 755 | libmoar.so | gc_free.2630 |
| 7 | 2.39 | 721 | libmoar.so | MVM_spesh_arg_guard_run |
| 8 | 2.38 | 732 | libmoar.so | MVM_interp_run |
| 9 | 2.38 | 717 | libmoar.so | initialize.2614 |
| 10 | 2.26 | 681 | libmoar.so | MVM_bigint_and |
| 11 | 1.94 | 586 | libmoar.so | MVM_gc_collect_free_nursery_uncopied |
| 12 | 1.90 | 573 | libmoar.so | get_boxed_ref |
| 13 | 1.56 | 473 | libmoar.so | MVM_gc_allocate_object |
| 14 | 1.52 | 463 | libmoar.so | MVM_disp_program_run |
| 15 | 1.51 | 455 | libc.so.6 | cfree |
| 16 | 1.36 | 408 | libmoar.so | initialize.2992 |
| 17 | 1.21 | 364 | libmoar.so | MVM_bigint_shr |
| 18 | 1.08 | 325 | libmoar.so | gc_cleanup |
| 19 | 1.03 | 315 | libmoar.so | MVM_callstack_unwind_frame |
| 20 | 0.99 | 298 | libmoar.so | mp_clear |
| 21 | 0.97 | 295 | libmoar.so | allocate |
| 22 | 0.80 | 240 | libmoar.so | MVM_VMArray_at_pos |
| 23 | 0.79 | 239 | libmoar.so | MVM_args_set_result_obj |
| 24 | 0.76 | 241 | libmoar.so | MVM_spesh_inline |
| 25 | 0.73 | 224 | libmoar.so | mi_free |
| 26 | 0.71 | 212 | libmoar.so | mp_xor |
| 27 | 0.65 | 195 | libmoar.so | mp_clamp |
| 28 | 0.51 | 154 | libmoar.so | MVM_cu_string |
| 29 | 0.45 | 179 | libmoar.so | incorporate_stats |
| 30 | 0.45 | 135 | libmoar.so | MVM_string_utf8_encode_substr |
| 31 | 0.44 | 132 | libmoar.so | MVM_repr_at_pos_o |
| 32 | 0.41 | 122 | libmoar.so | mp_div_2d |
| 33 | 0.39 | 118 | libc.so.6 | __libc_calloc |
| 34 | 0.38 | 115 | libmoar.so | MVM_VMArray_push |
| 35 | 0.37 | 110 | libmoar.so | copy_to.2615 |
| 36 | 0.34 | 103 | libmoar.so | two_complement_bitop |
| 37 | 0.32 | 95 | libmoar.so | MVM_frame_try_return |
| 38 | 0.32 | 98 | libmoar.so | MVM_gc_allocate_nursery |
| 39 | 0.31 | 94 | libmoar.so | MVM_repr_box_uint |
| 40 | 0.30 | 91 | libmoar.so | core.hash.tiers.small.ImplType(64,core.hash.str.StrSpec).find |


### top 40, f

| # | share % | samples | dso | symbol |
|---:|---:|---:|---|---|
| 1 | 26.93 | 8930 | [JIT] | (unresolved) |
| 2 | 9.15 | 2924 | libmoar.so | compiler_rt.fastMemset |
| 3 | 5.63 | 1789 | libmoar.so | MVM_frame_dispatch |
| 4 | 4.05 | 1299 | libc.so.6 | (unresolved) |
| 5 | 3.19 | 1010 | libmoar.so | MVM_bigint_xor |
| 6 | 2.94 | 933 | libmoar.so | initialize.2476 |
| 7 | 2.64 | 839 | libmoar.so | gc_free.2492 |
| 8 | 2.32 | 755 | libmoar.so | MVM_interp_run |
| 9 | 2.17 | 690 | libmoar.so | MVM_spesh_arg_guard_run |
| 10 | 2.05 | 649 | libmoar.so | MVM_bigint_and |
| 11 | 1.80 | 571 | libmoar.so | get_boxed_ref |
| 12 | 1.66 | 527 | libmoar.so | MVM_gc_collect_free_nursery_uncopied |
| 13 | 1.48 | 468 | libc.so.6 | cfree |
| 14 | 1.45 | 465 | libmoar.so | MVM_disp_program_run |
| 15 | 1.41 | 447 | libmoar.so | MVM_gc_allocate_object |
| 16 | 1.34 | 423 | libmoar.so | initialize.2854 |
| 17 | 1.12 | 356 | libmoar.so | MVM_callstack_unwind_frame |
| 18 | 1.11 | 352 | libmoar.so | gc_cleanup |
| 19 | 1.01 | 321 | libmoar.so | MVM_bigint_shr |
| 20 | 0.98 | 313 | libmoar.so | allocate |
| 21 | 0.87 | 278 | libmoar.so | MVM_args_set_result_obj |
| 22 | 0.83 | 264 | libmoar.so | mp_clear |
| 23 | 0.77 | 246 | libmoar.so | mp_xor |
| 24 | 0.74 | 237 | libmoar.so | mi_free |
| 25 | 0.74 | 237 | libmoar.so | gc.collect.processWorklist |
| 26 | 0.72 | 236 | libmoar.so | MVM_spesh_inline |
| 27 | 0.64 | 204 | libmoar.so | MVM_VMArray_at_pos |
| 28 | 0.58 | 184 | libmoar.so | mp_clamp |
| 29 | 0.54 | 172 | libmoar.so | copy_to.2477 |
| 30 | 0.53 | 168 | libmoar.so | MVM_cu_string |
| 31 | 0.49 | 195 | libmoar.so | incorporate_stats |
| 32 | 0.48 | 152 | libmoar.so | moar_c.MVM_gc_root_temp_push |
| 33 | 0.42 | 132 | libc.so.6 | __libc_calloc |
| 34 | 0.39 | 123 | libmoar.so | MVM_frame_try_return |
| 35 | 0.38 | 121 | libmoar.so | MVM_VMArray_push |
| 36 | 0.38 | 122 | libmoar.so | MVM_string_utf8_encode_substr |
| 37 | 0.36 | 115 | libmoar.so | mp_div_2d |
| 38 | 0.32 | 103 | libmoar.so | MVM_gc_allocate_nursery |
| 39 | 0.32 | 102 | libmoar.so | MVM_repr_box_uint |
| 40 | 0.32 | 101 | libmoar.so | core.hash.tiers.small.ImplType(64,core.hash.str.StrSpec).find |


`initialize.*`, `allocate`, `gc_free.*`, `copy_to.*` are REPR functions of src/6model/reprs (LTO renames statics
with a numeric suffix; the non-LTO build names them in src/6model/reprs/*.c), not collector functions.

## Aligned delta, LTO

Rows aligned by the C name: LTO suffixes dropped (so same-named statics of different REPRs are summed into one
row), a Zig function `gc.<file>.<camelName>` aligned with the C static it ports (`gc.collect.processWorklist` with
`process_worklist`). Delta cycles = share x the side's median total cycles:u (above), f minus c. "gc" marks a
collector row. Top 22 by |delta| per setting; top 40 in analysis-output.md.

### plain

| key (C name) | c % | f % | f names | delta cycles (f - c) | collector |
|---|---:|---:|---|---:|---|
| [JIT] (unresolved) | 26.57 | 26.93 | (unresolved) | 5.289e+08 |  |
| libc.so.6 (unresolved) | 3.35 | 4.05 | (unresolved) | 3.090e+08 |  |
| process_worklist | 0.05 | 0.74 | gc.collect.processWorklist | 2.562e+08 | gc |
| initialize | 3.74 | 4.28 | initialize.2476 initialize.2854 | 2.556e+08 |  |
| moar_c.MVM_gc_root_temp_push | 0.00 | 0.48 | moar_c.MVM_gc_root_temp_push | 1.777e+08 | gc |
| gc_free | 2.65 | 2.77 | gc_free.2297 gc_free.2364 gc_free.2492 gc_free.2578 gc_free.... | 8.388e+07 |  |
| MVM_gc_collect_free_nursery_uncopied | 1.94 | 1.66 | MVM_gc_collect_free_nursery_uncopied | -7.476e+07 | gc |
| copy_to | 0.39 | 0.55 | copy_to.2406 copy_to.2477 copy_to.2575 | 6.504e+07 |  |
| MVM_bigint_shr | 1.21 | 1.01 | MVM_bigint_shr | -5.601e+07 |  |
| MVM_callstack_allocate_heap_frame | 0.24 | 0.08 | MVM_callstack_allocate_heap_frame | -5.565e+07 |  |
| MVM_callstack_unwind_frame | 1.03 | 1.12 | MVM_callstack_unwind_frame | 4.865e+07 |  |
| MVM_VMArray_at_pos | 0.80 | 0.64 | MVM_VMArray_at_pos | -4.731e+07 |  |
| MVM_spesh_arg_guard_run | 2.39 | 2.17 | MVM_spesh_arg_guard_run | -4.585e+07 |  |
| mp_clear | 0.99 | 0.83 | mp_clear | -4.448e+07 |  |
| MVM_bigint_and | 2.26 | 2.05 | MVM_bigint_and | -4.408e+07 |  |
| MVM_args_set_result_obj | 0.79 | 0.87 | MVM_args_set_result_obj | 4.138e+07 |  |
| two_complement_bitop | 0.34 | 0.22 | two_complement_bitop | -3.936e+07 |  |
| MVM_repr_at_pos_o | 0.44 | 0.32 | MVM_repr_at_pos_o | -3.787e+07 |  |
| mp_xor | 0.71 | 0.77 | mp_xor | 3.278e+07 |  |
| MVM_gc_allocate_object | 1.56 | 1.41 | MVM_gc_allocate_object | -3.229e+07 | gc |
| MVM_frame_try_return | 0.32 | 0.39 | MVM_frame_try_return | 3.068e+07 |  |
| MVM_repr_clone | 0.29 | 0.20 | MVM_repr_clone | -2.900e+07 |  |

### --bad-packages

| key (C name) | c % | f % | f names | delta cycles (f - c) | collector |
|---|---:|---:|---|---:|---|
| [JIT] (unresolved) | 24.96 | 26.20 | (unresolved) | 9.444e+08 |  |
| initialize | 3.32 | 4.27 | initialize.2476 initialize.2854 | 4.366e+08 |  |
| get_boxed_ref | 2.95 | 1.81 | get_boxed_ref | -3.981e+08 |  |
| MVM_gc_allocate_object | 2.03 | 1.22 | MVM_gc_allocate_object | -2.841e+08 | gc |
| process_worklist | 0.09 | 0.79 | gc.collect.processWorklist | 2.790e+08 | gc |
| MVM_bigint_and | 2.63 | 1.94 | MVM_bigint_and | -2.256e+08 |  |
| MVM_frame_dispatch | 7.05 | 6.17 | MVM_frame_dispatch | -2.207e+08 |  |
| moar_c.MVM_gc_root_temp_push | 0.00 | 0.40 | moar_c.MVM_gc_root_temp_push | 1.585e+08 | gc |
| MVM_interp_run | 2.31 | 2.59 | MVM_interp_run | 1.529e+08 |  |
| libc.so.6 (unresolved) | 3.68 | 3.89 | (unresolved) | 1.500e+08 |  |
| allocate | 0.78 | 1.02 | allocate | 1.092e+08 |  |
| compiler_rt.fastMemset | 9.05 | 8.89 | compiler_rt.fastMemset | 1.009e+08 |  |
| MVM_bigint_shr | 1.35 | 1.05 | MVM_bigint_shr | -9.435e+07 |  |
| MVM_args_set_result_obj | 1.05 | 0.80 | MVM_args_set_result_obj | -7.998e+07 |  |
| MVM_gc_collect_free_nursery_uncopied | 1.54 | 1.67 | MVM_gc_collect_free_nursery_uncopied | 7.946e+07 | gc |
| MVM_callstack_allocate_heap_frame | 0.23 | 0.05 | MVM_callstack_allocate_heap_frame | -6.714e+07 |  |
| mp_clear | 0.84 | 0.97 | mp_clear | 6.675e+07 |  |
| MVM_repr_at_pos_o | 0.41 | 0.23 | MVM_repr_at_pos_o | -6.387e+07 |  |
| ld-linux-x86-64.so.2 __tls_get_addr | 0.29 | 0.43 | __tls_get_addr | 6.073e+07 |  |
| MVM_callstack_unwind_frame | 1.35 | 1.14 | MVM_callstack_unwind_frame | -5.869e+07 |  |

## Collector share (spec 7)

Collector symbols: every `MVM_gc_*` in libmoar; on the C side the statics of src/gc/*.c (26 names in
c-gc-statics.txt; under LTO only `process_worklist`, `run_gc`, `add_work` survive as symbols, the rest are inlined);
on the Zig side the Zig-internal functions of src/zig/gc/ that have symbols in -syms, `gc.collect.processWorklist`,
`gc.collect.addInTrayToWorklist`, `gc.orchestrate.runGc`, `gc.orchestrate.addWork`,
`gc.orchestrate.reactToDebugserverRequest`, `gc.finalize.walkThreadFinalizeQueue` (the other Zig functions are
inlined into the exports); and `moar_c.MVM_gc_root_temp_push`, the translate-c copy of src/gc/roots.h's inline that
the Zig object compiles out of line. It is counted because its callers on the f side are the collector's
`MVM_gc_allocate_object`, `MVM_gc_allocate_stable`, `MVM_gc_allocate_type_object` (plus `MVM_intcache_for`, which
calls it on both sides and samples 0.00 % on c), hot-spots.txt; on the C side the same inline is folded into
`MVM_gc_allocate_object`. The symbols counted with their shares are listed per side in analysis-output.md
("Collector symbols counted").

Formula: collector cycles = collector share of samples x the side's median total cycles:u (median of the three
round medians, each over five perf stat runs); collector share = (collector cycles f - collector cycles c) /
(total cycles f - total cycles c).

| | plain | --bad-packages |
|---|---:|---:|
| total cycles:u c | 35527891606 | 37803121150 |
| total cycles:u f | 37017096437 | 39618532654 |
| difference f - c | 1489204831 (4.19 % of c) | 1815411504 (4.80 % of c) |
| spread of round medians c / f | 164352416 / 441166038 | 210332707 / 929731014 |
| run-to-run spread (max - min of 15 runs) c / f | 832538599 / 1106939722 | 1044134536 / 2341888660 |
| collector samples c | 4.15 % | 4.25 % |
| collector samples f | 4.84 % | 4.58 % |
| collector cycles c | 0.0415 x 35527891606 = 1474407502 | 0.0425 x 37803121150 = 1606632649 |
| collector cycles f | 0.0484 x 37017096437 = 1791627468 | 0.0458 x 39618532654 = 1814528796 |
| collector difference f - c | 317219966 | 207896147 |
| **collector share** | **317219966 / 1489204831 = 0.213** | 207896147 / 1815411504 = 0.115 (computed, not resolvable at this volume) |
| without `moar_c.MVM_gc_root_temp_push` (exports and gc.* only) | 0.094 | 0.027 |

The unresolvable rule: plain, the total-cycle difference (1.49e9) is larger than either side's spread, both of round
medians (1.6e8, 4.4e8) and over all 15 runs (8.3e8, 1.11e9): **resolvable**. --bad-packages, the difference
(1.82e9) is smaller than the f side's run-to-run spread over its 15 runs (2.34e9: f runs range 3.88e10-4.11e10,
round 3 the slowest), so under spec 7's rule ("smaller than either side's run-to-run spread") **the --bad-packages
gap is unresolvable at volume 100 000**; the f side's 15-run spread decided it (it does exceed the round-median
spreads, 2.1e8 and 9.3e8, and the C side's 15-run spread, 1.04e9, but the rule takes either side). Its share 0.115
is computed but not resolvable at this volume and carries no weight. The verdict rests on plain's 0.213 alone.

Where the collector's part lies (plain, cycles from the delta table): `gc.collect.processWorklist` +2.56e8 against
`process_worklist`, `moar_c.MVM_gc_root_temp_push` +1.78e8, offset by `MVM_gc_collect_free_nursery_uncopied`
-7.5e7, `MVM_gc_allocate_object` -3.2e7 and the root scans (-2.0e7 frame roots, +1.9e7 frame registers).

**The processWorklist stall.** perf annotate (hot-spots.txt) puts 79.1 % of `gc.collect.processWorklist`'s samples
(37.10 % + 42.01 %) on the instruction after an `mfence`: the faithful port's `atomic.fence()` is inline-asm `mfence`
(src/zig/gc/atomic.zig:116), at the forwarder-publishing site (`*item_ptr = new; item.forwarder = new; fence;
flags2 |= MVM_CF_FORWARDER_VALID`; one site in the source, src/gc/collect.c:320, which the compiler duplicates into
the gen2-promotion and nursery-copy paths on both sides). The C collector's `MVM_barrier()` there
(`atomic_thread_fence(memory_order_seq_cst)`, src/moar.h:359) compiles to `lock orl $0x0,-0x40(%rsp)`. What the data shows is the sample concentration, not a direct timing of the
two fences: C's `process_worklist` is 0.05 % in total and its post-fence instruction 6.19 % of that, against the
Zig function's 0.74 % with 79.1 % after the fence. ng-f-syms has 3 `mfence` in the whole libmoar, all in `gc.collect.processWorklist`;
ng-c-syms has none (and 37 `lock or $0x0,...(%rsp)`). That is 0.791 x 0.74 % x 37017096437 = 2.17e8 cycles, 14.6 %
of the plain gap, in one instruction.

## Non-LTO attribution (ng-c-nlto / ng-f-nlto; attribution only, a different binary)

One sampled run per side, plain, no perf stat (the controller's ruling). Collector samples: c 3.59 %, f 5.25 %
(+1.66 points). There are no counted totals for this pair; if its total gap were the LTO pair's 4.19 %, the share
would be (0.0525 x 1.0419 - 0.0359) / 0.0419 = 0.45, so LTO folds part of the collector's cost into non-collector
callers on one side or the other, and the non-LTO view puts more of the gap in the collector. That number rests on
an assumed denominator and is not the spec's share.

| key (C name) | c % | f % | f names | delta points | collector |
|---|---:|---:|---|---:|---|
| process_worklist | 0.11 | 0.81 | gc.collect.processWorklist | +0.70 | gc |
| compiler_rt.fastMemset | 9.39 | 8.97 | compiler_rt.fastMemset | -0.42 |  |
| initialize | 3.59 | 3.99 | initialize | +0.40 |  |
| MVM_gc_allocate_nursery | 0.29 | 0.68 | MVM_gc_allocate_nursery | +0.39 | gc |
| MVM_repr_alloc_init | 1.49 | 1.82 | MVM_repr_alloc_init | +0.33 |  |
| moar_c.MVM_gc_root_temp_push | 0.00 | 0.25 | moar_c.MVM_gc_root_temp_push | +0.25 | gc |
| MVM_disp_program_run | 1.55 | 1.33 | MVM_disp_program_run | -0.22 |  |
| MVM_callstack_unwind_frame | 0.90 | 1.11 | MVM_callstack_unwind_frame | +0.21 |  |
| MVM_gc_collect_free_nursery_uncopied | 1.54 | 1.75 | MVM_gc_collect_free_nursery_uncopied | +0.21 | gc |
| gc_free | 3.11 | 3.31 | gc_free | +0.20 |  |
| MVM_spesh_arg_guard_run | 2.52 | 2.34 | MVM_spesh_arg_guard_run | -0.18 |  |
| MVM_frame_dispatch | 3.07 | 2.89 | MVM_frame_dispatch | -0.18 |  |
| MVM_bigint_and | 0.87 | 1.04 | MVM_bigint_and | +0.17 |  |
| get_boxed_ref | 2.38 | 2.21 | get_boxed_ref | -0.17 |  |
| mi_free | 0.87 | 0.71 | mi_free | -0.16 |  |
| mi_calloc | 2.52 | 2.37 | mi_calloc | -0.15 |  |
| mp_clear | 1.10 | 0.96 | mp_clear | -0.14 |  |
| libc.so.6 (unresolved) | 3.76 | 3.62 | (unresolved) | -0.14 |  |
| MVM_bigint_xor | 1.53 | 1.39 | MVM_bigint_xor | -0.14 |  |
| mp_xor | 0.73 | 0.87 | mp_xor | +0.14 |  |

The non-LTO deltas repeat the LTO picture and add one: `MVM_gc_allocate_nursery` +0.39 points (the Zig export is
reached through the PLT from C, `MVM_gc_allocate_nursery@plt` 0.04 %; under LTO both sides show 0.32 %).

## Finding

On cycles:u at volume 100 000 the faithful port's gap to the C control is 4.19 % plain (4.80 % bad) on the
profiled -syms pair. Plain is resolvable and the collector's functions hold 0.213 of it (0.094 counting only the
exports and the Zig-internal functions); the --bad-packages gap is not resolvable at this volume under spec 7's rule
(smaller than the f side's run-to-run spread), its computed 0.115 counts for nothing. Within the collector the gap lies in
`gc.collect.processWorklist` (+2.56e8 cycles plain, nearly all of it the `mfence` of `atomic.fence()` where C emits
`lock or`) and in `moar_c.MVM_gc_root_temp_push`, the translated C inline that `allocation.zig`'s
`MVM_gc_allocate_object`/`_stable`/`_type_object` call out of line (+1.78e8); `MVM_gc_allocate_nursery` reached
through the PLT adds to it in the non-LTO build. Of spec 8's items the evidence points at **b** (Zig calling Zig:
a Zig-native temp-root push and nursery allocation that the compiler inlines, Task 3's allocation.zig) and at the
fence, which is not a section 8 item: the global constraints keep `atomic.fence()` as it is, so a decision-neutral
`lock or` fence (what clang emits for `atomic_thread_fence(memory_order_seq_cst)`) needs the controller's ruling.
Items a, c, d, e, f, g, h show no measurable cost here. The rest of the gap, about four fifths, lies outside the
collector: JIT-compiled code (+5.3e8 plain, +9.4e8 bad), unsymbolised libc (+3.1e8 plain), the REPRs' `initialize`
(+2.6e8 plain, +4.4e8 bad) and a scatter of interpreter and bigint functions moving both ways, consistent with code
placement and cache effects of a different libmoar layout; the same-source -syms/-base A/B moved the C side by 1.5 %
on placement alone. The non-LTO attribution pass suggests LTO hides some collector cost (about 0.45 on an assumed
denominator), which is attribution only.

**Stop rule (spec 11): the collector share is 0.213 plain, under a quarter of the gap, so the rule fires: stop after
Task 2 and report to the user.** The verdict follows spec 7's measured (LTO) procedure and is not robust to build
mode: the non-LTO attribution pass puts the collector near 0.45 of the gap on an assumed denominator, so a decision
to stop should weigh that.
