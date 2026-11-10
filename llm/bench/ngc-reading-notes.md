# ngc reading notes: what the native reading of each GC file made visible

The "## Reading notes" sections of the Zig-native GC campaign's file-task reports (spec 1: what the native reading
made visible), collected at Task 9 and copied verbatim, one section per file of `src/zig/gc/`. Sources (the
implementers' reports, kept in the session's `.superpowers/sdd/2026-11-09-zig-native-gc/`, not in a repository):
`task-3-report.md` (view.zig, atomic.zig, worklist.zig, allocation.zig; four paragraphs), `task-4-report.md`
(gen2.zig), `task-5-report.md` (roots.zig), `task-6-report.md` (collect.zig; its later "Fix report" for ruling R10 is
not a reading note and is not copied), `task-7-report.md` (wb.zig, objectid.zig, finalize.zig, debug.zig; eleven
bullets, split by the file each names), `task-8-report.md` (orchestrate.zig). A report covering several files is
split by file at paragraph or bullet boundaries; Task 3's fourth paragraph (the temp-root push of allocation.zig and
the fence of atomic.zig) is kept whole under a combined heading, since the split would fall inside it. No word is
changed.

## view.zig

From task-3-report.md (third paragraph).

**The flag writes are whole-byte stores, not bit sets.** `st->header.flags1 = MVM_CF_STABLE` relies on the block
being zeroed. `view.flags1(h).* = .{ .stable = true }` makes it visible that every other flag is cleared. It also
showed why the C writes the flag first: it is what justifies viewing the block as an STable or frame. With
`asStable`/`asFrame` checking at debug 1, setting the flag first is now required in Zig as well.

## atomic.zig

No paragraph of the reports is about atomic.zig alone. Its fence note ends Task 3's fourth paragraph, under
"allocation.zig and atomic.zig" below; the status type it defines is read in Task 3's second paragraph (allocation.zig)
and in Task 8's notes 1, 2 and 6 (orchestrate.zig).

## worklist.zig

From task-3-report.md (first paragraph).

**`include_gen2` was a byte standing in for a bool.** The C gives `MVM_gc_worklist_create` an `MVMuint8`. Every
caller passes 0 or 1 (`gen != MVMGCGenerations_Nursery`, the literal 1 in heapsnapshot.c and the tests), and every
reader tests it for truth (`worklist.h:55,72`, `SCRef.c:72,91`). The typed `create(tc, include_gen2: bool)`
records that; the wrapper's `!= 0` keeps a hypothetical 2 meaning true, and it would store 1 instead, which no
reader can tell apart. The same holds for `presize_for`'s `MVMint32 items`: added to an `MVMuint32` in unsigned
arithmetic, a negative count would shrink `alloc` below `items` and the next fast-path store would overrun. The
signed type was wrong, and nothing passes a negative. The native signature is `u32`, and the wrapper's `@bitCast`
keeps the C arithmetic for an outside caller. The four worklist functions also take a `tc` they never use. That is
the C API's shape, so only the wrappers take it now.

## allocation.zig

From task-3-report.md (second paragraph).

