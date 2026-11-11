# cb Task 1: the call-boundary audit

```
Date:       2026-11-11, 18:05-18:30 CET
MoarVM:     gc-call-boundary, 782a56faa (the four edits of the plan) and c5aebb78a (the four noinline sites this
            audit adds); base 3145f190e (zig-hash-engine 66ff45c8c plus the cb spec and plan pointers)
Builds:     cb-n-syms (-Dstrip=false, cb-prefixes.md) against ng-n-syms (Campaign 6 native) and ng-c-syms (Campaign 6
            C-collector control); all three LTO, ReleaseFast
Spec:       traces/llm/specs/2026-11-11-gc-call-boundary-design.md section 5 (the rule and the audit)
Evidence:   objdump -d --no-show-raw-insn --section=.text of each libmoar.so; every direct `call`/`jmp`/`jcc`
            whose target is a symbol start, per containing symbol; nm -S --defined-only sizes
Toolchain:  C side compiled by Zig 0.17.1's clang (`zig cc --version`: clang version 22.1.8; the .comment section of
            each libmoar.so: clang version 22.1.8, Linker: LLD 22.1.8); disassembly and symbols read with GNU
            Binutils 2.47 (`objdump --version`: GNU objdump (GNU Binutils) 2.47; `nm --version`: GNU nm (GNU
            Binutils) 2.47). The system `clang --version` prints clang version 23.1.1; it built none of the three
            libraries.
```

## The method

The source-level candidate list: for every `pub fn` of the ten collector files (`src/zig/gc/*.zig` without
`gc_test.zig`) its callers in the other nine and in `src/zig/moar.zig`, through each file's import aliases (43
cross-file caller/callee pairs, plus the `c.MVM_gc_*` calls that reach a Zig export through a C header inline or a
`moar.zig` macro port). The binary-level list, which is the one that decides: every call in `ng-c-syms` from a
function defined in one `src/gc/*.c` file to a function defined in another (52 caller/callee/kind rows), each
looked up on the Zig side by the Zig symbol or its export name (LTO sometimes leaves the body under the export name,
for example `MVM_gc_root_add_gen2s_to_worklist` after c5aebb78a). A C call with no Zig counterpart is a Zig inline
where the C calls out of line; a C callee absent from `nm` (`add_in_tray_to_worklist`, `finish_gc`,
`process_in_tray`, `walk_thread_finalize_queue`, `MVM_gc_debug_*` and 14 more) was inlined into all its C callers (or, for
the debug pair, is compiled out). The 1.5x size trigger was run over all 59 Zig/C function pairs (the 56 exports and
three statics: `process_worklist`, `add_work`, `run_gc`).

"before" is ng-n-syms (Campaign 6), "after" is cb-n-syms at c5aebb78a. Call counts are `call` sites of that
callee in the caller's disassembly (`jmp` where marked). Size is the caller's `nm -S` size, Zig before -> after / C.

## The sizes join (Step 3)

The four edits alone (782a56faa), `join sizes-before.txt sizes-after.txt | awk '$2!=$3'` over the `gc.*`,
`MVM_gc*` and `moar.*` symbols, `LC_ALL=C` sorted (the default collation made `join` refuse the files):

```
gc.allocation.allocateObject 786 369
gc.allocation.allocateStable 585 344
gc.allocation.allocateTypeObject 494 259
gc.collect.processWorklist 2047 1568
```

Exactly the plan's four rows. The two imports changed nothing: `gc.gen2.transfer` (1473) and
`gc.roots.addGen2sToWorklist` (350) keep their size and call targets, because LTO had already bound
`c.MVM_gc_root_gen2_add` and `c.MVM_gc_mark_collectable` through the protected exports to `gc.roots.gen2Add` and
`gc.collect.markCollectable` (both called out of line before and after). No symbol appeared or vanished.

With the audit's four noinline sites (c5aebb78a):

