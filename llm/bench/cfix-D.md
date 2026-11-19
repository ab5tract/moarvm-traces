# cfix area D: deserialization holds fresh collectables only in C locals across read_ref (D1) (Task 5)

```
Branch:    serialization-root-array-var, from origin/main f112c3998, in P (local only, not pushed)
Commits:   edc33817c08c0b672c4ba4feef8ea88fb3ea15c4 "Root the result of read_array_var and read_hash_str_var across read_ref" (D1)
           830eb45e2d94fcf1c70173feccbedc46bd399da2 "Root the frame deserialize_context fills across read_ref" (D1, same defect, third site)
Diff:      src/6model/serialization.c +19 -5, three hunks: read_array_var, read_hash_str_var, deserialize_context
Status:    found by reading, NOT reproduced. No stress attempt was made (optional; not tried).
Prefixes:  /tmp/claude-1000/cfix-D (defaults: gcc -O3, mimalloc), /tmp/claude-1000/cfix-D-asan (--asan
           --no-mimalloc), from `git archive` copies /tmp/claude-1000/cfix-src-D{,-asan}
           (cfix-T-raw/build/export-build.sh, unchanged; driver cfix-N-raw/build/build-all.sh); the built
           serialization.c is byte-identical to the branch's; make exit 0, 11 s / 21 s, no warning in
           serialization.c (729 / 725 warnings in all, as every earlier prefix)
nqp/rakudo: Task 1's builds (nqp 305ff2f77, rakudo c6d6fc3c6b in cfix-base and /tmp/claude-1000/cfix-ws), only
           the libmoar swapped through LD_LIBRARY_PATH
Raw:       cfix-D-raw/repro/ (run-all on both prefixes), cfix-D-raw/cmp.txt, cfix-D-raw/suites/,
           cfix-D-raw/build/
```

## 1. The argument, re-verified step by step against f112c3998

1. **What holds what.** `read_array_var` (serialization.c:1805-1823) allocates `result` with
   `MVM_gc_allocate_object(BOOTArray)` and, per element, calls `MVM_serialization_read_ref` and then
   `MVM_VMArray_bind_pos` into `result`. Until `MVM_sc_set_obj_sc` and the return, `result` is referenced
   only by the C local. `read_hash_str_var` (1827-1849) has the same shape for a BOOTHash, and also holds
   `key`, from `MVM_serialization_read_str`, across `read_ref`.
2. **Gen2 on every path, so no move.** `read_ref` asserts `tc->allocate_in_gen2` (1904). read_array_var has
   two callers: `read_ref` (1939) and `deserialize_stable` (2631); read_hash_str_var has one, `read_ref`
   (1954). All of them run inside `MVM_serialization_deserialize` (gen2 set 3202, cleared 3273) or the demand
   functions (`demand_object` 2872-2885, `demand_stable` 2929-2942, `demand_code` 2966-2978). The counter
   is nested (allocation.h:26-35). `MVM_gc_allocate` takes the gen2 branch when it is set
   (allocation.h:12-16), and only the nursery branch checks for a GC interrupt or starts a collection
   (allocation.c:19-38). So `result` is in gen2, gen2 objects never move, and this thread cannot itself
   start or join a collection through allocation here.
3. **read_ref can block.** `read_ref` → `read_obj_ref` (1797-1802) → `MVM_sc_get_object` (sc.c:216-222),
   which calls `MVM_serialization_demand_object` when the slot is empty **or the SC is still working**
   (`sc_working`). demand_object locks the SC's reentrant mutex (`MVM_reentrantmutex_lock`). When another
   thread holds it, the lock marks this thread blocked around `uv_mutex_lock` (ReentrantMutex.c:145-149).
   The same holds for code references (`read_code_ref` → `MVM_sc_get_code`, sc.c:350-357 →
   `demand_code`).
4. **A collection can run meanwhile, with this thread's work stolen.** `MVM_gc_mark_thread_blocked` sets
   the thread's status to UNABLE (orchestrate.c:323-330). The thread coordinating a collection CASes
   UNABLE to STOLEN and does this thread's work itself (orchestrate.c:45-52). That work marks from this
   thread's roots, including its temporary roots (roots.c:245-252), but not from C locals.
5. **A full collection frees unmarked gen2 objects** of every thread it processed:
   `MVM_gc_collect_free_gen2_unmarked(tc, other, 0)` when `gen == MVMGCGenerations_Both`
   (orchestrate.c:217-223). `result` is unmarked, so it is freed, and the next `bind_pos` writes into freed
   memory.
