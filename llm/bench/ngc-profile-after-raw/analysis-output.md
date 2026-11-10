## Counters

### plain

| event | c median [round-median min-max] | f median [round-median min-max] | f/c | c runs min-max (15) | f runs min-max (15) |
|---|---:|---:|---:|---:|---:|
| cycles:u | 35897495068 [35809744758-36032590477] | 36577889225 [36467805575-36848937764] | 1.0190 | 35302497116-36160426821 | 36099171480-37063820902 |
| instructions:u | 68926715602 [68909987956-68928901449] | 69201143624 [69194034391-69210781987] | 1.0040 | 68596686163-68992434877 | 68893795481-69254297402 |
| branch-misses:u | 48817191 [48608185-49284281] | 49584603 [49375801-49585390] | 1.0157 | 47293477-61055427 | 48666225-51079928 |
| cache-misses:u | 122382349 [122329185-127573780] | 123393245 [120194850-129565505] | 1.0083 | 118369144-140413586 | 111154839-132645043 |
| L1-dcache-load-misses:u | 1127725233 [1120603805-1138872202] | 1107630364 [1084533080-1118198456] | 0.9822 | 1084222375-1304146901 | 1079446200-1155288946 |

Round medians, cycles:u: c 35897495068 35809744758 36032590477; f 36577889225 36848937764 36467805575

### bad

| event | c median [round-median min-max] | f median [round-median min-max] | f/c | c runs min-max (15) | f runs min-max (15) |
|---|---:|---:|---:|---:|---:|
| cycles:u | 38109076084 [37916942060-38139115515] | 38948294955 [38939649559-38955857374] | 1.0220 | 37736819373-40803334822 | 38715491550-40607003860 |
| instructions:u | 70920952897 [70916948383-70922337834] | 71212585707 [71157380647-71235699344] | 1.0041 | 70645004874-71066132160 | 70374415981-71302267664 |
| branch-misses:u | 51570988 [50753070-51658027] | 53665115 [52722838-54061912] | 1.0406 | 49915736-52705468 | 51985521-55926814 |
| cache-misses:u | 147171976 [144966598-151057848] | 146190368 [144419404-156751323] | 0.9933 | 136722355-166434133 | 132995807-170611114 |
| L1-dcache-load-misses:u | 1241278644 [1230561150-1257760309] | 1198263756 [1194147701-1228253203] | 0.9653 | 1202856594-1366233439 | 1181085146-1244667518 |

Round medians, cycles:u: c 37916942060 38109076084 38139115515; f 38948294955 38955857374 38939649559

## Samples: LTO, plain

### top 40, c

| # | share % | samples | dso | symbol |
|---:|---:|---:|---|---|
| 1 | 27.01 | 8631 | [JIT] | (unresolved) |
| 2 | 9.43 | 2909 | libmoar.so | compiler_rt.fastMemset |
| 3 | 5.66 | 1725 | libmoar.so | MVM_frame_dispatch |
| 4 | 3.72 | 1169 | libc.so.6 | (unresolved) |
| 5 | 3.33 | 1012 | libmoar.so | MVM_bigint_xor |
| 6 | 2.74 | 839 | libmoar.so | gc_free.2630 |
| 7 | 2.62 | 800 | libmoar.so | MVM_spesh_arg_guard_run |
| 8 | 2.49 | 760 | libmoar.so | initialize.2614 |
| 9 | 2.28 | 718 | libmoar.so | MVM_interp_run |
| 10 | 2.09 | 638 | libmoar.so | MVM_bigint_and |
| 11 | 2.06 | 628 | libmoar.so | get_boxed_ref |
| 12 | 1.71 | 524 | libmoar.so | MVM_gc_collect_free_nursery_uncopied |
| 13 | 1.56 | 479 | libmoar.so | MVM_gc_allocate_object |
| 14 | 1.48 | 460 | libmoar.so | MVM_disp_program_run |
| 15 | 1.46 | 446 | libc.so.6 | cfree |
| 16 | 1.27 | 387 | libmoar.so | initialize.2992 |
| 17 | 1.19 | 362 | libmoar.so | MVM_bigint_shr |
| 18 | 1.05 | 320 | libmoar.so | mp_clear |
| 19 | 1.03 | 317 | libmoar.so | allocate |
| 20 | 1.02 | 312 | libmoar.so | gc_cleanup |
| 21 | 1.01 | 312 | libmoar.so | MVM_callstack_unwind_frame |
| 22 | 0.85 | 261 | libmoar.so | MVM_args_set_result_obj |
| 23 | 0.77 | 240 | libmoar.so | MVM_spesh_inline |
| 24 | 0.73 | 227 | libmoar.so | mi_free |
| 25 | 0.70 | 213 | libmoar.so | MVM_VMArray_at_pos |
| 26 | 0.67 | 205 | libmoar.so | mp_clamp |
| 27 | 0.67 | 205 | libmoar.so | mp_xor |
| 28 | 0.48 | 196 | libmoar.so | incorporate_stats |
| 29 | 0.46 | 139 | libmoar.so | MVM_VMArray_push |
| 30 | 0.44 | 135 | libmoar.so | MVM_cu_string |
| 31 | 0.43 | 130 | libmoar.so | mp_div_2d |
| 32 | 0.40 | 121 | libmoar.so | copy_to.2615 |
| 33 | 0.39 | 119 | libmoar.so | set_size_internal |
| 34 | 0.35 | 105 | libmoar.so | two_complement_bitop |
| 35 | 0.35 | 108 | libmoar.so | MVM_frame_try_return |
| 36 | 0.35 | 108 | libmoar.so | MVM_string_utf8_encode_substr |
| 37 | 0.33 | 102 | libc.so.6 | __libc_calloc |
| 38 | 0.33 | 100 | libmoar.so | MVM_repr_at_pos_o |
| 39 | 0.32 | 99 | libmoar.so | MVM_callsite_mark_interns |
| 40 | 0.29 | 95 | ld-linux-x86-64.so.2 | __tls_get_addr |