```
MVM_gc_root_add_gen2s_to_worklist 5 185
MVM_gc_worklist_create 328 13
MVM_gc_worklist_presize_for 172 10
gc.allocation.allocateObject 786 369
gc.allocation.allocateStable 585 344
gc.allocation.allocateTypeObject 494 259
gc.collect.collect 1414 1797
gc.collect.markCollectable 3360 952
gc.collect.processWorklist 2047 1568
gc.orchestrate.runGc 2319 2239
gc.roots.addFrameRegistersToWorklist 403 221
gc.roots.addFrameRootsToWorklist 2011 685
gc.roots.addInstanceRootsToWorklist 7657 3555
gc.roots.addPermanentsToWorklist 373 182
gc.roots.addTcRootsToWorklist 5516 2605
gc.roots.addTempsToWorklist 412 207
```

Symbols only before: `gc.collect.addInTrayToWorklist`, `gc.roots.addGen2sToWorklist` (now inlined into
`gc.collect.collect`, which is what the C does with `add_in_tray_to_worklist` and
`MVM_gc_root_add_gen2s_to_worklist`; the export now carries the body). Only after: `gc.finalize.walkQueues`,
`gc.worklist.create`, `gc.worklist.presizeFor` (the new out-of-line bodies; the exports became 10-13 byte jumps).
`mark_last_handler_result` (outside the awk filter) 242 -> 47, C 56.

## The table

Callee column: does the callee contain an allocation, a lock, a panic path or a loop.

### Rows with action noinline