6. **`key` can move, not be freed.** It is reachable: from the reader's string heap (an array of strings,
   when the SC was deserialized with a string heap list; marked through the SCRef, SCRef.c:104) or from the
   compilation unit's string table (`MVM_cu_string`). The compilation unit's strings are decoded in gen2
   (`MVM_cu_obtain_string` sets the gen2 default, compunit.c:251-256). The strings of a runtime string heap
   list can be in the nursery, and a nursery collection run with this thread's work stolen moves them,
   which leaves the C local stale for `MVMHash_bind_key`.

**The fix** roots `result` across each `read_ref` call in read_array_var (`MVMROOT`). In
read_hash_str_var it roots `result` and `key` across the call (`MVMROOT2`). This is the file's own style:
`read_param_intern` roots its `params` array across `read_obj_ref` (2483-2488), and frame.c's
`create_context_only` roots its frame across `MVM_sc_get_object` (frame.c:173). Only the call that can
block is wrapped. `read_str` does not block (step 7), so `result` need not be rooted across it.

## 2. The other read_* helpers and their callers in serialization.c

I looked for the same shape: an object allocated, then held only in a C local across a call that can
block or allocate. Search: every `MVM_gc_allocate_object`, `MVM_repr_alloc_init`,
`MVM_frame_create_context_only` and `MVM_repr_clone` in the file's reading half (1700-3280), and every
`read_ref` / `read_obj_ref` / `read_code_ref` / `MVM_sc_get_*` call site (grep list in the report).
The search does not cover REPR deserialize functions in other files, which receive the reader. Those
deserialize into objects the SC already roots.

| site | held across | verdict |
|---|---|---|
| read_array_var `result` (1806) | read_ref | **same defect: fixed** |
| read_hash_str_var `result`, `key` (1828, 1838) | read_ref | **same defect: fixed** |
| **deserialize_context `f` (2314)** | read_ref of each object lexical (2342-2344), until `reader->contexts[row] = f` (2349) | **same defect, same path: fixed (second commit).** `f` is a fresh heap frame, allocated in gen2 (it runs under `demand_code`, the only caller of `deserialize_closure`, 2966-2978) and referenced by nothing until it is stored in `reader->contexts` (marked by SCRef.c:90-101). `read_ref` can block as in step 3; a full collection would free the frame and the next `MVM_ASSIGN_REF` writes into it. |
| read_array_int `result` (1852) | `MVM_serialization_read_int` only | no call that allocates or blocks: safe |
| read_array_str `result` (1871) | `MVM_serialization_read_str` | step 7: no window: safe |
| read_ref `REFVAR_VM_STR` `result` (1935) | read_str | same: safe |
| read_ref `REFVAR_VM_NUM` `result` (1931) | `read_num` | no allocation: safe |
| read_ref `ARR_VAR` / `HASH_STR_VAR` `result` after the helper (1939-1960) | `MVM_VMArray_push` into `owned_objects` | push only reallocs (no GC allocation, no lock): safe |
| deserialize_stable parameterized `ptype` (2630) | read_array_var (2631) | **not the same shape** (not allocated here; reported). ptype is an object of an SC, reachable from it. It cannot be freed. It could move only if it were a nursery object, which needs an SC object that was never promoted. Objects created by deserialization are in gen2. A compile-time SC object referenced by an SC deserialized at runtime might be in the nursery. Not fixed: not this defect, and not shown reachable. |
| deserialize_stable `lookup` (2616, 2640) | nothing (stored at once) | safe |
| read_param_intern `params` (2480) | read_obj_ref | already rooted (2483) |
| deserialize_closure `closure` (2386) | `MVM_sc_get_object` (2395) | stored in `reader->codes_list` before the call (2387-2388): reachable; gen2 (under demand_code): cannot move. Safe |
| deserialize_context `static_code` (2309) | `MVM_frame_create_context_only`, read_ref | from the SC's codes / the compilation unit's coderefs, reachable; coderefs are created under gen2 (bytecode.c, `MVM_bytecode_unpack` sets the default at its start): safe |

**Step 7, why read_str opens no window.** `MVM_serialization_read_str` → `read_string_from_heap`
(1521-1540) either indexes the string heap array (`MVM_repr_at_pos_s`, no allocation) or calls `MVM_cu_string`
→ `MVM_cu_obtain_string` (compunit.c:217-257). That decodes in gen2 and takes no lock that marks the
thread blocked. NFG synthetic creation takes `nfg->update_mutex` with a plain `uv_mutex_lock`
(nfg.c:224), so no collection can complete while a thread waits there. This is an argument from reading.
I did not check every function the decoders call.

