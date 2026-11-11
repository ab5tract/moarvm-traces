## Counters

### plain

| event | c median [round-median min-max] | f median [round-median min-max] | f/c | c runs min-max (15) | f runs min-max (15) |
|---|---:|---:|---:|---:|---:|
| cycles:u | 35993466595 [35610714012-36195853010] | 36129682828 [35915205514-36167961163] | 1.0038 | 35456480343-36627499807 | 35666247263-36254737266 |
| instructions:u | 68909118467 [68902279867-68934522940] | 68786479769 [68774659735-68796982887] | 0.9982 | 68479294571-68980701640 | 68491551596-68853442372 |
| branch-misses:u | 48602113 [48279928-49275266] | 50074393 [49644876-50373324] | 1.0303 | 47444452-50558132 | 48518702-51247522 |
| cache-misses:u | 126175431 [125675929-129482388] | 130769217 [127428658-130984512] | 1.0364 | 118352337-157012127 | 121536201-146930823 |
| L1-dcache-load-misses:u | 1106632781 [1094929064-1139515987] | 1103091508 [1093363753-1111892771] | 0.9968 | 1085535641-1151510221 | 1083565478-1164000620 |

Round medians, cycles:u: c 36195853010 35610714012 35993466595; f 36129682828 36167961163 35915205514

### bad

| event | c median [round-median min-max] | f median [round-median min-max] | f/c | c runs min-max (15) | f runs min-max (15) |
|---|---:|---:|---:|---:|---:|
| cycles:u | 38379754264 [38062136278-38552042153] | 38470716341 [38287403091-38514170057] | 1.0024 | 37742719735-53084305163 | 37999338634-39012791110 |
| instructions:u | 70916160495 [70877140317-70943506239] | 70808189292 [70785873912-70818520716] | 0.9985 | 70597164472-70964449878 | 70539159749-70869157283 |
| branch-misses:u | 51985911 [51296869-52257654] | 52943406 [52285329-53745200] | 1.0184 | 50192881-54082275 | 51626577-58044535 |
| cache-misses:u | 151248125 [146805900-156409416] | 153680197 [152054625-154517456] | 1.0161 | 135976281-171467264 | 141859867-175212173 |
| L1-dcache-load-misses:u | 1218731733 [1212215696-1238932917] | 1211200618 [1206872772-1216672007] | 0.9938 | 1189331528-3180273927 | 1181428164-1264900468 |

Round medians, cycles:u: c 38379754264 38062136278 38552042153; f 38470716341 38287403091 38514170057

## Samples: LTO, plain

### top 40, c