| Zig caller | Zig callee | C caller | C callee | Zig inlined? | C inlined? | callee alloc/lock/panic/loop? | size Zig/C | action |
|---|---|---|---|---|---|---|---|---|
| allocation.allocateObject | finalize.addToQueue | MVM_gc_allocate_object | MVM_gc_finalize_add_to_queue (finalize.c) | before inlined (0 calls), after call x1 | out of line, call x1 (plt) | yes: realloc growth of the finalize queue | 786 -> 369 / 384 | noinline (spike) |
| allocation.allocateObject | roots.gen2Add (through moar.assignRef, the wb.h inline and wb.hitBy) | MVM_gc_allocate_object | MVM_gc_root_gen2_add (roots.c) | before inlined (0), after call x1 | out of line, call x1 | yes: realloc growth, panic on null | 786 -> 369 / 384 | noinline (spike) |
| allocation.allocateStable | roots.gen2Add (same path) | MVM_gc_allocate_stable | MVM_gc_root_gen2_add | before inlined (0), after call x1 | out of line, call x1 | yes | 585 -> 344 / 344 | noinline (gen2Add) |
| allocation.allocateTypeObject | roots.gen2Add (same path) | MVM_gc_allocate_type_object | MVM_gc_root_gen2_add | before inlined (0), after call x1 | out of line, call x1 | yes | 494 -> 259 / 259 | noinline (gen2Add) |
| collect.processWorklist | roots.gen2Add | process_worklist | MVM_gc_root_gen2_add | before inlined (0), after call x2 | out of line, call x2 | yes | 2047 -> 1568 / 1359 | noinline (gen2Add) |
| gen2.transfer | roots.gen2Add (was `c.MVM_gc_root_gen2_add`, now the import) | MVM_gc_gen2_transfer | MVM_gc_root_gen2_add | out of line before and after, call x1 | out of line, call x1 | yes | 1473 -> 1473 / 1453 | noinline (gen2Add; the import changed no byte) |
| collect.markCollectable | worklist.addSlow (moar.worklistAdd -> `c.MVM_gc_worklist_add_slow`) | MVM_gc_mark_collectable | MVM_gc_worklist_add_slow (worklist.c) | before 2 calls of 11 sites, after call x10 + jmp x1 | out of line, call x10 + jmp x1 | yes: realloc growth | 3360 -> 952 / 1073 | noinline (audit) |
| collect.collect | worklist.addSlow | MVM_gc_collect | MVM_gc_worklist_add_slow | before inlined (0), after call x6 | out of line, call x5 | yes | 1414 -> 1797 / 1627 | noinline (audit) |
| roots.addPermanentsToWorklist | worklist.addSlow | MVM_gc_root_add_permanents_to_worklist | MVM_gc_worklist_add_slow | before inlined (0), after call x1 | out of line, call x1 | yes | 373 -> 182 / 165 | noinline (audit) |
| roots.addInstanceRootsToWorklist | worklist.addSlow | MVM_gc_root_add_instance_roots_to_worklist | MVM_gc_worklist_add_slow | before 2 of 23, after call x23 | out of line, call x23 | yes | 7657 -> 3555 / 4091 | noinline (audit) |
| roots.addTcRootsToWorklist | worklist.addSlow | MVM_gc_root_add_tc_roots_to_worklist | MVM_gc_worklist_add_slow | before inlined (0), after call x16 | out of line, call x15 | yes | 5516 -> 2605 / 4693 | noinline (audit) |
| roots.addTempsToWorklist | worklist.addSlow | MVM_gc_root_add_temps_to_worklist | MVM_gc_worklist_add_slow | before inlined (0), after call x1 | out of line, call x1 | yes | 412 -> 207 / 207 | noinline (audit) |
| roots.addFrameRootsToWorklist | worklist.addSlow | MVM_gc_root_add_frame_roots_to_worklist | MVM_gc_worklist_add_slow | before inlined (0), after call x8 | out of line, call x9 | yes | 2011 -> 685 / 955 | noinline (audit) |
| roots.addFrameRegistersToWorklist | worklist.addSlow | MVM_gc_root_add_frame_registers_to_worklist | MVM_gc_worklist_add_slow | before inlined (0), after call x1 | out of line, call x1 | yes | 403 -> 221 / 229 | noinline (audit) |
| finalize.markLastHandlerResult | worklist.addSlow | mark_last_handler_result | MVM_gc_worklist_add_slow | before inlined (0), after jmp x1 | out of line, jmp x1 | yes | 242 -> 47 / 56 | noinline (audit; a tail jump, so not a call-boundary.sh row) |
| collect.collect | worklist.create | MVM_gc_collect | MVM_gc_worklist_create (worklist.c) | before inlined (0), after call x1 | out of line, call x1 | yes: two mallocs | 1414 -> 1797 / 1627 | noinline (audit) |
| roots.addGen2sToWorklist (inlined into collect.collect after, as in the C) | worklist.presizeFor | MVM_gc_root_add_gen2s_to_worklist (inlined into MVM_gc_collect) | MVM_gc_worklist_presize_for (worklist.c) | before inlined (0) in gc.roots.addGen2sToWorklist and collect, after call x1 in collect and in the export body | out of line, call x1 in MVM_gc_collect and in the export | yes: realloc | 350 -> (inlined; export 185) / 165 | noinline (audit) |
| orchestrate.runGc (through finishGc) | finalize.walkQueues | run_gc (through finish_gc, inlined) | MVM_finalize_walk_queues (finalize.c) | before inlined (0), after call x1 | out of line, call x1 | yes: a loop over the threads, calls collect | 2319 -> 2239 / 2109 | noinline (audit) |

### markCollectable (the import)

| Zig caller | Zig callee | C caller | C callee | Zig inlined? | C inlined? | callee alloc/lock/panic/loop? | size Zig/C | action |
|---|---|---|---|---|---|---|---|---|
| roots.addGen2sToWorklist (was `c.MVM_gc_mark_collectable`, now `collect.markCollectable`) | collect.markCollectable | MVM_gc_root_add_gen2s_to_worklist (and, inlined, MVM_gc_collect) | MVM_gc_mark_collectable (collect.c) | out of line before and after: call x1 in gc.roots.addGen2sToWorklist before; after, call x1 in collect.collect and x1 in the export body | out of line under the C's own LTO: call x1 in MVM_gc_root_add_gen2s_to_worklist and x1 in MVM_gc_collect | yes: loops, the worklist growth, a panic path | callee 3360 -> 952 / 1073 | none: out of line in both builds without a keyword; LLVM did not inline it at either size (3360 or 952 bytes) (process_worklist x2 / C x3 as well); call-boundary.sh keeps the row |

### Rows where both sides call out of line (action none)