**`allocate_nursery`'s null result was unreachable.** The faithful port declared `var allocated: ?*anyopaque =
undefined` and nested the work in `if (size > 0) { … } else panic`. Written natively, the 0-byte branch is a guard
(`MVM_panic` is `noreturn`) and the result is always the bump pointer, so the function returns `*anyopaque`. The
C's if/else also hid that the interrupt check comes before the 0-byte panic: the order is kept. Reading
`gc_status` as a typed word showed that the allocator's `if (tc->gc_status)` tests the whole word, not the
`MVMGCStatus` field. A pending suspend request alone (status NONE, suspend REQUEST, value 4) also enters
`MVM_gc_enter_from_interrupt`. The native code keeps the whole-word test, with a comment, because `.status !=
.none` would change that decision. That is the trap orchestrate's typed sites will have to avoid.

## allocation.zig and atomic.zig

From task-3-report.md (fourth paragraph, kept whole).

**Some C idioms have no Zig need.** `MVMROOT`'s `__MVM_gc_root_temp_push_nonvoid(tc, ref, chain_in)` returns a
dummy `MVMuint8` and takes an unused argument only so the C macro can chain the pushes in a `for` header.
translate-c turned it, and the `MVM_STATIC_INLINE` push under it, into separate `callconv(.c)` functions, which is
how the faithful port paid a call per root (the profile's +1.78e8 cycles). Written from `roots.h`, the push is
seven lines that inline. The C macro's scope becomes `defer`. The `var st = st_in` shadowing of the faithful port
is now `rooted_st`, which names the one pointer that survives a collection inside the allocation. Using the
parameter `st` after `allocateZeroed` would be a stale-pointer bug that the old naming made easy to write. Last:
the faithful fence arm `.x86, .x86_64 => "mfence"` hid that one string served two ISAs. The clang identity RMW
needs a stack register, so the two arms now differ.

## gen2.zig

From task-4-report.md.

- **The "skip" branch of transfer's owner walk is dead.** It reads `if (cur_ptr == (char *)freelist_insert_pos)`.
  `freelist_insert_pos` starts at `&size_classes[bin].free_list`, which is not in any page. After that it only ever
  points at a slot the walk has already passed, because it is set to `cur_ptr` and the cursor then moves on. Pages
  are disjoint and each slot is visited once, so the current slot never equals the link's own address. The
  comparison that matters is the second one, `cur_ptr == *freelist_insert_pos`, the next free node. The native code
  keeps both branches, because removing one is not a shape change. The typed `*?*FreeNode` link next to a `[*]u8`
  slot makes it plain that two different things are being compared. That `@intFromPtr(link)` against
  `@intFromPtr(link.*)` difference is what the C's `char ***` casts hid.
- **The owner walk only recognises free items in walk order.** Each free item matches only when it is exactly the
  next free node. A free list that is not in page-and-address order would make transfer treat the out-of-order free
  slots as live and write `owner` into them. The precondition holds: collect.c's sweep (collect.c:641-753) threads
  the free list in walk order, and `allocate` only pops the head, so the list stays a sorted suffix. It is harmless
  even when broken, because `owner` sits at offset 8 and the free link at offset 0. The C comment "we don't have
  tests that exercise this path yet" is stale: the existing transfer test exercises the else branch for 299 items.
- **NULL with a zero count is part of the protocol.** transfer leaves the source's overflows and gen2 roots NULL with
  count 0, and threadcontext.c:101 then destroys that gen2. Bins that were never set up are NULL with `num_pages` 0.
  The C's `for (i = 0; i < n; i++)` loops are fine over NULL. A Zig slice is not, so the native code needed `list()`.
  That makes visible a state of the allocator ("freed by transfer, then destroyed") that the faithful port walked
  over without noticing.
- **`allocate` cannot return NULL.** Its `void *` result is always a free-list node, a bump pointer from a page that
  was just set up, or an `MVM_malloc` block, and `MVM_malloc` panics on failure. The typed `*anyopaque` records
  this. The faithful port's `var result: ?*anyopaque = undefined` and the test's `.?` everywhere had hidden it.
- **The head field and a free item are the same shape.** Writing `FreeNode` showed that the C's single `char ***`
  cursor works only because `free_list` (a `char **` field) and the first word of a free item are both one word
  holding the next item. One accessor, `node()`, covers both, and the comptime size assertions now state that
  layout.
- **The sweep in collect.c repeats the page walk verbatim** (collect.c:660-667 against gen2.c:189-196): the same
  "last page ends at `alloc_pos`" rule. `pageItems` gives that rule one home for when collect.zig is rewritten. Both
  walks also depend on `alloc_pos` lying in the last page. That holds because `addPage` always moves `alloc_pos` to
  the new last page, and transfer appends the source's pages after the destination's and then takes the source's
  `alloc_pos`.

## roots.zig

From task-5-report.md.

- **The "40 instance roots" was never in the C.** The instance walk is 18 field roots, 4 loop and weak-hash sites,
  and 7 calls into other subsystems: spesh plan, confprog, callsite interns, the dispatcher registry or its describe
  twin, the debugserver, and the integer cache loop. Only a table makes the split visible. Those subsystems sit
  *between* the field roots (spesh plan after `spesh_queue`; confprog between `sig_arr` and the subscriptions), so
  the order of the field roots alone does not determine the worklist order.
- **Two kinds of guard hide behind the same `if (tc->x)`.** For `interp_cu` the guard tests the *slot address*
  (`MVMCompUnit **`, NULL once the thread has finished) and the root is `*(tc->interp_cu)`. For `step_mode_frame` it
  tests the *slot content*. The `when`/`get` split states which is which. The content guard on `step_mode_frame` is
  redundant: both `add_collectable` branches already skip a NULL (`MVM_gc_worklist_add` tests `*item`, and
  `MVM_profile_heap_add_collectable_rel_const_cstr` tests `collectable`). The same holds for the NULL half of the
  `cur_frame` and `thread_entry_frame` guards; only the call-stack half matters, and that half needs a non-NULL frame
  to look at.
- **The handler frame has no NULL test.** `cur_ah->frame` goes straight into `MVM_FRAME_IS_ON_CALLSTACK`, unlike
  `cur_frame` and `thread_entry_frame`. An active handler always has a frame, but the C states that only through
  this asymmetry. The native code keeps it.
- **A fresh instance already has a weak-hash entry.** The VM registers one SC at boot, so the weak-hash branch of
  the instance walk runs in every collection, even before any bytecode is loaded. The golden test found this.
- **The snapshot stores descriptions by pointer and deduplicates them by `strcmp`.** `STR_MODE_CONST` keeps the
  literal's address, so the test can tell a table root's description apart by pointer identity. If two sites with
  equal text were added later, they would share a string index in the snapshot.
- **Several C locals change type for no effect.** `tempMark` holds the u32 mark in an `MVMint32` and returns it as
  u32. `add_gen2s_to_worklist` passes a u32 count through `presize_for`'s `MVMint32`. The callback loop counts with
  `MVMint32` against an `MVMint32` `num_types`, while the mark_args loop counts with `int` against a u16
  `flag_count`. With typed signatures these become plain u32 and usize, and the round trips disappear.
- **`is_stack_frame` identifies a call-stack frame by absence**: `flags1 == 0` and `owner == 0`, a header no heap
  collectable has. Because of this, `view.asFrame` would panic on such a frame at debug 1, as it should, since that
  frame is not a heap frame. The native code uses `asFrame` only after a `flags1.frame` test.
- **The frame register scan has three type sources (JIT, spesh candidate, static frame), but only two count
  widths.** The JIT's and the static frame's counts are u32 and are truncated to the u16 count. The candidate's is
  already u16. The lexical scan has no JIT case. A static frame with no locals may have NULL `local_types` and a zero
  count, which the C loops over safely; a Zig slice would not do that without `list()`.

## collect.zig

From task-6-report.md.

- **Two different kind precedences hide in the C.** The marking and both sweeps test type object, then STable, then
  frame. The promotion in `process_worklist` tests frame first, then "neither type object nor STable", and the debug
  logs' reprid test lumps all three together. With a `switch (kind)` in three places, the fourth one stands out as a
  different order; it agrees only because no header ever carries two kind bits. The native code keeps it as flag
  tests rather than claim an equivalence the C does not state.
- **The worklist loop also stops at a NULL entry, not only at an empty list.** `while ((item_ptr =
  MVM_gc_worklist_get(...)))` ends on a NULL slot address. `worklistAdd` never pushes one, so this never happens, but
  the typed `?ColSlot` return has to fold both cases into `null` to keep the C's loop exactly.
- **`item_gen2` is read once and trusted for the rest of the iteration.** The C captures `flags2 & SECOND_GEN` at
  the top and branches on the captured value later, after the pass-work and corruption checks. As a `const bool`
  that is plain; in the faithful port it was a `var` assigned on one line and read 45 lines later.
- **`new_addr` and `to_gen2` are one decision with two outputs.** The C sets them in three places (gen2 mark, promote,
  copy) through mutable locals. A destructured `const new_addr, const to_gen2 = if (...) ... else ...` shows that
  `to_gen2` is exactly "the nursery item was promoted" and `new_addr == item` exactly on the gen2 path.
- **The "processing %d items" logs are the root-phase boundaries.** Seven add-roots / log / process triples; folding
  the last two into `drain` makes the phase list (permanents, instance, TC, temps, gen2 (nursery runs only), in-tray)
  read as a list, with `NoInstance` skipping exactly the first two.
- **The enums are bytes the C never checks.** `what_to_do` and `gen` are compared, never switched or range-checked, so
  an unknown `what_to_do` is a full main run with instance roots, and an unknown `gen` builds a gen2-including worklist
  that still neither skips gen2 items nor marks promotions live. An exhaustive Zig enum would have turned that into
  illegal behaviour; the non-exhaustive one documents it.
- **`ThreadWork` growth was already one-at-a-time and exact.** The C reallocs to `num_target_threads * 16` per new
  target with no capacity field at all, so its "capacity" is its length by construction; that is what made
  `ensureTotalCapacityPrecise(len + 1)` the faithful growth, and what made the only remaining difference the call
  kind (realloc against malloc + copy + free), which mimalloc's bins erase up to 9 targets.
  (pre-R10; the ruling made the Zig growth the C's realloc sequence, see ngc-task6-tripwire.md)
- **The in-tray take is a single-word steal.** `add_in_tray_to_worklist` takes the whole list with one CAS to NULL and
  then walks it privately; as `const taken = while (true) { ... break head; }` the "retry until stolen or empty" shape
  is one expression, and the walk after it needs no atomics. The push side (`push_work_to_thread_in_tray`) is the
  mirror: link-then-CAS.
- **`free_gen2_unmarked`'s free-list cursor is a pointer to a link, not to a node.** `char ***freelist_insert_pos`
  starts at the bin's `free_list` field and then moves to the first word of a free or freed slot; typed as
  `*?*FreeNode` it is visibly the same thing gen2.zig's `FreeNode.next` is, which also shows that the sweep links each
  dead slot in right after the last free or freed slot below it, so an address-ordered free list stays address-ordered.
- **The STable "dead last time" protocol lives in the gen2 sweep only.** A dead gen2 STable is first stamped with
  `sc_idx == 0 && idx == MVM_DIRECT_SC_IDX_SENTINEL` and skipped (not put on the free list); the next full sweep frees
  it. In global destruction it is queued instead, like nursery STables. The `continue :slot` makes the "skip the
  freelist update" path explicit; in the C it is a `cur_ptr += obj_size; continue;` that duplicates the loop's step.
- **`free_nursery_uncopied`'s debug log reads `REPR(obj)->ID` for every object, live or dead**, while `gc_free` and
  the profiler call are gated on `dead`; the log is comptime-off, so only that gate matters. The native code keeps
  both as written.

## wb.zig

From task-7-report.md (bullets 1-2).

- **The two barriers differ by one store.** `hit` and `hitBy` are the same test and `gen2Add` call; `hitBy` adds
  `ref_from_gen2` on the referenced. The collector's post-promotion barrier deliberately uses the no-update form: the
  referenced items are already on the worklist, so flagging them would force them into gen2 at their next survival
  (`ref_from_gen2` is one of the three promote reasons in processWorklist). The typed inline makes the three-test
  conjunction readable as one `if`/`if (referenced) |r|` chain.
- **Under LTO the faithful port was already inlined.** ng-f-base has no call to the exported `hit` either, so the
  "header inline called out of line" cost from Task 2's profile shows only in non-LTO builds for this site. The native
  form guarantees the inline without LTO.

## objectid.zig

From task-7-report.md (bullets 3-4).

- **`useAllocation` toggles, it does not clear.** `flags1 ^= MVM_CF_HAS_OBJECT_ID` is a clear only because every
  caller holds the flag set. The typed non-null return now states the matching precondition (the entry exists). A
  caller without the flag would silently *set* it in both C and Zig.
- **`objectId` tests `second_gen` outside the mutex.** That is safe only because promotion happens with the world
  stopped. The early-return form makes the unlocked fast path visible as a separate branch.

## finalize.zig

From task-7-report.md (bullets 5-8).

- **The two finalize queues are one algorithm over two field triples** (`finalize/num_finalize/alloc_finalize` and
  the `finalizing` ones). In the C they are written twice; the shared `append` shows they cannot drift.
- **The compacting walk is safe as a plain slice loop**, because dead entries go to the *other* queue. So
  `num_finalize` is fixed for the walk, and the write index never passes the read index.
- **`runHandler` roots only `handler`, not `drain`,** while it pushes the finalizing objects into the array. That is
  safe because `MVM_repr_push_o` on a VMArray grows with `MVM_realloc`, not the GC heap. A REPR change there would
  make it a GC hazard.
- **A stale C comment.** The comment "Returns a true value if we do so" sits above `reinstate_last_handler_result`,
  a void callback; it belonged to an older form of `run_handler`.

## debug.zig

From task-7-report.md (bullets 9-11).

- **`findRegion` treats a whole page as allocated.** It uses the full page geometry, `PAGE_ITEMS * bin size`, even
  for a size class's current page. The sweeps (`gen2.pageItems`) end that page at `alloc_pos`. So a pointer into the
  unallocated tail reports "In gen2 bin".
- **`findRegion` reads `instance->threads` plainly; the log writer and the finalize walk use `MVM_load`.** The finder
  is a debugger helper, so the inconsistency is harmless, but it is now visible side by side.
- **The log writer reads `MVMuint8 full` as `full ? 1 : 0`.** Read natively, it is a bool at the Zig level. The
  per-collection log has one line per thread context the run worked for, not one per run. The in-process test shows
  the booted VM's second context (tid 3, a 512 KiB nursery) in every collection.

## orchestrate.zig

From task-8-report.md.

What the native reading of orchestrate.zig made visible that the faithful port (and the C) hid:

1. **The C's `switch` cases are whole words, and only nine of sixteen combinations are legal.** Written as a
   `switch (current.status)` with each arm testing the whole word, `signal_one_thread` shows that of the 4 x 4
   status/suspend-state grid the C accepts NONE only without a suspend bit, INTERRUPT with none or SUSPEND_REQUEST
   (never SUSPENDED), and UNABLE and STOLEN with any of the three. INTERRUPT | SUSPENDED, NONE | SUSPEND_REQUEST and
   NONE | SUSPENDED are panics ("invalid status") at this site. The faithful port listed the cases as `|` constants and
   the asymmetry was not visible.
2. **Only one site ever writes a suspend bit onto a non-blocked thread, and only global destruction and the
   debugserver issue requests.** Reading the CAS arguments as states: SUSPEND_REQUEST is written by
   `globalDestruction` (NONE -> INTERRUPT | REQ, UNABLE -> UNABLE | REQ) and SUSPENDED only by `markThreadBlocked`'s
   second CAS (INTERRUPT | REQ -> UNABLE | SUSPENDED). The release loop in `finishGc` and the steal in
   `signalOneThread` only *carry* the suspend bits through (`suspend_bits`, `had_suspend_request`); nothing in this
   file clears them (the debugserver and the test do, by a store). That is why `INTERRUPT | SUSPEND_REQUEST` on a
   coordinator survives a run (the `if (suspend_bits == .request) break` at c:285, pinned by a test).
3. **The release loop's `else` panic is dead code.** `status_bits` is `current & 3`; all four values are handled
   before the `else`. The typed switch has no arm for it, which is the honest shape; the faithful port carried the
   panic as a reachable-looking branch.
4. **`had_suspend_request` is loop-carried state, by design.** The C sets it in the UNABLE | suspend cases and falls
   through, so a later iteration that sees plain UNABLE still CASes from UNABLE | <old bits>, which then fails and
   loops; the native code keeps the variable outside the loop and says so. A `Suspend`-typed variable makes the
   carried value's meaning explicit (the faithful `c_uint` did not).
5. **`is_thread_blocked` and the suspend-state tests are the only masked reads**; every other read of `gc_status`
   is a whole-word comparison or a CAS expectation. The TSV's "whole-word compare" column makes the split countable:
   17 whole-word sites, 7 masked ones (c:272-273 counted as one load).
6. **`Suspend` had to become non-exhaustive (R9) for a reason the C never states:** `MVMSUSPENDSTATUS_MASK` is two
   bits but only three values are named; a word with bit 3 alone is "impossible" in the C only because no store
   writes it. The typed view would have made such a word illegal behaviour at every load, which is stricter than the
   C's "compare and fall to default". With `_`, the view reads what the C reads; the new tests pin that.
7. **The work list is the coordinator's only mutable list and it never changes during a run.** `addWork` is called
   only from `signalAll`/`signalOneThread` (under `mutex_threads`, before `gc_start` is bumped) and from the two
   `addWork(tc, tc)` resets; nothing in `finishGc`'s loops can append. That is what lets the loops take the count once
   as a slice (the C re-reads `gc_work_count` each iteration).
8. **`gen2` is both a module and a field** (`tc.gen2`), so the import is `gen2_mod` as in collect.zig; and the C's
   local `instance` in `run_gc` is an *object* (a GCEvent instance), renamed `event` here with a note, since
   `instance` is `tc.instance` everywhere else in the file.
9. **`MVM_trycas` is the odd one out.** It is the only `gc_status` operation that returns a flag, not the previous
   value, so it is the one site that cannot be a `casStatus(...) == expected` without changing the spelling of the
   operation; it stays `moar.trycas` over `word(state)`, which is the same cmpxchg.
