## Counters

### plain

| event | c median [round-median min-max] | f median [round-median min-max] | f/c | c runs min-max (15) | f runs min-max (15) |
|---|---:|---:|---:|---:|---:|
| cycles:u | 35527891606 [35383237665-35547590081] | 37017096437 [36954975837-37396141875] | 1.0419 | 35091686431-35924225030 | 36650070950-37757010672 |
| instructions:u | 68896244986 [68893561275-68904054451] | 69589523829 [69441335107-69598735286] | 1.0101 | 68577836258-69050522172 | 69172737403-69610710303 |
| branch-misses:u | 48565860 [48413195-49060819] | 48889564 [48753481-49053814] | 1.0067 | 46906373-51672144 | 47482757-50838344 |
| cache-misses:u | 130289415 [130047785-130502899] | 129059552 [127474634-133052907] | 0.9906 | 124022356-165027884 | 119043370-151321078 |
| L1-dcache-load-misses:u | 1104520995 [1101542045-1109093013] | 1110353175 [1102865693-1121737351] | 1.0053 | 1070574168-1148755756 | 1090693699-1305234797 |

Round medians, cycles:u: c 35527891606 35547590081 35383237665; f 36954975837 37017096437 37396141875

### bad

| event | c median [round-median min-max] | f median [round-median min-max] | f/c | c runs min-max (15) | f runs min-max (15) |
|---|---:|---:|---:|---:|---:|
| cycles:u | 37803121150 [37738629592-37948962299] | 39618532654 [39491249122-40420980136] | 1.0480 | 37324957502-38369092038 | 38805290827-41147179487 |
| instructions:u | 70926799873 [70920235611-70931510683] | 71610845585 [71596328139-71620286675] | 1.0096 | 70582119383-70963778112 | 71287560904-71634793621 |
| branch-misses:u | 52039725 [51700001-52633260] | 51859961 [51549248-52990080] | 0.9965 | 50244570-53904772 | 50431124-56509079 |
| cache-misses:u | 155453085 [150726035-157073643] | 154810461 [149640893-155765258] | 0.9959 | 141617735-168209773 | 142817144-171130480 |
| L1-dcache-load-misses:u | 1214248850 [1214204730-1225048914] | 1212195310 [1206065066-1243476246] | 0.9983 | 1191443540-1296409463 | 1189000511-1302710322 |

Round medians, cycles:u: c 37803121150 37738629592 37948962299; f 39618532654 39491249122 40420980136

## Samples: LTO, plain

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