| Zig caller | Zig callee | C caller | C callee | Zig inlined? | C inlined? | callee alloc/lock/panic/loop? | size Zig/C | action |
|---|---|---|---|---|---|---|---|---|
| allocation.allocateNursery | orchestrate.enterFromAllocator, enterFromInterrupt | MVM_gc_allocate_nursery | MVM_gc_enter_from_allocator, _from_interrupt (orchestrate.c) | out of line, x1 each | out of line, x1 each | yes | 136 / 146 | none |
| allocation.allocateFrame | orchestrate.enterFrom*, gen2.allocate | MVM_gc_allocate_frame | MVM_gc_enter_from_*, MVM_gc_gen2_allocate | out of line, x1 each | out of line, x1 each | yes | 145 / 153 | none |
| allocation.allocateObject, allocateStable, allocateTypeObject | orchestrate.enterFrom*, gen2.allocate | MVM_gc_allocate_object, _stable, _type_object | MVM_gc_enter_from_*, MVM_gc_gen2_allocate | out of line, x1 each, before and after | out of line, x1 each | yes | see above | none |
| allocation.allocate* (through moar.root, the roots.h push inline) | roots.tempPushSlow | MVM_gc_allocate_object, _stable, _type_object | MVM_gc_root_temp_push_slow (roots.c) | out of line, x1 each | out of line, x1 each | yes | see above | none |
| finalize.runHandler (moar.root) | roots.tempPushSlow | MVM_gc_finalize_run_handler | MVM_gc_root_temp_push_slow | out of line, x2 | out of line, x2 | yes | 712 / 717 | none |
| finalize.walkQueues | collect.collect | MVM_finalize_walk_queues | MVM_gc_collect | out of line, x1 | out of line, x1 | yes | 93 / 534 | none (C 534 holds walk_thread_finalize_queue inlined; the Zig keeps that same-file static out of line) |
| collect.collect (mainRun) | roots.addInstanceRootsToWorklist, addTcRootsToWorklist | MVM_gc_collect | MVM_gc_root_add_instance_roots_to_worklist, _tc_roots_ (roots.c) | out of line, x1 each | out of line, x1 each | yes | 1797 / 1627 | none |
| collect.markCollectable | roots.addFrameRootsToWorklist | MVM_gc_mark_collectable | MVM_gc_root_add_frame_roots_to_worklist | tail jmp x1 | tail jmp x1 | yes | 952 / 1073 | none |
| collect.processWorklist | gen2.allocate | process_worklist | MVM_gc_gen2_allocate (gen2.c) | out of line, x1 | out of line, x1 | yes | 1568 / 1359 | none |
| objectid.objectId | gen2.allocateZeroed -> gen2.allocate | MVM_gc_object_id | MVM_gc_gen2_allocate (allocate_zeroed inlined) | allocate out of line x1, allocateZeroed inlined | allocate out of line x1, allocate_zeroed inlined | yes | 320 / 328 | none |
| orchestrate.globalDestruction | collect.freeGen2Unmarked, freeNurseryUncopied | MVM_gc_global_destruction | MVM_gc_collect_free_gen2_unmarked, _nursery_uncopied | out of line, x1 each | out of line, x1 each | yes | 919 / 788 | none |
| orchestrate.runGc (finishGc, freeNurseryUncopied, processInTray) | collect.collect, freeGen2Unmarked, freeNurseryUncopied, gen2.transfer | run_gc | MVM_gc_collect (x4), _free_gen2_unmarked, _free_nursery_uncopied, MVM_gc_gen2_transfer | out of line: collect x5 before, x4 after; the rest x1 | out of line: collect x4; the rest x1 | yes | 2239 / 2109 | none |
| wb.hitBy | roots.gen2Add | MVM_gc_write_barrier_hit_by | MVM_gc_root_gen2_add | out of line, x1 | out of line, x1 | yes | 21 / 21 | none |
| wb.hit | roots.gen2Add | MVM_gc_write_barrier_hit | MVM_gc_root_gen2_add | conditional tail jump (`je`) x1 | conditional tail jump x1 | yes | 11 / 11 | none |

### Rows where the C inlines (action none)