| # | share % | samples | dso | symbol |
|---:|---:|---:|---|---|
| 1 | 26.73 | 8757 | [JIT] | (unresolved) |
| 2 | 9.67 | 3056 | libmoar.so | compiler_rt.fastMemset |
| 3 | 6.21 | 1948 | libmoar.so | MVM_frame_dispatch |
| 4 | 4.38 | 1373 | libc.so.6 | (unresolved) |
| 5 | 3.15 | 987 | libmoar.so | MVM_bigint_xor |
| 6 | 2.81 | 879 | libmoar.so | gc_free.2630 |
| 7 | 2.38 | 743 | libmoar.so | MVM_spesh_arg_guard_run |
| 8 | 2.33 | 746 | libmoar.so | MVM_interp_run |
| 9 | 2.30 | 719 | libmoar.so | initialize.2614 |
| 10 | 2.20 | 685 | libmoar.so | MVM_bigint_and |
| 11 | 2.12 | 663 | libmoar.so | get_boxed_ref |
| 12 | 1.71 | 534 | libmoar.so | MVM_gc_collect_free_nursery_uncopied |
| 13 | 1.59 | 500 | libmoar.so | MVM_gc_allocate_object |
| 14 | 1.47 | 467 | libmoar.so | MVM_disp_program_run |
| 15 | 1.37 | 430 | libc.so.6 | cfree |
| 16 | 1.24 | 387 | libmoar.so | initialize.2992 |
| 17 | 1.17 | 366 | libmoar.so | MVM_bigint_shr |
| 18 | 1.10 | 346 | libmoar.so | mp_clear |
| 19 | 1.02 | 319 | libmoar.so | gc_cleanup |
| 20 | 0.94 | 294 | libmoar.so | allocate |
| 21 | 0.86 | 270 | libmoar.so | mi_free |
| 22 | 0.85 | 266 | libmoar.so | MVM_callstack_unwind_frame |
| 23 | 0.78 | 244 | libmoar.so | mp_xor |
| 24 | 0.77 | 241 | libmoar.so | MVM_args_set_result_obj |
| 25 | 0.75 | 242 | libmoar.so | MVM_spesh_inline |
| 26 | 0.67 | 209 | libmoar.so | MVM_VMArray_at_pos |
| 27 | 0.57 | 178 | libmoar.so | mp_clamp |
| 28 | 0.48 | 193 | libmoar.so | incorporate_stats |
| 29 | 0.46 | 143 | libmoar.so | mp_div_2d |
| 30 | 0.45 | 142 | libmoar.so | MVM_frame_try_return |
| 31 | 0.40 | 125 | libmoar.so | MVM_string_utf8_encode_substr |
| 32 | 0.39 | 123 | libmoar.so | MVM_VMArray_push |
| 33 | 0.35 | 109 | libmoar.so | core.hash.tiers.small.ImplType(64,core.hash.str.StrSpec).find |
| 34 | 0.35 | 110 | libmoar.so | MVM_gc_allocate_nursery |
| 35 | 0.34 | 108 | libmoar.so | set_size_internal |
| 36 | 0.34 | 108 | libmoar.so | MVM_repr_at_pos_o |
| 37 | 0.34 | 109 | libmoar.so | two_complement_bitop |
| 38 | 0.32 | 99 | libmoar.so | copy_to.2615 |
| 39 | 0.31 | 96 | libmoar.so | MVM_cu_string |
| 40 | 0.31 | 99 | libmoar.so | dispatch_monomorphic |