Collector share of samples, c: 4.15 % (sum over 15 symbols; perf's listed total 97.90 %)

Collector symbols counted, c: MVM_gc_collect_free_nursery_uncopied 1.94, MVM_gc_allocate_object 1.56, MVM_gc_allocate_nursery 0.32, MVM_gc_root_add_frame_roots_to_worklist 0.13, process_worklist 0.05, MVM_gc_mark_thread_unblocked 0.03, MVM_gc_gen2_allocate 0.03, MVM_gc_collect 0.03, run_gc 0.02, MVM_gc_mark_collectable 0.02, MVM_gc_root_add_instance_roots_to_worklist 0.01, MVM_gc_root_gen2_add 0.01, MVM_gc_root_add_tc_roots_to_worklist 0.00, MVM_gc_allocate_stable 0.00, MVM_gc_enter_from_allocator 0.00

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

Collector share of samples, f: 4.84 % (sum over 18 symbols; perf's listed total 98.22 %)

Collector symbols counted, f: MVM_gc_collect_free_nursery_uncopied 1.66, MVM_gc_allocate_object 1.41, gc.collect.processWorklist 0.74, moar_c.MVM_gc_root_temp_push 0.48, MVM_gc_allocate_nursery 0.32, MVM_gc_root_add_frame_roots_to_worklist 0.07, MVM_gc_root_add_frame_registers_to_worklist 0.05, MVM_gc_mark_collectable 0.03, MVM_gc_gen2_allocate 0.02, MVM_gc_root_add_permanents_to_worklist 0.02, gc.orchestrate.runGc 0.01, MVM_gc_root_add_instance_roots_to_worklist 0.01, MVM_gc_root_add_tc_roots_to_worklist 0.01, MVM_gc_mark_thread_unblocked 0.01, gc.collect.addInTrayToWorklist 0.00, MVM_gc_root_add_gen2s_to_worklist 0.00, MVM_gc_enter_from_allocator 0.00, MVM_gc_allocate_stable 0.00

### aligned delta, top 40 by |delta| (cycles = share x median total cycles of the side)

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
| mp_set_i64 | 0.18 | 0.25 | mp_set_i64 | 2.859e+07 |  |
| mp_copy | 0.12 | 0.19 | mp_copy | 2.770e+07 |  |
| compiler_rt.memcpy.memcpyFast | 0.10 | 0.17 | compiler_rt.memcpy.memcpyFast | 2.740e+07 |  |
| gc_cleanup | 1.08 | 1.11 | gc_cleanup | 2.719e+07 |  |
| MVM_args_set_result_int | 0.07 | 0.14 | MVM_args_set_result_int | 2.695e+07 |  |
| search_for_handler_from | 0.24 | 0.30 | search_for_handler_from | 2.578e+07 |  |
| MVM_SC_WB_OBJ | 0.08 | 0.14 | MVM_SC_WB_OBJ | 2.340e+07 |  |
| MVM_frame_takeclosure | 0.20 | 0.13 | MVM_frame_takeclosure | -2.293e+07 |  |
| mp_and | 0.21 | 0.26 | mp_and | 2.164e+07 |  |
| incorporate_stats | 0.45 | 0.49 | incorporate_stats | 2.151e+07 |  |
| compiler_rt.bcmp | 0.13 | 0.18 | compiler_rt.bcmp | 2.044e+07 |  |
| MVM_gc_root_add_frame_roots_to_worklist | 0.13 | 0.07 | MVM_gc_root_add_frame_roots_to_worklist | -2.027e+07 | gc |
| mp_init | 0.15 | 0.09 | mp_init | -1.998e+07 |  |
| MVM_string_utf8_encode_substr | 0.45 | 0.38 | MVM_string_utf8_encode_substr | -1.921e+07 |  |
| MVM_gc_root_add_frame_registers_to_worklist | 0.00 | 0.05 | MVM_gc_root_add_frame_registers_to_worklist | 1.851e+07 | gc |
| allocate | 0.97 | 0.98 | allocate | 1.815e+07 |  |
| allocate_record | 0.29 | 0.23 | allocate_record | -1.789e+07 |  |
| get_attribute | 0.19 | 0.23 | get_attribute | 1.764e+07 |  |

### collector share, plain

- total cycles median: c 35527891606, f 37017096437; difference f - c 1489204831 (4.19 % of c)
- spread of round medians: c 164352416, f 441166038; run-to-run spread over all 15 runs: c 832538599, f 1106939722
- collector cycles: c 4.15 % x 35527891606 = 1474407502; f 4.84 % x 37017096437 = 1791627468; difference 317219966
- collector share = 317219966 / 1489204831 = 0.213

## Samples: LTO, bad

### top 40, c

| # | share % | samples | dso | symbol |
|---:|---:|---:|---|---|
| 1 | 24.96 | 8818 | [JIT] | (unresolved) |
| 2 | 9.05 | 3045 | libmoar.so | compiler_rt.fastMemset |
| 3 | 7.05 | 2352 | libmoar.so | MVM_frame_dispatch |
| 4 | 3.68 | 1249 | libc.so.6 | (unresolved) |
| 5 | 3.50 | 1168 | libmoar.so | MVM_bigint_xor |
| 6 | 2.95 | 984 | libmoar.so | get_boxed_ref |
| 7 | 2.64 | 879 | libmoar.so | gc_free.2630 |
| 8 | 2.63 | 878 | libmoar.so | MVM_bigint_and |
| 9 | 2.31 | 778 | libmoar.so | MVM_interp_run |
| 10 | 2.29 | 764 | libmoar.so | MVM_spesh_arg_guard_run |
| 11 | 2.17 | 723 | libmoar.so | initialize.2614 |
| 12 | 2.03 | 679 | libmoar.so | MVM_gc_allocate_object |
| 13 | 1.54 | 515 | libmoar.so | MVM_gc_collect_free_nursery_uncopied |
| 14 | 1.38 | 463 | libmoar.so | MVM_disp_program_run |
| 15 | 1.36 | 454 | libc.so.6 | cfree |
| 16 | 1.35 | 451 | libmoar.so | MVM_callstack_unwind_frame |
| 17 | 1.35 | 452 | libmoar.so | MVM_bigint_shr |
| 18 | 1.15 | 383 | libmoar.so | initialize.2992 |
| 19 | 1.05 | 349 | libmoar.so | MVM_args_set_result_obj |
| 20 | 1.03 | 344 | libmoar.so | gc_cleanup |
| 21 | 0.84 | 282 | libmoar.so | mp_clear |
| 22 | 0.78 | 260 | libmoar.so | mp_xor |
| 23 | 0.78 | 259 | libmoar.so | allocate |
| 24 | 0.77 | 261 | libmoar.so | mi_free |
| 25 | 0.76 | 252 | libmoar.so | MVM_VMArray_at_pos |
| 26 | 0.69 | 237 | libmoar.so | MVM_spesh_inline |
| 27 | 0.54 | 180 | libmoar.so | MVM_cu_string |
| 28 | 0.52 | 174 | libmoar.so | mp_clamp |
| 29 | 0.45 | 151 | libmoar.so | mp_div_2d |
| 30 | 0.42 | 140 | libmoar.so | MVM_string_utf8_encode_substr |
| 31 | 0.41 | 138 | libmoar.so | MVM_repr_at_pos_o |
| 32 | 0.40 | 133 | libmoar.so | set_size_internal |
| 33 | 0.39 | 171 | libmoar.so | incorporate_stats |
| 34 | 0.37 | 127 | libmoar.so | MVM_frame_try_return |
| 35 | 0.35 | 117 | libmoar.so | MVM_gc_allocate_nursery |
| 36 | 0.35 | 116 | libmoar.so | copy_to.2615 |
| 37 | 0.34 | 114 | libmoar.so | MVM_VMArray_push |
| 38 | 0.32 | 107 | libmoar.so | MVM_repr_clone |
| 39 | 0.29 | 95 | libmoar.so | exit_heap_frame |
| 40 | 0.29 | 98 | ld-linux-x86-64.so.2 | __tls_get_addr |

Collector share of samples, c: 4.25 % (sum over 14 symbols; perf's listed total 98.18 %)

Collector symbols counted, c: MVM_gc_allocate_object 2.03, MVM_gc_collect_free_nursery_uncopied 1.54, MVM_gc_allocate_nursery 0.35, MVM_gc_root_add_frame_roots_to_worklist 0.12, process_worklist 0.09, run_gc 0.03, MVM_gc_mark_collectable 0.02, MVM_gc_mark_thread_unblocked 0.02, MVM_gc_gen2_allocate 0.01, MVM_gc_root_add_instance_roots_to_worklist 0.01, MVM_gc_collect 0.01, MVM_gc_root_add_tc_roots_to_worklist 0.01, MVM_gc_enter_from_allocator 0.01, MVM_gc_mark_thread_unblocked@plt 0.00

### top 40, f

| # | share % | samples | dso | symbol |
|---:|---:|---:|---|---|
| 1 | 26.20 | 9416 | [JIT] | (unresolved) |
| 2 | 8.89 | 3011 | libmoar.so | compiler_rt.fastMemset |
| 3 | 6.17 | 2072 | libmoar.so | MVM_frame_dispatch |
| 4 | 3.89 | 1337 | libc.so.6 | (unresolved) |
| 5 | 3.20 | 1071 | libmoar.so | MVM_bigint_xor |
| 6 | 2.97 | 993 | libmoar.so | initialize.2476 |
| 7 | 2.59 | 880 | libmoar.so | MVM_interp_run |
| 8 | 2.53 | 848 | libmoar.so | gc_free.2492 |
| 9 | 2.28 | 766 | libmoar.so | MVM_spesh_arg_guard_run |
| 10 | 1.94 | 650 | libmoar.so | MVM_bigint_and |
| 11 | 1.81 | 606 | libmoar.so | get_boxed_ref |
| 12 | 1.67 | 560 | libmoar.so | MVM_gc_collect_free_nursery_uncopied |
| 13 | 1.45 | 499 | libmoar.so | MVM_disp_program_run |
| 14 | 1.30 | 435 | libmoar.so | initialize.2854 |
| 15 | 1.23 | 414 | libc.so.6 | cfree |
| 16 | 1.22 | 411 | libmoar.so | MVM_gc_allocate_object |
| 17 | 1.14 | 384 | libmoar.so | MVM_callstack_unwind_frame |
| 18 | 1.05 | 353 | libmoar.so | MVM_bigint_shr |
| 19 | 1.02 | 340 | libmoar.so | allocate |
| 20 | 1.00 | 337 | libmoar.so | gc_cleanup |
| 21 | 0.97 | 326 | libmoar.so | mp_clear |
| 22 | 0.86 | 288 | libmoar.so | mi_free |
| 23 | 0.80 | 271 | libmoar.so | MVM_args_set_result_obj |
| 24 | 0.79 | 268 | libmoar.so | gc.collect.processWorklist |
| 25 | 0.77 | 257 | libmoar.so | MVM_VMArray_at_pos |
| 26 | 0.67 | 224 | libmoar.so | mp_xor |
| 27 | 0.67 | 233 | libmoar.so | MVM_spesh_inline |
| 28 | 0.63 | 212 | libmoar.so | mp_clamp |
| 29 | 0.48 | 160 | libmoar.so | set_size_internal |
| 30 | 0.45 | 152 | libmoar.so | MVM_cu_string |
| 31 | 0.43 | 150 | ld-linux-x86-64.so.2 | __tls_get_addr |
| 32 | 0.40 | 135 | libmoar.so | MVM_frame_try_return |
| 33 | 0.40 | 135 | libmoar.so | moar_c.MVM_gc_root_temp_push |
| 34 | 0.39 | 172 | libmoar.so | incorporate_stats |
| 35 | 0.39 | 134 | libmoar.so | MVM_VMArray_push |
| 36 | 0.38 | 127 | libmoar.so | MVM_string_utf8_encode_substr |
| 37 | 0.37 | 123 | libmoar.so | mp_div_2d |
| 38 | 0.37 | 125 | libmoar.so | exit_heap_frame |
| 39 | 0.35 | 118 | libmoar.so | search_for_handler_from |
| 40 | 0.34 | 115 | libmoar.so | copy_to.2477 |

Collector share of samples, f: 4.58 % (sum over 17 symbols; perf's listed total 97.66 %)

Collector symbols counted, f: MVM_gc_collect_free_nursery_uncopied 1.67, MVM_gc_allocate_object 1.22, gc.collect.processWorklist 0.79, moar_c.MVM_gc_root_temp_push 0.40, MVM_gc_allocate_nursery 0.28, MVM_gc_root_add_frame_roots_to_worklist 0.07, gc.orchestrate.runGc 0.04, MVM_gc_root_add_frame_registers_to_worklist 0.04, MVM_gc_mark_thread_unblocked 0.02, MVM_gc_mark_collectable 0.02, MVM_gc_gen2_allocate 0.01, MVM_gc_root_add_permanents_to_worklist 0.01, MVM_gc_root_add_temps_to_worklist 0.01, MVM_gc_allocate_type_object 0.00, MVM_gc_root_add_instance_roots_to_worklist 0.00, MVM_gc_root_add_tc_roots_to_worklist 0.00, MVM_gc_allocate_stable 0.00

### aligned delta, top 40 by |delta| (cycles = share x median total cycles of the side)

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
| MVM_bigint_xor | 3.50 | 3.20 | MVM_bigint_xor | -5.532e+07 |  |
| mp_clamp | 0.52 | 0.63 | mp_clamp | 5.302e+07 |  |
| MVM_disp_program_run | 1.38 | 1.45 | MVM_disp_program_run | 5.279e+07 |  |
| mi_free | 0.77 | 0.86 | mi_free | 4.964e+07 |  |
| mp_copy | 0.10 | 0.22 | mp_copy | 4.936e+07 |  |
| allocate_record | 0.19 | 0.30 | allocate_record | 4.703e+07 |  |
| set_size_internal | 0.40 | 0.48 | set_size_internal | 3.896e+07 |  |
| mp_and | 0.18 | 0.27 | mp_and | 3.892e+07 |  |
| MVM_spesh_arg_guard_run | 2.29 | 2.28 | MVM_spesh_arg_guard_run | 3.761e+07 |  |
| exit_heap_frame | 0.29 | 0.37 | exit_heap_frame | 3.696e+07 |  |
| search_for_handler_from | 0.28 | 0.35 | search_for_handler_from | 3.282e+07 |  |
| set_uint | 0.32 | 0.23 | set_uint set_uint.2652 set_uint.2858 | -2.985e+07 |  |
| mp_xor | 0.78 | 0.67 | mp_xor | -2.942e+07 |  |
| libc.so.6 __libc_calloc | 0.28 | 0.34 | __libc_calloc | 2.885e+07 |  |
| MVM_string_ci_get_codepoint | 0.17 | 0.23 | MVM_string_ci_get_codepoint.5077 | 2.686e+07 |  |
| libc.so.6 cfree | 1.36 | 1.23 | cfree | -2.681e+07 |  |
| MVM_VMArray_push | 0.34 | 0.39 | MVM_VMArray_push | 2.598e+07 |  |
| MVM_cu_string | 0.54 | 0.45 | MVM_cu_string | -2.585e+07 |  |
| mp_div_2d | 0.45 | 0.37 | mp_div_2d | -2.353e+07 |  |
| MVM_string_substrings_equal_nocheck | 0.16 | 0.21 | MVM_string_substrings_equal_nocheck | 2.271e+07 |  |

### collector share, bad

- total cycles median: c 37803121150, f 39618532654; difference f - c 1815411504 (4.80 % of c)
- spread of round medians: c 210332707, f 929731014; run-to-run spread over all 15 runs: c 1044134536, f 2341888660
- collector cycles: c 4.25 % x 37803121150 = 1606632649; f 4.58 % x 39618532654 = 1814528796; difference 207896147
- collector share = 207896147 / 1815411504 = 0.115

## Samples: non-LTO (attribution only, a different binary)

### top 40, c

| # | share % | samples | dso | symbol |
|---:|---:|---:|---|---|
| 1 | 26.68 | 8626 | [JIT] | (unresolved) |
| 2 | 9.39 | 2928 | libmoar.so | compiler_rt.fastMemset |
| 3 | 3.76 | 1179 | libc.so.6 | (unresolved) |
| 4 | 3.59 | 1107 | libmoar.so | initialize |
| 5 | 3.11 | 962 | libmoar.so | gc_free |
| 6 | 3.07 | 948 | libmoar.so | MVM_frame_dispatch |
| 7 | 2.52 | 776 | libmoar.so | MVM_spesh_arg_guard_run |
| 8 | 2.52 | 786 | libmoar.so | mi_calloc |
| 9 | 2.38 | 733 | libmoar.so | get_boxed_ref |
| 10 | 2.15 | 664 | libmoar.so | mi_malloc |
| 11 | 2.14 | 671 | libmoar.so | MVM_interp_run |
| 12 | 1.55 | 482 | libmoar.so | MVM_disp_program_run |
| 13 | 1.54 | 478 | libmoar.so | MVM_gc_collect_free_nursery_uncopied |
| 14 | 1.53 | 472 | libmoar.so | MVM_bigint_xor |
| 15 | 1.49 | 459 | libmoar.so | MVM_repr_alloc_init |
| 16 | 1.42 | 439 | libc.so.6 | cfree |
| 17 | 1.34 | 416 | libmoar.so | MVM_gc_allocate_object |
| 18 | 1.10 | 340 | libmoar.so | mp_clear |
| 19 | 0.92 | 286 | libmoar.so | gc_cleanup |
| 20 | 0.90 | 281 | libmoar.so | MVM_callstack_unwind_frame |
| 21 | 0.88 | 272 | libmoar.so | allocate |
| 22 | 0.87 | 267 | libmoar.so | MVM_bigint_and |
| 23 | 0.87 | 273 | libmoar.so | mi_free |
| 24 | 0.79 | 246 | libmoar.so | MVM_args_set_result_obj |
| 25 | 0.74 | 229 | libmoar.so | MVM_VMArray_at_pos |
| 26 | 0.73 | 225 | libmoar.so | mp_xor |
| 27 | 0.73 | 230 | libmoar.so | MVM_spesh_inline |
| 28 | 0.63 | 193 | libmoar.so | mp_clamp |
| 29 | 0.45 | 139 | libmoar.so | MVM_bigint_shr |
| 30 | 0.42 | 167 | libmoar.so | incorporate_stats |
| 31 | 0.39 | 121 | libmoar.so | copy_to |
| 32 | 0.38 | 122 | ld-linux-x86-64.so.2 | __tls_get_addr |
| 33 | 0.37 | 113 | libmoar.so | MVM_VMArray_push |
| 34 | 0.36 | 114 | libmoar.so | MVM_frame_try_return |
| 35 | 0.36 | 111 | libmoar.so | MVM_cu_string |
| 36 | 0.34 | 104 | libmoar.so | set_uint |
| 37 | 0.33 | 101 | libmoar.so | mp_div_2d |
| 38 | 0.31 | 95 | libmoar.so | two_complement_bitop |
| 39 | 0.31 | 94 | libmoar.so | exit_heap_frame |
| 40 | 0.30 | 92 | libmoar.so | MVM_repr_clone |

Collector share of samples, c: 3.59 % (sum over 22 symbols; perf's listed total 98.22 %)

Collector symbols counted, c: MVM_gc_collect_free_nursery_uncopied 1.54, MVM_gc_allocate_object 1.34, MVM_gc_allocate_nursery 0.29, process_worklist 0.11, MVM_gc_root_add_frame_roots_to_worklist 0.09, MVM_gc_allocate_frame 0.06, MVM_gc_mark_collectable 0.05, MVM_gc_gen2_allocate 0.02, MVM_gc_write_barrier_hit_by@plt 0.02, MVM_gc_root_add_instance_roots_to_worklist 0.01, MVM_gc_root_add_permanents_to_worklist 0.01, run_gc 0.01, MVM_gc_mark_thread_unblocked 0.01, MVM_gc_root_add_gen2s_to_worklist 0.01, MVM_gc_mark_thread_blocked 0.01, MVM_gc_write_barrier_hit_by 0.01, MVM_gc_gen2_allocate_zeroed 0.00, MVM_gc_enter_from_allocator 0.00, MVM_gc_root_add_tc_roots_to_worklist 0.00, MVM_gc_root_add_temps_to_worklist 0.00, MVM_gc_object_id 0.00, MVM_gc_root_gen2_add 0.00

### top 40, f

| # | share % | samples | dso | symbol |
|---:|---:|---:|---|---|
| 1 | 26.59 | 8815 | [JIT] | (unresolved) |
| 2 | 8.97 | 2892 | libmoar.so | compiler_rt.fastMemset |
| 3 | 3.99 | 1276 | libmoar.so | initialize |
| 4 | 3.62 | 1182 | libc.so.6 | (unresolved) |
| 5 | 3.31 | 1059 | libmoar.so | gc_free |
| 6 | 2.89 | 925 | libmoar.so | MVM_frame_dispatch |
| 7 | 2.37 | 765 | libmoar.so | mi_calloc |
| 8 | 2.34 | 749 | libmoar.so | MVM_spesh_arg_guard_run |
| 9 | 2.21 | 705 | libmoar.so | get_boxed_ref |
| 10 | 2.14 | 692 | libmoar.so | MVM_interp_run |
| 11 | 2.04 | 651 | libmoar.so | mi_malloc |
| 12 | 1.82 | 581 | libmoar.so | MVM_repr_alloc_init |
| 13 | 1.75 | 558 | libmoar.so | MVM_gc_collect_free_nursery_uncopied |
| 14 | 1.40 | 446 | libmoar.so | MVM_gc_allocate_object |
| 15 | 1.39 | 444 | libmoar.so | MVM_bigint_xor |
| 16 | 1.36 | 435 | libc.so.6 | cfree |
| 17 | 1.33 | 431 | libmoar.so | MVM_disp_program_run |
| 18 | 1.11 | 356 | libmoar.so | MVM_callstack_unwind_frame |
| 19 | 1.04 | 332 | libmoar.so | MVM_bigint_and |
| 20 | 0.98 | 314 | libmoar.so | gc_cleanup |
| 21 | 0.96 | 306 | libmoar.so | mp_clear |
| 22 | 0.88 | 282 | libmoar.so | allocate |
| 23 | 0.87 | 277 | libmoar.so | mp_xor |
| 24 | 0.82 | 263 | libmoar.so | MVM_args_set_result_obj |
| 25 | 0.81 | 258 | libmoar.so | gc.collect.processWorklist |
| 26 | 0.71 | 229 | libmoar.so | mi_free |
| 27 | 0.71 | 231 | libmoar.so | MVM_spesh_inline |
| 28 | 0.68 | 219 | libmoar.so | MVM_gc_allocate_nursery |
| 29 | 0.67 | 214 | libmoar.so | mp_clamp |
| 30 | 0.61 | 196 | libmoar.so | MVM_VMArray_at_pos |
| 31 | 0.41 | 131 | libmoar.so | MVM_jit_code_enter |
| 32 | 0.41 | 130 | libmoar.so | MVM_VMArray_push |
| 33 | 0.40 | 174 | libmoar.so | incorporate_stats |
| 34 | 0.38 | 123 | libmoar.so | copy_to |
| 35 | 0.37 | 117 | libmoar.so | MVM_bigint_shr |
| 36 | 0.36 | 114 | libmoar.so | MVM_cu_string |
| 37 | 0.34 | 108 | libc.so.6 | __libc_calloc |
| 38 | 0.33 | 106 | libmoar.so | mp_div_2d |
| 39 | 0.33 | 106 | libmoar.so | MVM_frame_try_return |
| 40 | 0.31 | 100 | libmoar.so | MVM_string_utf8_encode_substr |

Collector share of samples, f: 5.25 % (sum over 27 symbols; perf's listed total 98.36 %)

Collector symbols counted, f: MVM_gc_collect_free_nursery_uncopied 1.75, MVM_gc_allocate_object 1.40, gc.collect.processWorklist 0.81, MVM_gc_allocate_nursery 0.68, moar_c.MVM_gc_root_temp_push 0.25, MVM_gc_root_add_frame_roots_to_worklist 0.13, MVM_gc_mark_collectable 0.05, MVM_gc_allocate_nursery@plt 0.04, MVM_gc_gen2_allocate 0.02, gc.orchestrate.runGc 0.02, MVM_gc_mark_thread_blocked 0.02, MVM_gc_allocate_frame 0.02, MVM_gc_write_barrier_hit_by@plt 0.02, MVM_gc_root_add_permanents_to_worklist 0.01, MVM_gc_root_add_instance_roots_to_worklist 0.01, MVM_gc_allocate_frame@plt 0.01, MVM_gc_write_barrier_hit_by 0.01, MVM_gc_mark_thread_unblocked@plt 0.00, MVM_gc_collect 0.00, MVM_gc_root_add_gen2s_to_worklist 0.00, MVM_gc_mark_thread_unblocked 0.00, MVM_gc_enter_from_allocator 0.00, gc.finalize.walkThreadFinalizeQueue 0.00, MVM_gc_root_add_temps_to_worklist 0.00, MVM_gc_root_add_tc_roots_to_worklist 0.00, MVM_gc_collect_free_stables 0.00, MVM_gc_root_gen2_add 0.00

### aligned delta, top 40 by |delta| (share points)

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
| MVM_jit_code_enter | 0.27 | 0.41 | MVM_jit_code_enter | +0.14 |  |
| MVM_VMArray_at_pos | 0.74 | 0.61 | MVM_VMArray_at_pos | -0.13 |  |
| ld-linux-x86-64.so.2 __tls_get_addr | 0.38 | 0.26 | __tls_get_addr | -0.12 |  |
| mi_malloc | 2.15 | 2.04 | mi_malloc | -0.11 |  |
| MVM_frame_capturelex | 0.25 | 0.15 | MVM_frame_capturelex | -0.10 |  |
| mp_set_i64 | 0.21 | 0.12 | mp_set_i64 | -0.09 |  |
| MVM_VMArray_at_pos_o | 0.14 | 0.23 | MVM_VMArray_at_pos_o | +0.09 |  |
| [JIT] (unresolved) | 26.68 | 26.59 | (unresolved) | -0.09 |  |
| MVM_frame_destroy | 0.06 | 0.14 | MVM_frame_destroy | +0.08 |  |
| mp_clear@plt | 0.20 | 0.12 | mp_clear@plt | -0.08 |  |
| MVM_bigint_shr | 0.45 | 0.37 | MVM_bigint_shr | -0.08 |  |
| dispatch_monomorphic | 0.28 | 0.20 | dispatch_monomorphic | -0.08 |  |
| MVM_jit_code_trampoline | 0.13 | 0.20 | MVM_jit_code_trampoline | +0.07 |  |
| MVM_string_get_grapheme_at_nocheck | 0.17 | 0.10 | MVM_string_get_grapheme_at_nocheck | -0.07 |  |
| gc_mark | 0.06 | 0.13 | gc_mark | +0.07 |  |
| exit_heap_frame | 0.31 | 0.25 | exit_heap_frame | -0.06 |  |
| get_attribute | 0.25 | 0.19 | get_attribute | -0.06 |  |
| gc_cleanup | 0.92 | 0.98 | gc_cleanup | +0.06 |  |
| MVM_gc_allocate_object | 1.34 | 1.40 | MVM_gc_allocate_object | +0.06 | gc |
| libc.so.6 cfree | 1.42 | 1.36 | cfree | -0.06 |  |