| Zig caller | Zig callee | C caller | C callee | Zig inlined? | C inlined? | callee alloc/lock/panic/loop? | size Zig/C | action |
|---|---|---|---|---|---|---|---|---|
| allocation.allocate* (moar.assignRef -> the wb.h inline) | wb.hitBy | MVM_gc_allocate_object, _stable, _type_object | MVM_gc_write_barrier_hit_by (wb.c) | inlined (gen2Add is called directly) | inlined under LTO (gen2_add called directly) | no: a flag test and the gen2Add call | 21 / 21 | none |
| collect.collect (mainRun) | roots.addPermanentsToWorklist, addTempsToWorklist, addGen2sToWorklist | MVM_gc_collect | MVM_gc_root_add_permanents_to_worklist, _temps_, _gen2s_ | before out of line (the Zig only), after inlined | inlined (collect.c calls them; no call in MVM_gc_collect) | yes | 1797 / 1627 | none: the reverse of the rule's case; LLVM matched the C by itself once addSlow was out of line |
| collect.collect | collect.addInTrayToWorklist (same file) | MVM_gc_collect | add_in_tray_to_worklist | before out of line, after inlined | inlined (symbol absent) | yes | | none (same file, recorded for the size join) |
| collect.collect | worklist.destroy | MVM_gc_collect | MVM_gc_worklist_destroy (worklist.c) | inlined | inlined | no: two frees | 21 / 21 | none |
| collect.freeGen2Unmarked | gen2.compactOverflows | MVM_gc_collect_free_gen2_unmarked | MVM_gc_gen2_compact_overflows (gen2.c) | inlined | inlined | yes: a loop | 2163 / 2067 | none |
| collect.freeGen2Unmarked | gen2.pageItems | (inline pointer arithmetic) | none | inlined | no function | no | | none |
| collect.freeNurseryUncopied | objectid.clear | MVM_gc_collect_free_nursery_uncopied | MVM_gc_object_id_clear (objectid.c) | inlined (calls MVM_ptr_hash_fetch_and_delete itself) | inlined (same) | no: a hash delete call | 431 / 407 | none |
| collect.processWorklist | objectid.useAllocation | process_worklist | MVM_gc_object_id_use_allocation | inlined (calls MVM_ptr_hash_fetch_and_delete) | inlined (same) | no | 1568 / 1359 | none |
| collect.processWorklist, freeNurseryUncopied | allocation.alignSize | process_worklist, ... | MVM_ALIGN_SIZE (macro) | inline fn | macro | no | | none |
| collect.processWorklist | wb.noUpdateReferenced | process_worklist | MVM_gc_write_barrier_no_update_referenced (wb.h static inline) | inline fn | static inline | no | | none |
| orchestrate.enterFromAllocator | collect.freeStables | MVM_gc_enter_from_allocator | MVM_gc_collect_free_stables (collect.c) | inlined | inlined | yes: a loop | 1079 / 1184 | none (the C inlines) |
| orchestrate.runGc (finishGc), globalDestruction | roots.gen2Cleanup | run_gc, MVM_gc_global_destruction | MVM_gc_root_gen2_cleanup (roots.c) | inlined | inlined | yes: a loop | | none (the C inlines; no caller of either export in either library) |
| orchestrate.globalDestruction | collect.freeStables | MVM_gc_global_destruction | MVM_gc_collect_free_stables | inlined | inlined | yes | 919 / 788 | none (the C inlines) |
| orchestrate.finishGc | debug.logCollection | finish_gc | MVM_gc_debug_log_collection (debug.c) | not in a gc-debug=0 build (absent) | absent in ng-c-syms | | | none |
| debug.findRegion | gen2.sizeOfBin | MVM_gc_debug_find_region | MVM_GEN2_BIN_SIZE-style inline | inline fn | absent in ng-c-syms | no | | none |
| allocation.allocate* (moar.Root.pop) | `c.MVM_gc_root_temp_pop(_n)` | | roots.h static inlines | inlined | inlined | no | | none |