## 3. Evidence

No reproducer exists. None was fabricated, and no stress attempt was made. A program that could show
it would need two threads, lazy deserialization of a BOOTArray- or BOOTHash-valued slot (or a closure's
context) whose elements are in a second SC that the other thread is deserializing at that moment, and a
full collection started by a third party in that window, with ASAN or MVM_GC_DEBUG to see the
use-after-free. The other reproducers show nothing changed (section 4), and the suites show no regression
(section 5).

## 4. Every reproducer: unchanged

`run-all.sh -p cfix-D -o cfix-D-raw/repro` and `-p cfix-D-asan` (62 program/case pairs each, 124 outputs).
`cfix-N-raw/cmp-repro.sh cfix-D-raw/repro D` (`cfix-D-raw/cmp.txt`): 120 same, 4 differ, all noise:
- B1's raku program, and B-buf-grid (plain): bytes past a block, which vary run to run.
- O-buf-type-cases `rebind` (plain): element 99 is read 664 bytes past the buffer, a different value each
  run.
- E-encode-state (plain): upstream overruns the buffer in its `emptied` cases (bug E2), and the run then
  crashes at a point that varies run to run (cfix-E.md section 3). Its result lines agree with upstream's
  as far as both go (`cfix-E-raw/prefix-cmp.txt`, also per kind).

## 5. Suites

`cfix-maketest-driver.sh cfix-D-raw/suites cfix-D` (probes map `/tmp/claude-1000/cfix-D/lib/libmoar.so`;
run on the branch's final tree):

| project | exit | Files / Tests | Result | per-file list vs cfix-base |
|---|---:|---|---|---|
| nqp 305ff2f77 | 0 | 150 / 13746 | PASS (18 s, load 0.93) | identical (`diff` empty) |
| rakudo c6d6fc3c6b | 0 | 599 / 11162 | PASS (124 s, load 0.93) | identical (`diff` empty) |

## 6. Draft PR text

Title: **Root objects that deserialization holds only in C locals across read_ref**

Body:

> Three places in the deserializer allocate a collectable and then hold it only in a C local while
> calling `MVM_serialization_read_ref`: read_array_var (a BOOTArray), read_hash_str_var (a BOOTHash, and
> also the key it just read) and deserialize_context (the heap frame for a closure's outer context). This
> roots them across that call, as read_param_intern already roots its array and create_context_only its
> frame. I found this by reading. I have not reproduced it.
>
> Why it matters, although nothing can move there: every path into these functions runs with gen2 as the
> allocation default (`MVM_serialization_deserialize` and the demand functions set it), so the objects
> are in gen2 and this thread's own allocations cannot start a collection. But `read_ref` can block.
> Resolving an object or code reference calls `MVM_sc_get_object` / `MVM_sc_get_code`, which go to
> `MVM_serialization_demand_object` / `demand_code` when the target's SC has not stubbed it yet or is still
> being deserialized, and those take that SC's reentrant mutex. When another thread holds it,
> `MVM_reentrantmutex_lock` marks this thread blocked while it waits. Another thread can then run a
> collection with this thread's work stolen. A full collection frees every unmarked gen2 object of the
> threads it processed, and these objects are unmarked: the next bind_pos, bind_key or `MVM_ASSIGN_REF`
> into them writes into freed memory. The key cannot be freed (the reader's string heap or the compilation
> unit's string table holds it), but a key from a string heap list given at runtime can be a nursery
> string, which such a collection moves.
>
> To hit it you need two threads lazily deserializing SCs that refer to each other (an array, hash or
> closure context in one SC whose elements are in another that the other thread is deserializing right
> then) and a full collection in that window. I don't have a program that does that reliably.
>
> I checked the other helpers in the file for the same shape. read_array_int holds its array only
> across read_int. read_array_str and the VM_STR case of read_ref hold theirs across read_str, which does
> not block. The parameter loop in read_param_intern is already rooted. deserialize_closure puts its
> clone into the codes list before it calls anything. `make test` of nqp and Rakudo gives the same
> per-file results as before.
>
> Found by reading while porting the VMArray REPR to Zig.
>
> 🤖 Generated with [Claude Code](https://claude.com/claude-code)