Collector share of samples, c: 3.89 % (sum over 13 symbols; perf's listed total 98.17 %)

Collector symbols counted, c: MVM_gc_collect_free_nursery_uncopied 1.71, MVM_gc_allocate_object 1.56, MVM_gc_allocate_nursery 0.26, MVM_gc_root_add_frame_roots_to_worklist 0.09, process_worklist 0.08, MVM_gc_mark_collectable 0.04, MVM_gc_collect 0.04, MVM_gc_gen2_allocate 0.03, MVM_gc_mark_thread_unblocked 0.03, run_gc 0.02, MVM_gc_root_add_instance_roots_to_worklist 0.02, MVM_gc_root_add_tc_roots_to_worklist 0.01, MVM_gc_enter_from_allocator 0.00

### top 40, f

| # | share % | samples | dso | symbol |
|---:|---:|---:|---|---|
| 1 | 26.90 | 8963 | [JIT] | (unresolved) |
| 2 | 9.21 | 2950 | libmoar.so | compiler_rt.fastMemset |
| 3 | 5.97 | 1894 | libmoar.so | MVM_frame_dispatch |
| 4 | 4.02 | 1304 | libc.so.6 | (unresolved) |
| 5 | 3.22 | 1020 | libmoar.so | MVM_bigint_xor |
| 6 | 3.03 | 960 | libmoar.so | gc_free.2492 |
| 7 | 2.85 | 902 | libmoar.so | initialize.2476 |
| 8 | 2.43 | 793 | libmoar.so | MVM_interp_run |
| 9 | 2.15 | 682 | libmoar.so | MVM_spesh_arg_guard_run |
| 10 | 2.07 | 654 | libmoar.so | get_boxed_ref |
| 11 | 1.94 | 614 | libmoar.so | MVM_bigint_and |
| 12 | 1.77 | 561 | libmoar.so | gc.collect.freeNurseryUncopied |
| 13 | 1.77 | 567 | libmoar.so | gc.allocation.allocateObject |
| 14 | 1.44 | 462 | libmoar.so | MVM_disp_program_run |
| 15 | 1.36 | 431 | libc.so.6 | cfree |
| 16 | 1.32 | 417 | libmoar.so | initialize.2854 |
| 17 | 1.07 | 338 | libmoar.so | gc_cleanup |
| 18 | 1.07 | 337 | libmoar.so | MVM_bigint_shr |
| 19 | 1.05 | 336 | libmoar.so | MVM_callstack_unwind_frame |
| 20 | 0.95 | 300 | libmoar.so | mp_clear |
| 21 | 0.91 | 291 | libmoar.so | allocate |
| 22 | 0.90 | 283 | libmoar.so | mp_xor |
| 23 | 0.81 | 260 | libmoar.so | MVM_args_set_result_obj |
| 24 | 0.79 | 253 | libmoar.so | mi_free |
| 25 | 0.74 | 246 | libmoar.so | MVM_spesh_inline |
| 26 | 0.64 | 205 | libmoar.so | MVM_VMArray_at_pos |
| 27 | 0.62 | 197 | libmoar.so | mp_clamp |
| 28 | 0.44 | 192 | libmoar.so | incorporate_stats |
| 29 | 0.40 | 125 | libmoar.so | mp_div_2d |
| 30 | 0.39 | 122 | libmoar.so | MVM_VMArray_push |
| 31 | 0.38 | 120 | libmoar.so | MVM_string_utf8_encode_substr |
| 32 | 0.37 | 119 | libmoar.so | MVM_frame_try_return |
| 33 | 0.35 | 110 | libmoar.so | MVM_repr_at_pos_o |
| 34 | 0.35 | 112 | ld-linux-x86-64.so.2 | __tls_get_addr |
| 35 | 0.34 | 107 | libmoar.so | MVM_callsite_mark_interns |
| 36 | 0.33 | 106 | libmoar.so | copy_to.2477 |
| 37 | 0.33 | 105 | libmoar.so | set_size_internal |
| 38 | 0.31 | 99 | libmoar.so | MVM_cu_string |
| 39 | 0.30 | 95 | libmoar.so | two_complement_bitop |
| 40 | 0.29 | 93 | libc.so.6 | __libc_calloc |

Collector share of samples, f: 4.22 % (sum over 17 symbols; perf's listed total 98.08 %)

Collector symbols counted, f: gc.collect.freeNurseryUncopied 1.77, gc.allocation.allocateObject 1.77, MVM_gc_allocate_nursery 0.25, gc.collect.processWorklist 0.11, MVM_gc_allocate_object 0.10, gc.roots.addFrameRootsToWorklist 0.06, gc.roots.addFrameRegistersToWorklist 0.05, gc.gen2.allocate 0.03, gc.orchestrate.markThreadUnblocked 0.02, gc.collect.markCollectable 0.02, gc.orchestrate.runGc 0.01, gc.allocation.allocateTypeObject 0.01, gc.roots.addInstanceRootsToWorklist 0.01, gc.roots.addPermanentsToWorklist 0.01, gc.finalize.walkThreadFinalizeQueue 0.00, gc.collect.addInTrayToWorklist 0.00, gc.allocation.allocateStable 0.00

### aligned delta, top 40 by |delta| (cycles = share x median total cycles of the side)

| key (C name) | c % | f % | f names | delta cycles (f - c) | collector |
|---|---:|---:|---|---:|---|
| allocate_object | 0.00 | 1.77 | gc.allocation.allocateObject | 6.474e+08 | gc |
| free_nursery_uncopied | 0.00 | 1.77 | gc.collect.freeNurseryUncopied | 6.474e+08 | gc |
| MVM_gc_collect_free_nursery_uncopied | 1.71 | 0.00 |  | -6.138e+08 | gc |
| MVM_gc_allocate_object | 1.56 | 0.10 | MVM_gc_allocate_object | -5.234e+08 | gc |
| initialize | 3.76 | 4.17 | initialize.2476 initialize.2854 initialize.3647 | 1.756e+08 |  |
| MVM_spesh_arg_guard_run | 2.62 | 2.15 | MVM_spesh_arg_guard_run | -1.541e+08 |  |
| MVM_frame_dispatch | 5.66 | 5.97 | MVM_frame_dispatch | 1.519e+08 |  |
| [JIT] (unresolved) | 27.01 | 26.90 | (unresolved) | 1.435e+08 |  |
| gc_free | 2.84 | 3.17 | gc_free.2297 gc_free.2364 gc_free.2492 gc_free.2578 gc_free.... | 1.400e+08 |  |
| libc.so.6 (unresolved) | 3.72 | 4.02 | (unresolved) | 1.350e+08 |  |
| mp_xor | 0.67 | 0.90 | mp_xor | 8.869e+07 |  |
| MVM_interp_run | 2.28 | 2.43 | MVM_interp_run | 7.038e+07 |  |
| MVM_cu_string | 0.44 | 0.31 | MVM_cu_string | -4.456e+07 |  |
| MVM_bigint_and | 2.09 | 1.94 | MVM_bigint_and | -4.065e+07 |  |
| MVM_bigint_shr | 1.19 | 1.07 | MVM_bigint_shr | -3.580e+07 |  |
| MVM_gc_root_add_frame_roots_to_worklist | 0.09 | 0.00 |  | -3.231e+07 | gc |
| mp_clear | 1.05 | 0.95 | mp_clear | -2.943e+07 |  |
| mi_free | 0.73 | 0.79 | mi_free | 2.691e+07 |  |
| libc.so.6 cfree | 1.46 | 1.36 | cfree | -2.664e+07 |  |
| allocate | 1.03 | 0.94 | allocate gc.gen2.allocate | -2.591e+07 | gc |
| gc_cleanup | 1.02 | 1.07 | gc_cleanup | 2.523e+07 |  |
| ld-linux-x86-64.so.2 __tls_get_addr | 0.29 | 0.35 | __tls_get_addr | 2.392e+07 |  |
| MVM_repr_clone | 0.27 | 0.20 | MVM_repr_clone | -2.377e+07 |  |
| set_uint | 0.26 | 0.32 | set_uint set_uint.2652 set_uint.2858 | 2.372e+07 |  |
| allocate_record | 0.28 | 0.21 | allocate_record | -2.370e+07 |  |
| copy_to | 0.42 | 0.35 | copy_to.2456 copy_to.2477 copy_to.2575 | -2.275e+07 |  |
| dispatch_polymorphic | 0.08 | 0.14 | dispatch_polymorphic | 2.249e+07 |  |
| MVM_VMArray_push | 0.46 | 0.39 | MVM_VMArray_push | -2.247e+07 |  |
| bind_attribute | 0.05 | 0.11 | bind_attribute | 2.229e+07 |  |
| add_frame_roots_to_worklist | 0.00 | 0.06 | gc.roots.addFrameRootsToWorklist | 2.195e+07 | gc |
| MVM_callstack_unwind_frame | 1.01 | 1.05 | MVM_callstack_unwind_frame | 2.150e+07 |  |
| MVM_callstack_allocate_heap_frame | 0.19 | 0.13 | MVM_callstack_allocate_heap_frame | -2.065e+07 |  |
| mi_free@plt | 0.25 | 0.19 | mi_free@plt | -2.025e+07 |  |
| MVM_frame_takeclosure | 0.25 | 0.19 | MVM_frame_takeclosure | -2.025e+07 |  |
| core.hash.tiers.small.ImplType(64,core.hash.str.StrSpec).find | 0.28 | 0.22 | core.hash.tiers.small.ImplType(64,core.hash.str.StrSpec).find | -2.004e+07 |  |
| MVM_string_ci_get_codepoint | 0.28 | 0.22 | MVM_string_ci_get_codepoint.5077 | -2.004e+07 |  |
| set_size_internal | 0.39 | 0.33 | set_size_internal | -1.929e+07 |  |
| MVM_reentrantmutex_lock_checked | 0.09 | 0.14 | MVM_reentrantmutex_lock_checked | 1.890e+07 |  |
| MVM_args_bind_succeeded | 0.04 | 0.09 | MVM_args_bind_succeeded | 1.856e+07 |  |
| MVM_reentrantmutex_unlock_checked | 0.04 | 0.09 | MVM_reentrantmutex_unlock_checked | 1.856e+07 |  |

### collector share, plain

- total cycles median: c 35897495068, f 36577889225; difference f - c 680394157 (1.90 % of c)
- spread of round medians: c 222845719, f 381132189; run-to-run spread over all 15 runs: c 857929705, f 964649422
- collector cycles: c 3.89 % x 35897495068 = 1396412558; f 4.22 % x 36577889225 = 1543586925; difference 147174367
- collector share = 147174367 / 680394157 = 0.216

## Samples: LTO, bad

### top 40, c

| # | share % | samples | dso | symbol |
|---:|---:|---:|---|---|
| 1 | 26.90 | 9286 | [JIT] | (unresolved) |
| 2 | 9.23 | 3058 | libmoar.so | compiler_rt.fastMemset |
| 3 | 6.64 | 2182 | libmoar.so | MVM_frame_dispatch |
| 4 | 4.10 | 1400 | libc.so.6 | (unresolved) |
| 5 | 2.81 | 922 | libmoar.so | MVM_bigint_xor |
| 6 | 2.64 | 869 | libmoar.so | gc_free.2630 |
| 7 | 2.53 | 849 | libmoar.so | MVM_interp_run |
| 8 | 2.52 | 829 | libmoar.so | MVM_spesh_arg_guard_run |
| 9 | 2.25 | 738 | libmoar.so | initialize.2614 |
| 10 | 2.10 | 687 | libmoar.so | get_boxed_ref |
| 11 | 1.97 | 646 | libmoar.so | MVM_bigint_and |
| 12 | 1.68 | 556 | libmoar.so | MVM_gc_allocate_object |
| 13 | 1.68 | 554 | libmoar.so | MVM_gc_collect_free_nursery_uncopied |
| 14 | 1.48 | 486 | libc.so.6 | cfree |
| 15 | 1.34 | 444 | libmoar.so | MVM_disp_program_run |
| 16 | 1.20 | 394 | libmoar.so | initialize.2992 |
| 17 | 1.10 | 360 | libmoar.so | MVM_bigint_shr |
| 18 | 1.04 | 340 | libmoar.so | mp_clear |
| 19 | 1.00 | 331 | libmoar.so | MVM_callstack_unwind_frame |
| 20 | 0.93 | 305 | libmoar.so | gc_cleanup |
| 21 | 0.91 | 300 | libmoar.so | MVM_args_set_result_obj |
| 22 | 0.88 | 289 | libmoar.so | allocate |
| 23 | 0.82 | 271 | libmoar.so | mi_free |
| 24 | 0.73 | 254 | libmoar.so | MVM_spesh_inline |
| 25 | 0.69 | 226 | libmoar.so | MVM_VMArray_at_pos |
| 26 | 0.59 | 194 | libmoar.so | mp_xor |
| 27 | 0.50 | 164 | libmoar.so | mp_clamp |
| 28 | 0.48 | 206 | libmoar.so | incorporate_stats |
| 29 | 0.45 | 148 | libmoar.so | copy_to.2615 |
| 30 | 0.43 | 140 | libmoar.so | mp_div_2d |
| 31 | 0.42 | 139 | libmoar.so | MVM_VMArray_push |
| 32 | 0.40 | 132 | libmoar.so | MVM_frame_try_return |
| 33 | 0.38 | 126 | libmoar.so | set_size_internal |
| 34 | 0.38 | 125 | libmoar.so | exit_heap_frame |
| 35 | 0.37 | 121 | libmoar.so | MVM_string_utf8_encode_substr |
| 36 | 0.35 | 116 | libmoar.so | search_for_handler_from |
| 37 | 0.33 | 110 | libmoar.so | MVM_gc_allocate_nursery |
| 38 | 0.32 | 104 | libmoar.so | MVM_repr_at_pos_o |
| 39 | 0.31 | 102 | libmoar.so | core.hash.tiers.small.ImplType(64,core.hash.str.StrSpec).find |
| 40 | 0.31 | 102 | libmoar.so | MVM_repr_box_uint |

Collector share of samples, c: 4.07 % (sum over 17 symbols; perf's listed total 98.15 %)

Collector symbols counted, c: MVM_gc_allocate_object 1.68, MVM_gc_collect_free_nursery_uncopied 1.68, MVM_gc_allocate_nursery 0.33, MVM_gc_root_add_frame_roots_to_worklist 0.14, process_worklist 0.08, MVM_gc_mark_thread_unblocked 0.04, run_gc 0.04, MVM_gc_mark_collectable 0.03, MVM_gc_collect 0.02, MVM_gc_root_add_instance_roots_to_worklist 0.01, MVM_gc_root_add_tc_roots_to_worklist 0.01, MVM_gc_gen2_allocate 0.01, MVM_gc_object_id 0.00, MVM_gc_allocate_stable 0.00, MVM_gc_root_gen2_add 0.00, MVM_gc_enter_from_allocator 0.00, MVM_gc_worklist_presize_for 0.00

### top 40, f

| # | share % | samples | dso | symbol |
|---:|---:|---:|---|---|
| 1 | 26.92 | 9473 | [JIT] | (unresolved) |
| 2 | 9.11 | 3072 | libmoar.so | compiler_rt.fastMemset |
| 3 | 6.99 | 2325 | libmoar.so | MVM_frame_dispatch |
| 4 | 4.62 | 1561 | libc.so.6 | (unresolved) |
| 5 | 3.20 | 1067 | libmoar.so | gc_free.2492 |
| 6 | 3.04 | 1010 | libmoar.so | MVM_bigint_xor |
| 7 | 2.45 | 812 | libmoar.so | initialize.2476 |
| 8 | 2.28 | 780 | libmoar.so | MVM_interp_run |
| 9 | 2.17 | 722 | libmoar.so | MVM_spesh_arg_guard_run |
| 10 | 1.92 | 638 | libmoar.so | get_boxed_ref |
| 11 | 1.90 | 630 | libmoar.so | MVM_bigint_and |
| 12 | 1.80 | 600 | libmoar.so | gc.collect.freeNurseryUncopied |
| 13 | 1.60 | 535 | libmoar.so | gc.allocation.allocateObject |
| 14 | 1.34 | 454 | libmoar.so | MVM_disp_program_run |
| 15 | 1.26 | 419 | libc.so.6 | cfree |
| 16 | 1.17 | 389 | libmoar.so | initialize.2854 |
| 17 | 1.04 | 347 | libmoar.so | gc_cleanup |
| 18 | 0.95 | 316 | libmoar.so | MVM_bigint_shr |
| 19 | 0.95 | 317 | libmoar.so | MVM_callstack_unwind_frame |
| 20 | 0.89 | 298 | libmoar.so | mp_clear |
| 21 | 0.88 | 292 | libmoar.so | allocate |
| 22 | 0.83 | 275 | libmoar.so | MVM_args_set_result_obj |
| 23 | 0.73 | 246 | libmoar.so | mi_free |
| 24 | 0.70 | 233 | libmoar.so | MVM_VMArray_at_pos |
| 25 | 0.62 | 206 | libmoar.so | mp_clamp |
| 26 | 0.49 | 164 | libmoar.so | MVM_string_utf8_encode_substr |
| 27 | 0.49 | 163 | libmoar.so | mp_xor |
| 28 | 0.48 | 163 | ld-linux-x86-64.so.2 | __tls_get_addr |
| 29 | 0.45 | 149 | libmoar.so | set_size_internal |
| 30 | 0.45 | 151 | libmoar.so | MVM_cu_string |
| 31 | 0.44 | 206 | libmoar.so | incorporate_stats |
| 32 | 0.41 | 135 | libc.so.6 | __libc_calloc |
| 33 | 0.37 | 124 | libmoar.so | copy_to.2477 |
| 34 | 0.37 | 123 | libmoar.so | MVM_VMArray_push |
| 35 | 0.36 | 120 | libmoar.so | mp_div_2d |
| 36 | 0.33 | 111 | libmoar.so | MVM_frame_try_return |
| 37 | 0.33 | 111 | libmoar.so | MVM_repr_at_pos_o |
| 38 | 0.33 | 111 | libmoar.so | exit_heap_frame |
| 39 | 0.31 | 103 | libmoar.so | search_for_handler_from |
| 40 | 0.29 | 99 | libmoar.so | core.hash.tiers.small.ImplType(64,core.hash.str.StrSpec).find |

Collector share of samples, f: 4.10 % (sum over 15 symbols; perf's listed total 97.92 %)

Collector symbols counted, f: gc.collect.freeNurseryUncopied 1.80, gc.allocation.allocateObject 1.60, MVM_gc_allocate_nursery 0.28, MVM_gc_allocate_object 0.12, gc.collect.processWorklist 0.09, gc.roots.addFrameRootsToWorklist 0.07, gc.orchestrate.runGc 0.04, gc.roots.addFrameRegistersToWorklist 0.04, gc.gen2.allocate 0.02, gc.roots.addPermanentsToWorklist 0.02, gc.collect.markCollectable 0.01, gc.orchestrate.markThreadUnblocked 0.01, MVM_gc_write_barrier_hit_by 0.00, gc.roots.addTempsToWorklist 0.00, gc.roots.addInstanceRootsToWorklist 0.00

### aligned delta, top 40 by |delta| (cycles = share x median total cycles of the side)

| key (C name) | c % | f % | f names | delta cycles (f - c) | collector |
|---|---:|---:|---|---:|---|
| free_nursery_uncopied | 0.00 | 1.80 | gc.collect.freeNurseryUncopied | 7.011e+08 | gc |
| MVM_gc_collect_free_nursery_uncopied | 1.68 | 0.00 |  | -6.402e+08 | gc |
| allocate_object | 0.00 | 1.60 | gc.allocation.allocateObject | 6.232e+08 | gc |
| MVM_gc_allocate_object | 1.68 | 0.12 | MVM_gc_allocate_object | -5.935e+08 | gc |
| MVM_spesh_inline | 0.73 | 0.10 | MVM_spesh_inline | -2.392e+08 |  |
| libc.so.6 (unresolved) | 4.10 | 4.62 | (unresolved) | 2.369e+08 |  |
| [JIT] (unresolved) | 26.90 | 26.92 | (unresolved) | 2.335e+08 |  |
| gc_free | 2.80 | 3.27 | gc_free.2297 gc_free.2364 gc_free.2412 gc_free.2492 gc_free.... | 2.066e+08 |  |
| MVM_frame_dispatch | 6.64 | 6.99 | MVM_frame_dispatch | 1.920e+08 |  |
| MVM_spesh_arg_guard_run | 2.52 | 2.17 | MVM_spesh_arg_guard_run | -1.152e+08 |  |
| MVM_bigint_xor | 2.81 | 3.04 | MVM_bigint_xor | 1.132e+08 |  |
| initialize | 3.45 | 3.62 | initialize.2476 initialize.2854 | 9.517e+07 |  |
| ld-linux-x86-64.so.2 __tls_get_addr | 0.29 | 0.48 | __tls_get_addr | 7.644e+07 |  |
| MVM_cu_string | 0.26 | 0.45 | MVM_cu_string | 7.618e+07 |  |
| MVM_interp_run | 2.53 | 2.28 | MVM_interp_run | -7.614e+07 |  |
| libc.so.6 cfree | 1.48 | 1.26 | cfree | -7.327e+07 |  |
| MVM_args_set_result_int | 0.05 | 0.19 | MVM_args_set_result_int | 5.495e+07 |  |
| MVM_gc_root_add_frame_roots_to_worklist | 0.14 | 0.00 |  | -5.335e+07 | gc |
| get_boxed_ref | 2.10 | 1.92 | get_boxed_ref | -5.248e+07 |  |
| mp_clamp | 0.50 | 0.62 | mp_clamp | 5.093e+07 |  |
| gc_cleanup | 0.93 | 1.04 | gc_cleanup | 5.065e+07 |  |
| MVM_string_utf8_encode_substr | 0.37 | 0.49 | MVM_string_utf8_encode_substr | 4.984e+07 |  |
| mp_clear | 1.04 | 0.89 | mp_clear | -4.969e+07 |  |
| MVM_bigint_shr | 1.10 | 0.95 | MVM_bigint_shr | -4.919e+07 |  |
| libc.so.6 __libc_calloc | 0.29 | 0.41 | __libc_calloc | 4.917e+07 |  |
| two_complement_bitop | 0.30 | 0.19 | two_complement_bitop | -4.033e+07 |  |
| mp_xor | 0.59 | 0.49 | mp_xor | -3.400e+07 |  |
| value_desc_cont_fetch | 0.03 | 0.11 | value_desc_cont_fetch | 3.141e+07 |  |
| copy_to | 0.50 | 0.41 | copy_to.2362 copy_to.2477 copy_to.2575 | -3.086e+07 |  |
| compiler_rt.fastMemset | 9.23 | 9.11 | compiler_rt.fastMemset | 3.072e+07 |  |
| set_size_internal | 0.38 | 0.45 | set_size_internal | 3.045e+07 |  |
| MVM_callstack_allocate_heap_frame | 0.23 | 0.15 | MVM_callstack_allocate_heap_frame | -2.923e+07 |  |
| mi_free | 0.82 | 0.73 | mi_free | -2.817e+07 |  |
| add_frame_roots_to_worklist | 0.00 | 0.07 | gc.roots.addFrameRootsToWorklist | 2.726e+07 | gc |
| MVM_frame_try_return | 0.40 | 0.33 | MVM_frame_try_return | -2.391e+07 |  |
| mp_div_2d | 0.43 | 0.36 | mp_div_2d | -2.366e+07 |  |
| MVM_args_set_result_obj | 0.91 | 0.83 | MVM_args_set_result_obj | -2.352e+07 |  |
| MVM_callsite_mark_interns | 0.24 | 0.29 | MVM_callsite_mark_interns | 2.149e+07 |  |
| mi_free@plt | 0.25 | 0.19 | mi_free@plt | -2.127e+07 |  |
| bind_attribute | 0.11 | 0.06 | bind_attribute | -1.855e+07 |  |

### collector share, bad

- total cycles median: c 38109076084, f 38948294955; difference f - c 839218871 (2.20 % of c)
- spread of round medians: c 222173455, f 16207815; run-to-run spread over all 15 runs: c 3066515449, f 1891512310
- collector cycles: c 4.07 % x 38109076084 = 1551039397; f 4.10 % x 38948294955 = 1596880093; difference 45840697
- collector share = 45840697 / 839218871 = 0.055

## Samples: non-LTO (attribution only, a different binary)

### top 40, c

| # | share % | samples | dso | symbol |
|---:|---:|---:|---|---|
| 1 | 27.49 | 9097 | [JIT] | (unresolved) |
| 2 | 9.37 | 2986 | libmoar.so | compiler_rt.fastMemset |
| 3 | 3.79 | 1228 | libc.so.6 | (unresolved) |
| 4 | 3.50 | 1104 | libmoar.so | initialize |
| 5 | 3.43 | 1085 | libmoar.so | MVM_frame_dispatch |
| 6 | 2.79 | 879 | libmoar.so | gc_free |
| 7 | 2.39 | 761 | libmoar.so | mi_calloc |
| 8 | 2.31 | 726 | libmoar.so | get_boxed_ref |
| 9 | 2.30 | 726 | libmoar.so | MVM_spesh_arg_guard_run |
| 10 | 2.20 | 697 | libmoar.so | MVM_interp_run |
| 11 | 2.02 | 640 | libmoar.so | mi_malloc |
| 12 | 1.63 | 513 | libmoar.so | MVM_bigint_xor |
| 13 | 1.62 | 514 | libmoar.so | MVM_gc_collect_free_nursery_uncopied |
| 14 | 1.56 | 494 | libmoar.so | MVM_gc_allocate_object |
| 15 | 1.56 | 495 | libmoar.so | MVM_disp_program_run |
| 16 | 1.47 | 464 | libmoar.so | MVM_repr_alloc_init |
| 17 | 1.45 | 458 | libc.so.6 | cfree |
| 18 | 1.15 | 365 | libmoar.so | mp_clear |
| 19 | 1.05 | 331 | libmoar.so | MVM_callstack_unwind_frame |
| 20 | 1.02 | 323 | libmoar.so | gc_cleanup |
| 21 | 0.89 | 279 | libmoar.so | MVM_bigint_and |
| 22 | 0.82 | 257 | libmoar.so | mp_xor |
| 23 | 0.80 | 253 | libmoar.so | MVM_args_set_result_obj |
| 24 | 0.78 | 248 | libmoar.so | MVM_VMArray_at_pos |
| 25 | 0.76 | 240 | libmoar.so | allocate |
| 26 | 0.73 | 238 | libmoar.so | MVM_spesh_inline |
| 27 | 0.69 | 218 | libmoar.so | mi_free |
| 28 | 0.60 | 188 | libmoar.so | mp_clamp |
| 29 | 0.41 | 170 | libmoar.so | incorporate_stats |
| 30 | 0.39 | 124 | libmoar.so | MVM_cu_string |
| 31 | 0.39 | 123 | libmoar.so | MVM_bigint_shr |
| 32 | 0.38 | 119 | libmoar.so | exit_heap_frame |
| 33 | 0.37 | 118 | libmoar.so | MVM_frame_try_return |
| 34 | 0.36 | 113 | libmoar.so | copy_to |
| 35 | 0.36 | 112 | libmoar.so | two_complement_bitop |
| 36 | 0.36 | 112 | libmoar.so | set_uint |
| 37 | 0.34 | 108 | libmoar.so | MVM_VMArray_push |
| 38 | 0.34 | 106 | libmoar.so | mp_div_2d |
| 39 | 0.34 | 107 | libmoar.so | core.hash.tiers.small.ImplType(64,core.hash.str.StrSpec).find |
| 40 | 0.33 | 104 | libmoar.so | MVM_str_hash_fetch |

Collector share of samples, c: 3.87 % (sum over 19 symbols; perf's listed total 98.29 %)

Collector symbols counted, c: MVM_gc_collect_free_nursery_uncopied 1.62, MVM_gc_allocate_object 1.56, MVM_gc_allocate_nursery 0.28, MVM_gc_root_add_frame_roots_to_worklist 0.10, process_worklist 0.06, MVM_gc_allocate_frame 0.04, MVM_gc_write_barrier_hit_by@plt 0.03, MVM_gc_mark_collectable 0.03, MVM_gc_gen2_allocate 0.03, MVM_gc_mark_thread_unblocked 0.02, run_gc 0.02, MVM_gc_root_add_permanents_to_worklist 0.02, MVM_gc_collect 0.01, MVM_gc_mark_thread_blocked 0.01, MVM_gc_write_barrier_hit_by 0.01, MVM_gc_root_add_instance_roots_to_worklist 0.01, MVM_gc_enter_from_allocator 0.01, MVM_gc_root_add_temps_to_worklist 0.01, MVM_gc_root_add_gen2s_to_worklist 0.00

### top 40, f

| # | share % | samples | dso | symbol |
|---:|---:|---:|---|---|
| 1 | 26.82 | 8875 | [JIT] | (unresolved) |
| 2 | 9.11 | 2934 | libmoar.so | compiler_rt.fastMemset |
| 3 | 4.20 | 1338 | libmoar.so | initialize |
| 4 | 3.37 | 1095 | libc.so.6 | (unresolved) |
| 5 | 3.19 | 1022 | libmoar.so | gc_free |
| 6 | 2.97 | 948 | libmoar.so | MVM_frame_dispatch |
| 7 | 2.44 | 777 | libmoar.so | get_boxed_ref |
| 8 | 2.43 | 785 | libmoar.so | mi_calloc |
| 9 | 2.32 | 741 | libmoar.so | MVM_spesh_arg_guard_run |
| 10 | 2.25 | 738 | libmoar.so | MVM_interp_run |
| 11 | 2.05 | 657 | libmoar.so | mi_malloc |
| 12 | 1.96 | 625 | libmoar.so | MVM_repr_alloc_init |
| 13 | 1.74 | 556 | libmoar.so | gc.collect.freeNurseryUncopied |
| 14 | 1.53 | 486 | libmoar.so | MVM_bigint_xor |
| 15 | 1.41 | 456 | libmoar.so | MVM_disp_program_run |
| 16 | 1.39 | 443 | libc.so.6 | cfree |
| 17 | 1.36 | 437 | libmoar.so | gc.allocation.allocateObject |
| 18 | 1.14 | 363 | libmoar.so | gc_cleanup |
| 19 | 1.09 | 347 | libmoar.so | mp_clear |
| 20 | 0.88 | 282 | libmoar.so | allocate |
| 21 | 0.87 | 279 | libmoar.so | MVM_bigint_and |
| 22 | 0.84 | 267 | libmoar.so | MVM_callstack_unwind_frame |
| 23 | 0.78 | 249 | libmoar.so | MVM_args_set_result_obj |
| 24 | 0.78 | 249 | libmoar.so | mp_xor |
| 25 | 0.74 | 235 | libmoar.so | MVM_VMArray_at_pos |
| 26 | 0.74 | 240 | libmoar.so | mi_free |
| 27 | 0.69 | 225 | libmoar.so | MVM_spesh_inline |
| 28 | 0.67 | 214 | libmoar.so | MVM_gc_allocate_nursery |
| 29 | 0.65 | 206 | libmoar.so | mp_clamp |
| 30 | 0.43 | 136 | libmoar.so | MVM_VMArray_push |
| 31 | 0.42 | 177 | libmoar.so | incorporate_stats |
| 32 | 0.40 | 128 | libmoar.so | MVM_bigint_shr |
| 33 | 0.37 | 117 | libmoar.so | MVM_string_utf8_encode_substr |
| 34 | 0.36 | 116 | libmoar.so | MVM_cu_string |
| 35 | 0.35 | 113 | libmoar.so | copy_to |
| 36 | 0.34 | 107 | libmoar.so | set_uint |
| 37 | 0.34 | 107 | libmoar.so | mp_div_2d |
| 38 | 0.34 | 110 | libmoar.so | MVM_repr_at_pos_o |
| 39 | 0.33 | 106 | libmoar.so | MVM_frame_try_return |
| 40 | 0.29 | 93 | libmoar.so | core.hash.tiers.small.ImplType(64,core.hash.str.StrSpec).find |

Collector share of samples, f: 4.35 % (sum over 24 symbols; perf's listed total 98.42 %)

Collector symbols counted, f: gc.collect.freeNurseryUncopied 1.74, gc.allocation.allocateObject 1.36, MVM_gc_allocate_nursery 0.67, MVM_gc_allocate_object 0.11, gc.collect.processWorklist 0.10, gc.roots.addFrameRootsToWorklist 0.07, gc.collect.markCollectable 0.04, MVM_gc_mark_thread_blocked 0.03, gc.gen2.allocate 0.03, gc.orchestrate.markThreadUnblocked 0.03, MVM_gc_allocate_frame 0.03, MVM_gc_write_barrier_hit_by@plt 0.02, MVM_gc_allocate_nursery@plt 0.02, gc.roots.addFrameRegistersToWorklist 0.02, gc.collect.collect 0.01, gc.roots.addInstanceRootsToWorklist 0.01, MVM_gc_write_barrier_hit_by 0.01, gc.orchestrate.runGc 0.01, MVM_gc_mark_thread_blocked@plt 0.01, gc.roots.addTempsToWorklist 0.01, MVM_gc_gen2_allocate_zeroed 0.01, gc.orchestrate.enterFromAllocator 0.01, gc.finalize.walkThreadFinalizeQueue 0.00, gc.roots.addTcRootsToWorklist 0.00

### aligned delta, top 40 by |delta| (share points)

| key (C name) | c % | f % | f names | delta points | collector |
|---|---:|---:|---|---:|---|
| free_nursery_uncopied | 0.00 | 1.74 | gc.collect.freeNurseryUncopied | +1.74 | gc |
| MVM_gc_collect_free_nursery_uncopied | 1.62 | 0.00 |  | -1.62 | gc |
| MVM_gc_allocate_object | 1.56 | 0.11 | MVM_gc_allocate_object | -1.45 | gc |
| allocate_object | 0.00 | 1.36 | gc.allocation.allocateObject | +1.36 | gc |
| initialize | 3.50 | 4.20 | initialize | +0.70 |  |
| [JIT] (unresolved) | 27.49 | 26.82 | (unresolved) | -0.67 |  |
| MVM_repr_alloc_init | 1.47 | 1.96 | MVM_repr_alloc_init | +0.49 |  |
| MVM_frame_dispatch | 3.43 | 2.97 | MVM_frame_dispatch | -0.46 |  |
| libc.so.6 (unresolved) | 3.79 | 3.37 | (unresolved) | -0.42 |  |
| gc_free | 2.79 | 3.19 | gc_free | +0.40 |  |
| MVM_gc_allocate_nursery | 0.28 | 0.67 | MVM_gc_allocate_nursery | +0.39 | gc |
| compiler_rt.fastMemset | 9.37 | 9.11 | compiler_rt.fastMemset | -0.26 |  |
| MVM_callstack_unwind_frame | 1.05 | 0.84 | MVM_callstack_unwind_frame | -0.21 |  |
| MVM_disp_program_run | 1.56 | 1.41 | MVM_disp_program_run | -0.15 |  |
| MVM_str_hash_fetch | 0.33 | 0.18 | MVM_str_hash_fetch | -0.15 |  |
| allocate | 0.76 | 0.91 | allocate gc.gen2.allocate | +0.15 | gc |
| exit_heap_frame | 0.38 | 0.24 | exit_heap_frame | -0.14 |  |
| get_boxed_ref | 2.31 | 2.44 | get_boxed_ref | +0.13 |  |
| MVM_string_utf8_encode_substr | 0.25 | 0.37 | MVM_string_utf8_encode_substr | +0.12 |  |
| gc_cleanup | 1.02 | 1.14 | gc_cleanup | +0.12 |  |
| MVM_gc_root_add_frame_roots_to_worklist | 0.10 | 0.00 |  | -0.10 | gc |
| MVM_bigint_xor | 1.63 | 1.53 | MVM_bigint_xor | -0.10 |  |
| mp_init | 0.09 | 0.18 | mp_init | +0.09 |  |
| MVM_VMArray_push | 0.34 | 0.43 | MVM_VMArray_push | +0.09 |  |
| MVM_sc_get_object | 0.19 | 0.11 | MVM_sc_get_object | -0.08 |  |
| two_complement_bitop | 0.36 | 0.29 | two_complement_bitop | -0.07 |  |
| add_frame_roots_to_worklist | 0.00 | 0.07 | gc.roots.addFrameRootsToWorklist | +0.07 | gc |
| MVM_jit_code_trampoline | 0.11 | 0.18 | MVM_jit_code_trampoline | +0.07 |  |
| libc.so.6 cfree | 1.45 | 1.39 | cfree | -0.06 |  |
| allocate_record | 0.29 | 0.23 | allocate_record | -0.06 |  |
| mp_clear | 1.15 | 1.09 | mp_clear | -0.06 |  |
| mi_free | 0.69 | 0.74 | mi_free | +0.05 |  |
| core.hash.tiers.small.ImplType(64,core.hash.str.StrSpec).find | 0.34 | 0.29 | core.hash.tiers.small.ImplType(64,core.hash.str.StrSpec).find | -0.05 |  |
| MVM_repr_at_pos_o | 0.29 | 0.34 | MVM_repr_at_pos_o | +0.05 |  |
| mp_clamp | 0.60 | 0.65 | mp_clamp | +0.05 |  |
| MVM_string_get_grapheme_at_nocheck | 0.12 | 0.17 | MVM_string_get_grapheme_at_nocheck | +0.05 |  |
| dispatch_monomorphic | 0.28 | 0.23 | dispatch_monomorphic | -0.05 |  |
| elems | 0.05 | 0.00 | elems | -0.05 |  |
| MVM_string_encode_to_buf_config | 0.04 | 0.09 | MVM_string_encode_to_buf_config | +0.05 |  |
| get_int | 0.22 | 0.17 | get_int | -0.05 |  |