Row count: 18 noinline rows (6 for the two spike definitions, 12 for the four audit definitions), 1 markCollectable
row, 14 both-out-of-line rows, 17 C-inlines rows. No `ask` rows. After c5aebb78a every one of the 52 C cross-file
calls of ng-c-syms has a Zig counterpart call in cb-n-syms.

### The 1.5x trigger

Before (ng-n-syms vs ng-c-syms), above 1.5x: markCollectable 3.13, mark_last_handler_result 4.32,
addPermanentsToWorklist 2.26, addInstanceRootsToWorklist 1.87, addTempsToWorklist 1.99, addGen2sToWorklist 2.12,
addFrameRootsToWorklist 2.11, addFrameRegistersToWorklist 1.76 (all the addSlow inline), gen2.compactOverflows 1.78
and roots.gen2Cleanup 1.54. After, only the last two remain: both are leaf loops with no call in either build (C
inlines them into their callers too; the export bodies differ by codegen, not by a call boundary). Action none.

## The check: tools/bench/gc/call-boundary.sh

```
$ tools/bench/gc/call-boundary.sh /tmp/claude-1000/cb-n-syms/lib; echo "exit $?"
ok gc.allocation.allocateObject -> gc.roots.gen2Add (1)
ok gc.allocation.allocateObject -> gc.finalize.addToQueue (1)
ok gc.collect.processWorklist -> gc.roots.gen2Add (2)
ok gc.allocation.allocateStable -> gc.roots.gen2Add (1)
ok gc.allocation.allocateTypeObject -> gc.roots.gen2Add (1)
ok gc.gen2.transfer -> gc.roots.gen2Add (1)
ok gc.collect.markCollectable -> gc.worklist.addSlow (10)
ok gc.collect.collect -> gc.worklist.addSlow (6)
ok gc.roots.addPermanentsToWorklist -> gc.worklist.addSlow (1)
ok gc.roots.addInstanceRootsToWorklist -> gc.worklist.addSlow (23)
ok gc.roots.addTcRootsToWorklist -> gc.worklist.addSlow (16)
ok gc.roots.addTempsToWorklist -> gc.worklist.addSlow (1)
ok gc.roots.addFrameRootsToWorklist -> gc.worklist.addSlow (8)
ok gc.roots.addFrameRegistersToWorklist -> gc.worklist.addSlow (1)
ok gc.collect.collect -> gc.worklist.create (1)
ok gc.collect.collect -> gc.worklist.presizeFor (1)
ok gc.orchestrate.runGc -> gc.finalize.walkQueues (1)
ok gc.collect.collect -> gc.collect.markCollectable (1)
call-boundary.sh: all 18 rows satisfied in /tmp/claude-1000/cb-n-syms/lib/libmoar.so
exit 0

$ tools/bench/gc/call-boundary.sh /tmp/claude-1000/ng-n-syms/lib; echo "exit $?"
call-boundary.sh: FAIL gc.allocation.allocateObject does not call gc.roots.gen2Add in /tmp/claude-1000/ng-n-syms/lib/libmoar.so
exit 1

$ tools/bench/gc/call-boundary.sh /tmp/claude-1000/ng-n-base/lib; echo "exit $?"
nm: /tmp/claude-1000/ng-n-base/lib/libmoar.so: no symbols
call-boundary.sh: symbol gc.allocation.allocateObject (row gc.allocation.allocateObject -> gc.roots.gen2Add) is not defined in /tmp/claude-1000/ng-n-base/lib/libmoar.so
exit 2
```

The ng-n-syms run is the negative test: the Campaign 6 binary inlines gen2Add into allocateObject. The stripped
ng-n-base gives the missing-symbol exit. Rows are checked in table order, each for its symbols and then its call, so
the negative test stops at row 1 even though ng-n-syms also lacks the later rows' `gc.worklist.create` symbol.

## Tests

`zig build test`: 105/105 steps succeeded (176/188 tests passed, 12 skipped), at 782a56faa and again at c5aebb78a.
`zig build unit-test -Dgc-debug=1`: gc-test 66 pass (66 total), at both commits. Exports: `nm -D --defined-only`
2850 names in cb-n-syms, the same set as ng-n-syms and ng-c-syms.