Collector share of samples, c: 3.93 % (sum over 16 symbols; perf's listed total 98.36 %)

Collector symbols counted, c: MVM_gc_collect_free_nursery_uncopied 1.71, MVM_gc_allocate_object 1.59, MVM_gc_allocate_nursery 0.35, MVM_gc_root_add_frame_roots_to_worklist 0.11, process_worklist 0.05, MVM_gc_mark_collectable 0.03, MVM_gc_gen2_allocate 0.03, MVM_gc_collect 0.02, run_gc 0.01, MVM_gc_root_gen2_add 0.01, MVM_gc_root_add_instance_roots_to_worklist 0.01, MVM_gc_root_add_tc_roots_to_worklist 0.01, MVM_gc_worklist_create 0.00, MVM_gc_gen2_allocate@plt 0.00, MVM_gc_mark_thread_unblocked 0.00, MVM_gc_allocate_stable 0.00

### top 40, f

| # | share % | samples | dso | symbol |
|---:|---:|---:|---|---|
| 1 | 27.70 | 8938 | [JIT] | (unresolved) |
| 2 | 9.40 | 2925 | libmoar.so | compiler_rt.fastMemset |
| 3 | 5.86 | 1810 | libmoar.so | MVM_frame_dispatch |
| 4 | 3.64 | 1143 | libc.so.6 | (unresolved) |
| 5 | 3.10 | 957 | libmoar.so | MVM_bigint_xor |
| 6 | 2.74 | 845 | libmoar.so | gc_free.2492 |
| 7 | 2.55 | 801 | libmoar.so | MVM_interp_run |
| 8 | 2.54 | 782 | libmoar.so | initialize.2476 |
| 9 | 2.29 | 706 | libmoar.so | MVM_spesh_arg_guard_run |
| 10 | 2.05 | 632 | libmoar.so | MVM_bigint_and |
| 11 | 1.91 | 588 | libmoar.so | get_boxed_ref |
| 12 | 1.83 | 570 | libmoar.so | gc.collect.freeNurseryUncopied |
| 13 | 1.53 | 474 | libmoar.so | gc.allocation.allocateObject |
| 14 | 1.49 | 467 | libmoar.so | MVM_disp_program_run |
| 15 | 1.48 | 457 | libc.so.6 | cfree |
| 16 | 1.35 | 417 | libmoar.so | initialize.2854 |
| 17 | 1.11 | 343 | libmoar.so | MVM_bigint_shr |
| 18 | 1.09 | 338 | libmoar.so | MVM_callstack_unwind_frame |
| 19 | 1.08 | 334 | libmoar.so | gc_cleanup |
| 20 | 1.05 | 325 | libmoar.so | mp_clear |
| 21 | 0.92 | 290 | libmoar.so | mi_free |
| 22 | 0.90 | 279 | libmoar.so | allocate |
| 23 | 0.89 | 274 | libmoar.so | MVM_args_set_result_obj |
| 24 | 0.72 | 232 | libmoar.so | MVM_spesh_inline |
| 25 | 0.64 | 197 | libmoar.so | mp_xor |
| 26 | 0.62 | 192 | libmoar.so | MVM_VMArray_at_pos |
| 27 | 0.55 | 169 | libmoar.so | mp_clamp |
| 28 | 0.45 | 188 | libmoar.so | incorporate_stats |
| 29 | 0.41 | 127 | libmoar.so | MVM_cu_string |
| 30 | 0.40 | 122 | libmoar.so | MVM_string_utf8_encode_substr |
| 31 | 0.39 | 122 | libmoar.so | MVM_VMArray_push |
| 32 | 0.38 | 117 | libmoar.so | copy_to.2477 |
| 33 | 0.35 | 109 | libmoar.so | MVM_repr_at_pos_o |
| 34 | 0.34 | 105 | libmoar.so | mp_div_2d |
| 35 | 0.34 | 106 | libmoar.so | MVM_frame_try_return |
| 36 | 0.33 | 100 | libmoar.so | two_complement_bitop |
| 37 | 0.32 | 98 | libmoar.so | exit_heap_frame |
| 38 | 0.32 | 100 | libmoar.so | mp_and |
| 39 | 0.31 | 97 | libmoar.so | set_size_internal |
| 40 | 0.30 | 94 | libmoar.so | MVM_callsite_mark_interns |

Collector share of samples, f: 4.08 % (sum over 18 symbols; perf's listed total 98.30 %)

Collector symbols counted, f: gc.collect.freeNurseryUncopied 1.83, gc.allocation.allocateObject 1.53, MVM_gc_allocate_nursery 0.24, gc.collect.processWorklist 0.11, MVM_gc_allocate_object 0.10, gc.roots.addFrameRootsToWorklist 0.08, gc.roots.addFrameRegistersToWorklist 0.06, gc.collect.markCollectable 0.04, gc.orchestrate.markThreadUnblocked 0.03, gc.gen2.allocate 0.02, gc.collect.collect 0.02, gc.roots.addInstanceRootsToWorklist 0.01, gc.allocation.allocateStable 0.01, MVM_gc_write_barrier_hit_by 0.00, gc.orchestrate.runGc 0.00, gc.orchestrate.enterFromAllocator 0.00, MVM_gc_object_id 0.00, gc.roots.gen2Add 0.00

### aligned delta, top 40 by |delta| (cycles = share x median total cycles of the side)

| key (C name) | c % | f % | f names | delta cycles (f - c) | collector |
|---|---:|---:|---|---:|---|
| free_nursery_uncopied | 0.00 | 1.83 | gc.collect.freeNurseryUncopied | 6.612e+08 | gc |
| MVM_gc_collect_free_nursery_uncopied | 1.71 | 0.00 |  | -6.155e+08 | gc |
| allocate_object | 0.00 | 1.53 | gc.allocation.allocateObject | 5.528e+08 | gc |
| MVM_gc_allocate_object | 1.59 | 0.10 | MVM_gc_allocate_object | -5.362e+08 | gc |
| [JIT] (unresolved) | 26.73 | 27.70 | (unresolved) | 3.869e+08 |  |
| libc.so.6 (unresolved) | 4.38 | 3.64 | (unresolved) | -2.614e+08 |  |
| initialize | 3.54 | 3.89 | initialize.2476 initialize.2854 | 1.313e+08 |  |
| MVM_frame_dispatch | 6.21 | 5.86 | MVM_frame_dispatch | -1.180e+08 |  |
| MVM_callstack_unwind_frame | 0.85 | 1.09 | MVM_callstack_unwind_frame | 8.787e+07 |  |
| compiler_rt.fastMemset | 9.67 | 9.40 | compiler_rt.fastMemset | -8.438e+07 |  |
| MVM_interp_run | 2.33 | 2.55 | MVM_interp_run | 8.266e+07 |  |
| get_boxed_ref | 2.12 | 1.91 | get_boxed_ref | -7.298e+07 |  |
| MVM_bigint_and | 2.20 | 2.05 | MVM_bigint_and | -5.120e+07 |  |
| mp_xor | 0.78 | 0.64 | mp_xor | -4.952e+07 |  |
| mp_and | 0.19 | 0.32 | mp_and | 4.723e+07 |  |
| exit_heap_frame | 0.19 | 0.32 | exit_heap_frame | 4.723e+07 |  |
| MVM_args_set_result_obj | 0.77 | 0.89 | MVM_args_set_result_obj | 4.440e+07 |  |
| mp_div_2d | 0.46 | 0.34 | mp_div_2d | -4.273e+07 |  |
| libc.so.6 cfree | 1.37 | 1.48 | cfree | 4.161e+07 |  |
| MVM_gc_root_add_frame_roots_to_worklist | 0.11 | 0.00 |  | -3.959e+07 | gc |
| MVM_gc_allocate_nursery | 0.35 | 0.24 | MVM_gc_allocate_nursery | -3.927e+07 | gc |
| MVM_frame_try_return | 0.45 | 0.34 | MVM_frame_try_return | -3.913e+07 |  |
| MVM_cu_string | 0.31 | 0.41 | MVM_cu_string | 3.655e+07 |  |
| MVM_spesh_arg_guard_run | 2.38 | 2.29 | MVM_spesh_arg_guard_run | -2.927e+07 |  |
| add_frame_roots_to_worklist | 0.00 | 0.08 | gc.roots.addFrameRootsToWorklist | 2.890e+07 | gc |
| core.hash.tiers.small.ImplType(64,core.hash.str.StrSpec).find | 0.35 | 0.27 | core.hash.tiers.small.ImplType(64,core.hash.str.StrSpec).find | -2.843e+07 |  |
| MVM_string_compute_hash_code | 0.16 | 0.09 | MVM_string_compute_hash_code | -2.507e+07 |  |
| mp_clear@plt | 0.17 | 0.10 | mp_clear@plt | -2.506e+07 |  |
| get_int | 0.23 | 0.16 | get_int get_int.2857 | -2.498e+07 |  |
| gc_cleanup | 1.02 | 1.08 | gc_cleanup | 2.307e+07 |  |
| mi_free | 0.86 | 0.92 | mi_free | 2.285e+07 |  |
| MVM_callsite_mark_interns | 0.24 | 0.30 | MVM_callsite_mark_interns | 2.200e+07 |  |
| MVM_spesh_stats_update | 0.19 | 0.25 | MVM_spesh_stats_update | 2.194e+07 |  |
| process_worklist | 0.05 | 0.11 | gc.collect.processWorklist | 2.175e+07 | gc |
| MVM_string_encode_to_buf_config | 0.05 | 0.11 | MVM_string_encode_to_buf_config | 2.175e+07 |  |
| add_frame_registers_to_worklist | 0.00 | 0.06 | gc.roots.addFrameRegistersToWorklist | 2.168e+07 | gc |
| get_str | 0.11 | 0.05 | get_str | -2.153e+07 |  |
| MVM_bigint_shr | 1.17 | 1.11 | MVM_bigint_shr | -2.008e+07 |  |
| copy_to | 0.35 | 0.40 | copy_to.2477 copy_to.2575 | 1.854e+07 |  |
| MVM_string_substrings_equal_nocheck | 0.16 | 0.21 | MVM_string_substrings_equal_nocheck | 1.828e+07 |  |

### collector share, plain

- total cycles median: c 35993466595, f 36129682828; difference f - c 136216233 (0.38 % of c)
- spread of round medians: c 585138998, f 252755649; run-to-run spread over all 15 runs: c 1171019464, f 588490003
- collector cycles: c 3.93 % x 35993466595 = 1414543237; f 4.08 % x 36129682828 = 1474091059; difference 59547822
- collector share = 59547822 / 136216233 = 0.437

## Samples: LTO, bad

### top 40, c

| # | share % | samples | dso | symbol |
|---:|---:|---:|---|---|
| 1 | 25.95 | 8970 | [JIT] | (unresolved) |
| 2 | 9.43 | 3087 | libmoar.so | compiler_rt.fastMemset |
| 3 | 6.76 | 2191 | libmoar.so | MVM_frame_dispatch |
| 4 | 3.50 | 1154 | libc.so.6 | (unresolved) |
| 5 | 2.80 | 906 | libmoar.so | MVM_bigint_xor |
| 6 | 2.78 | 903 | libmoar.so | gc_free.2630 |
| 7 | 2.62 | 864 | libmoar.so | MVM_interp_run |
| 8 | 2.51 | 811 | libmoar.so | MVM_spesh_arg_guard_run |
| 9 | 2.31 | 747 | libmoar.so | initialize.2614 |
| 10 | 1.98 | 641 | libmoar.so | get_boxed_ref |
| 11 | 1.88 | 609 | libmoar.so | MVM_bigint_and |
| 12 | 1.75 | 566 | libmoar.so | MVM_gc_collect_free_nursery_uncopied |
| 13 | 1.61 | 521 | libmoar.so | MVM_gc_allocate_object |
| 14 | 1.53 | 501 | libmoar.so | MVM_disp_program_run |
| 15 | 1.50 | 485 | libc.so.6 | cfree |
| 16 | 1.21 | 390 | libmoar.so | initialize.2992 |
| 17 | 1.04 | 337 | libmoar.so | mp_clear |
| 18 | 1.02 | 329 | libmoar.so | MVM_bigint_shr |
| 19 | 1.01 | 328 | libmoar.so | gc_cleanup |
| 20 | 1.00 | 325 | libmoar.so | MVM_callstack_unwind_frame |
| 21 | 0.96 | 312 | libmoar.so | allocate |
| 22 | 0.91 | 293 | libmoar.so | MVM_args_set_result_obj |
| 23 | 0.80 | 262 | libmoar.so | mi_free |
| 24 | 0.74 | 240 | libmoar.so | MVM_VMArray_at_pos |
| 25 | 0.72 | 243 | libmoar.so | MVM_spesh_inline |
| 26 | 0.68 | 221 | libmoar.so | mp_xor |
| 27 | 0.57 | 186 | libmoar.so | mp_clamp |
| 28 | 0.50 | 162 | libmoar.so | set_size_internal |
| 29 | 0.46 | 149 | libmoar.so | mp_div_2d |
| 30 | 0.45 | 187 | libmoar.so | incorporate_stats |
| 31 | 0.42 | 135 | libmoar.so | MVM_string_utf8_encode_substr |
| 32 | 0.40 | 128 | libmoar.so | exit_heap_frame |
| 33 | 0.38 | 124 | libmoar.so | MVM_cu_string |
| 34 | 0.38 | 122 | libmoar.so | search_for_handler_from |
| 35 | 0.38 | 124 | libmoar.so | MVM_repr_clone |
| 36 | 0.38 | 124 | libmoar.so | copy_to.2615 |
| 37 | 0.37 | 119 | libmoar.so | MVM_frame_try_return |
| 38 | 0.36 | 117 | libmoar.so | MVM_repr_at_pos_o |
| 39 | 0.35 | 114 | libmoar.so | MVM_VMArray_push |
| 40 | 0.32 | 104 | libc.so.6 | __libc_calloc |

Collector share of samples, c: 4.02 % (sum over 13 symbols; perf's listed total 97.92 %)

Collector symbols counted, c: MVM_gc_collect_free_nursery_uncopied 1.75, MVM_gc_allocate_object 1.61, MVM_gc_allocate_nursery 0.32, MVM_gc_root_add_frame_roots_to_worklist 0.12, process_worklist 0.07, run_gc 0.05, MVM_gc_gen2_allocate 0.03, MVM_gc_mark_collectable 0.03, MVM_gc_collect 0.02, MVM_gc_root_add_instance_roots_to_worklist 0.01, MVM_gc_mark_thread_unblocked 0.01, MVM_gc_root_gen2_add 0.00, MVM_gc_mark_thread_unblocked@plt 0.00

### top 40, f

| # | share % | samples | dso | symbol |
|---:|---:|---:|---|---|
| 1 | 25.89 | 9133 | [JIT] | (unresolved) |
| 2 | 10.02 | 3373 | libmoar.so | compiler_rt.fastMemset |
| 3 | 6.92 | 2300 | libmoar.so | MVM_frame_dispatch |
| 4 | 3.64 | 1258 | libc.so.6 | (unresolved) |
| 5 | 2.96 | 986 | libmoar.so | gc_free.2492 |
| 6 | 2.94 | 977 | libmoar.so | MVM_bigint_xor |
| 7 | 2.41 | 816 | libmoar.so | MVM_interp_run |
| 8 | 2.38 | 789 | libmoar.so | MVM_spesh_arg_guard_run |
| 9 | 2.20 | 732 | libmoar.so | initialize.2476 |
| 10 | 1.93 | 640 | libmoar.so | MVM_bigint_and |
| 11 | 1.90 | 630 | libmoar.so | get_boxed_ref |
| 12 | 1.73 | 578 | libmoar.so | gc.collect.freeNurseryUncopied |
| 13 | 1.71 | 568 | libmoar.so | mp_clear |
| 14 | 1.47 | 490 | libc.so.6 | cfree |
| 15 | 1.44 | 486 | libmoar.so | MVM_disp_program_run |
| 16 | 1.41 | 469 | libmoar.so | gc.allocation.allocateObject |
| 17 | 1.12 | 373 | libmoar.so | MVM_bigint_shr |
| 18 | 1.09 | 362 | libmoar.so | MVM_callstack_unwind_frame |
| 19 | 1.07 | 355 | libmoar.so | initialize.2854 |
| 20 | 1.04 | 347 | libmoar.so | gc_cleanup |
| 21 | 0.89 | 296 | libmoar.so | MVM_args_set_result_obj |
| 22 | 0.86 | 287 | libmoar.so | allocate |
| 23 | 0.86 | 285 | libmoar.so | mi_free |
| 24 | 0.68 | 234 | libmoar.so | MVM_spesh_inline |
| 25 | 0.63 | 210 | libmoar.so | mp_xor |
| 26 | 0.56 | 186 | libmoar.so | mp_clamp |
| 27 | 0.53 | 175 | libmoar.so | MVM_VMArray_at_pos |
| 28 | 0.47 | 156 | libmoar.so | exit_heap_frame |
| 29 | 0.46 | 153 | libmoar.so | set_size_internal |
| 30 | 0.41 | 136 | libmoar.so | MVM_cu_string |
| 31 | 0.41 | 181 | libmoar.so | incorporate_stats |
| 32 | 0.41 | 136 | libmoar.so | MVM_string_utf8_encode_substr |
| 33 | 0.40 | 132 | libmoar.so | MVM_frame_try_return |
| 34 | 0.40 | 133 | libmoar.so | copy_to.2477 |
| 35 | 0.38 | 127 | libmoar.so | MVM_VMArray_push |
| 36 | 0.36 | 120 | libmoar.so | search_for_handler_from |
| 37 | 0.36 | 119 | libmoar.so | mi_free@plt |
| 38 | 0.33 | 111 | libmoar.so | MVM_repr_clone |
| 39 | 0.31 | 106 | libmoar.so | core.hash.tiers.small.ImplType(64,core.hash.str.StrSpec).find |
| 40 | 0.30 | 100 | libc.so.6 | __libc_calloc |

Collector share of samples, f: 3.90 % (sum over 16 symbols; perf's listed total 97.87 %)

Collector symbols counted, f: gc.collect.freeNurseryUncopied 1.73, gc.allocation.allocateObject 1.41, MVM_gc_allocate_nursery 0.26, MVM_gc_allocate_object 0.13, gc.collect.processWorklist 0.07, gc.roots.addFrameRootsToWorklist 0.07, gc.orchestrate.runGc 0.06, gc.roots.addFrameRegistersToWorklist 0.05, gc.orchestrate.markThreadUnblocked 0.04, gc.collect.markCollectable 0.03, gc.gen2.allocate 0.02, gc.roots.addTcRootsToWorklist 0.01, gc.roots.addInstanceRootsToWorklist 0.01, gc.collect.collect 0.01, gc.allocation.allocateStable 0.00, MVM_gc_write_barrier_hit_by 0.00

### aligned delta, top 40 by |delta| (cycles = share x median total cycles of the side)

| key (C name) | c % | f % | f names | delta cycles (f - c) | collector |
|---|---:|---:|---|---:|---|
| MVM_gc_collect_free_nursery_uncopied | 1.75 | 0.00 |  | -6.716e+08 | gc |
| free_nursery_uncopied | 0.00 | 1.73 | gc.collect.freeNurseryUncopied | 6.655e+08 | gc |
| MVM_gc_allocate_object | 1.61 | 0.13 | MVM_gc_allocate_object | -5.679e+08 | gc |
| allocate_object | 0.00 | 1.41 | gc.allocation.allocateObject | 5.424e+08 | gc |
| mp_clear | 1.04 | 1.71 | mp_clear | 2.587e+08 |  |
| compiler_rt.fastMemset | 9.43 | 10.02 | compiler_rt.fastMemset | 2.356e+08 |  |
| initialize | 3.52 | 3.27 | initialize.2476 initialize.2854 | -9.297e+07 |  |
| MVM_VMArray_at_pos | 0.74 | 0.53 | MVM_VMArray_at_pos | -8.012e+07 |  |
| MVM_interp_run | 2.62 | 2.41 | MVM_interp_run | -7.841e+07 |  |
| MVM_frame_dispatch | 6.76 | 6.92 | MVM_frame_dispatch | 6.770e+07 |  |
| gc_free | 2.94 | 3.10 | gc_free.2297 gc_free.2364 gc_free.2492 gc_free.2578 gc_free.... | 6.423e+07 |  |
| mp_div_2d | 0.46 | 0.30 | mp_div_2d | -6.113e+07 |  |
| libc.so.6 (unresolved) | 3.50 | 3.64 | (unresolved) | 5.704e+07 |  |
| MVM_bigint_xor | 2.80 | 2.94 | MVM_bigint_xor | 5.641e+07 |  |
| mi_free@plt | 0.22 | 0.36 | mi_free@plt | 5.406e+07 |  |
| MVM_spesh_arg_guard_run | 2.51 | 2.38 | MVM_spesh_arg_guard_run | -4.773e+07 |  |
| MVM_gc_root_add_frame_roots_to_worklist | 0.12 | 0.00 |  | -4.606e+07 | gc |
| MVM_repr_at_pos_o | 0.36 | 0.24 | MVM_repr_at_pos_o | -4.584e+07 |  |
| MVM_bigint_shr | 1.02 | 1.12 | MVM_bigint_shr | 3.940e+07 |  |
| MVM_callstack_unwind_frame | 1.00 | 1.09 | MVM_callstack_unwind_frame | 3.553e+07 |  |
| MVM_disp_program_run | 1.53 | 1.44 | MVM_disp_program_run | -3.323e+07 |  |
| allocate | 0.96 | 0.88 | allocate gc.gen2.allocate | -2.990e+07 | gc |
| get_boxed_ref | 1.98 | 1.90 | get_boxed_ref | -2.898e+07 |  |
| exit_heap_frame | 0.40 | 0.47 | exit_heap_frame | 2.729e+07 |  |
| MVM_string_ci_get_codepoint | 0.17 | 0.24 | MVM_string_ci_get_codepoint.5077 | 2.708e+07 |  |
| add_frame_roots_to_worklist | 0.00 | 0.07 | gc.roots.addFrameRootsToWorklist | 2.693e+07 | gc |
| two_complement_bitop | 0.31 | 0.24 | two_complement_bitop | -2.665e+07 |  |
| mi_free | 0.80 | 0.86 | mi_free | 2.381e+07 |  |
| mp_set_u64 | 0.27 | 0.21 | mp_set_u64 | -2.284e+07 |  |
| MVM_gc_allocate_nursery | 0.32 | 0.26 | MVM_gc_allocate_nursery | -2.279e+07 | gc |
| MVM_bigint_and | 1.88 | 1.93 | MVM_bigint_and | 2.095e+07 |  |
| _mi_malloc_generic | 0.02 | 0.07 | _mi_malloc_generic | 1.925e+07 |  |
| add_frame_registers_to_worklist | 0.00 | 0.05 | gc.roots.addFrameRegistersToWorklist | 1.924e+07 | gc |
| core.hash.index.fetchNocheck | 0.11 | 0.06 | core.hash.index.fetchNocheck | -1.914e+07 |  |
| go_to_first_inline | 0.11 | 0.06 | go_to_first_inline | -1.914e+07 |  |
| compiler_rt.memcpy.memcpyFast | 0.14 | 0.09 | compiler_rt.memcpy.memcpyFast | -1.911e+07 |  |
| MVM_callstack_allocate_heap_frame | 0.22 | 0.17 | MVM_callstack_allocate_heap_frame | -1.904e+07 |  |
| MVM_repr_clone | 0.38 | 0.33 | MVM_repr_clone | -1.889e+07 |  |
| mp_xor | 0.68 | 0.63 | mp_xor | -1.862e+07 |  |
| allocate_record | 0.21 | 0.25 | allocate_record | 1.558e+07 |  |

### collector share, bad

- total cycles median: c 38379754264, f 38470716341; difference f - c 90962077 (0.24 % of c)
- spread of round medians: c 489905875, f 226766966; run-to-run spread over all 15 runs: c 15341585428, f 1013452476
- collector cycles: c 4.02 % x 38379754264 = 1542866121; f 3.90 % x 38470716341 = 1500357937; difference -42508184
- collector share = -42508184 / 90962077 = -0.467

