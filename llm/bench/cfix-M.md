# cfix area M: the GC worklist's 32-bit counts (M1) (Task 4)

```
Branch:    vmarray-mark-presize, from origin/main f112c3998, in P (local only, not pushed)
Commit:    e9dee2a3e7c3f1f847c8d6f6ec22870188f71622 "Make the GC worklist's item counts 64-bit"
Diff:      src/gc/worklist.h +3 -3, worklist.c +1 -1, collect.c +10 -10, roots.c +1 -1 (15/15 lines)
Status:    found by reading, NOT reproduced (it needs an object array of about 2**31 elements: 16 GiB of
           slots plus a worklist of the same size; this machine has 32 GB and no swap). Not tried.
Prefixes:  /tmp/claude-1000/cfix-M (defaults), /tmp/claude-1000/cfix-M-asan (--asan --no-mimalloc), from
           `git archive` copies /tmp/claude-1000/cfix-src-M{,-asan}; the four built files are byte-identical
           to the branch's; make exit 0, 11 s / 22 s, no warning in src/gc (729 in all, as cfix-T)
nqp/rakudo: Task 1's builds, only the libmoar swapped (Rakudo's dynops, src/vm/moar/ops/perl6_ops.c, do not
           use the worklist, so the old header they were compiled with does not matter here)
Raw:       cfix-M-raw/worklist-arith.c and its outputs worklist-arith.{old,new}.txt (the arithmetic, by
           program), cfix-M-raw/repro/, cfix-M-raw/cmp.txt, cfix-M-raw/suites/, cfix-M-raw/build/
```

## 1. Evaluation

**The defect** (cfix-baseline.md section 3, completed here). `VMArray_gc_mark` (VMArray.c:68-109) calls
`MVM_gc_worklist_presize_for(tc, worklist, elems)` with `elems` an MVMuint64; the parameter is MVMint32
(worklist.c:24, worklist.h:113), the worklist's `items` and `alloc` are MVMuint32 (worklist.h:21-25), and
the loops that follow use the `_nocheck` adds (worklist.h:83-101), which trust the presize. Two failures,
by threshold:
- **from about 2**31 entries: the growth path.** `MVM_gc_worklist_add_slow` doubles `alloc`
  (worklist.c:15-17). Once `alloc >= 2**31` the doubling wraps in 32 bits to `2 * alloc - 2**32`, which is
  smaller than `items` (0 when alloc is exactly 2**31); the list is reallocated to it and the next store
  goes past it. A full collection adds every slot of an object array (`include_gen2` adds even null slots),
  so after an array of E elements the list holds `items + E` entries and is exactly full; the next marked
  object's first two children reach add_slow. So an array of about 2**31 - items elements is enough, even
  though for `E < 2**32 - items` the presize itself is right (the MVMint32 is negative for E >= 2**31, but
  `items + (MVMint32)E` is computed in MVMuint32 and comes out right).
- **from 2**32 entries: the presize.** Once `items + E >= 2**32` the sum wraps; the presize allocates too
  little (for E = 2**32 + 16 it allocates nothing new: the parameter is 16) and the `_nocheck` adds write
  past the list, and `items` itself wraps.
The same holds for MVMHash's gc_mark (`presize_for(2 * elems)`, MVMHash.c:60, a hash of 2**30 entries) and
any worklist that grows past 2**31 entries by ordinary adds.

**By program** (`cfix-M-raw/worklist-arith.c`): the counter arithmetic of worklist.{h,c} mirrored without
the memory (each store checked against the capacity of the last (re)allocation), compiled with upstream's
types (-DOLD) and with the branch's; scenario: a list of 100 items (alloc 256), presize for E, E `_nocheck`
adds, then 1000 steps of get-one, add-two (checked). Output (`worklist-arith.old.txt`, `.new.txt`):

```
upstream (MVMuint32 items/alloc, MVMint32 presize count)
E = 1000000     alloc after presize 1000100     no write past the list (1000 steps)
E = 2147483000  alloc after presize 2147483100  no write past the list (1000 steps)
E = 2147483548  alloc after presize 2147483648  WRITE PAST THE LIST: checked add (add_slow) (step 0): index 2147483648 >= capacity 0
E = 2147483648  alloc after presize 2147483748  WRITE PAST THE LIST: checked add (add_slow) (step 0): index 2147483748 >= capacity 200
E = 3221225472  alloc after presize 3221225572  WRITE PAST THE LIST: checked add (add_slow) (step 0): index 3221225572 >= capacity 2147483848
E = 4294967000  alloc after presize 4294967100  WRITE PAST THE LIST: checked add (add_slow) (step 0): index 4294967100 >= capacity 4294966904
E = 4294967312  alloc after presize 256         WRITE PAST THE LIST: _nocheck add (step 156): index 256 >= capacity 256
E = 8589934592  alloc after presize 256         WRITE PAST THE LIST: _nocheck add (step 156): index 256 >= capacity 256
fixed (MVMuint64 items/alloc and presize count)
(every E: alloc after presize = E + 100, no write past the list in 1000 steps)
```

(E = 2147483000 survives the 1000 steps only because its alloc is still below 2**31; its next doubling is
fine, the one after would not be.)

**Option (ii), a fallback in VMArray_gc_mark to the checked add: not correct.** The checked add is
`add_slow`, whose 32-bit doubling is the first failure above; and `items` cannot count past 2**32 - 1 in
any case. Today, a VM holding such an array with a correct presize still corrupts the heap in the first
full collection that marks it (from about 2**31 entries), so a fallback would only move the failure.

**Option (iii), a structural limit: no.** The limit is the counters' width, not memory layout: with 64-bit
counts a worklist of 2**32 entries is a 32 GiB allocation like any other, and a machine that can hold such
an array (256 GiB servers exist) can collect it.

**Option (i), widen the counts: small, contained, correct by reading; implemented.** Every reader and writer
of the fields, from `git grep` on f112c3998 (all variables of type MVMGCWorklist * are named `worklist`, 139
declarations, or `gcwl`, heapsnapshot.c; the JIT's `list->items` are a different struct, MVMJitTileList):
- worklist.h: the struct (21-28); `MVM_gc_worklist_add` in both the MVM_GC_DEBUG and the normal variant
  (`items == alloc`, `list[items++]`); the three `_nocheck` macros (`list[items++]`); `MVM_gc_worklist_get`
  (`items ? list[--items] : NULL`); the prototype of presize_for (113). All work unchanged on MVMuint64.
- worklist.c: create (`items = 0`, `alloc = 256`, `alloc * sizeof`), add_slow (doubling: cannot wrap for any
  list that fits in memory), presize_for (the parameter: now MVMuint64; `items + count` cannot wrap), destroy.
- collect.c: process_worklist's `gen2count` (168, 330) and the `max`/`k` loop over the entries added while
  marking (337-339): MVMuint32 copies of `items`, now MVMuint64; eight GCDEBUG_LOG lines (65, 73, 113, 116,
  122, 127, 137, 143) print `items` with `%d`: now `%"PRIu64"`. These are compiled even with logging off
  (`if (0) printf(...)`), so `-Wall` checks them: compiling the branch's collect.c with the old formats gives
  8 -Wformat warnings, with the new ones 0 (the build's own gcc command for collect.o, gcc 16.2.1).
- roots.c: `MVM_gc_root_add_gen2s_to_worklist`'s `items_before_mark` (344, 354), now MVMuint64.
- Readers of `include_gen2` (its offset moves): the add macros, MVMHash.c:61, SCRef.c:72/91, VMArray.c:84/98:
  all compiled against the header.
- Users through the API only: heapsnapshot.c (`ss->gcwl`), debugserver.c:3846, the gc_mark functions of every
  REPR (85 files mention MVMGCWorklist), and the seven presize_for calls (HashAttrStore.c:49, MVMHash.c:60,
  SCRef.c:71/90, VMArray.c:83/97, roots.c:339; the "11" of cfix-baseline.md counted the definition, the
  prototype and two comments). Every caller passes a non-negative count; widening the parameter only stops
  truncating it.
- Nothing in src/jit, src/spesh or src/debug touches the fields or knows the struct layout.

What else the change does: the struct grows from 24 to 32 bytes (one per worklist; created per collection
run and per heap snapshot); code compiled against the old header that uses the worklist macros (a REPR's
gc_mark in an extension) must be rebuilt; the counters' stores are 64-bit. Performance was not measured.

## 2. The change

```c
 src/gc/worklist.h:  MVMuint32 items;  ->  MVMuint64 items;
                     MVMuint32 alloc;  ->  MVMuint64 alloc;
                     presize_for(..., MVMint32 items)  ->  presize_for(..., MVMuint64 items)
 src/gc/worklist.c:  the same parameter
 src/gc/collect.c:   MVMuint32 gen2count; MVMuint32 max, k  ->  MVMuint64; 8 x "%d items" -> "%"PRIu64" items"
 src/gc/roots.c:     MVMuint32 items_before_mark  ->  MVMuint64
```

VMArray.c is not changed: its MVMuint64 `elems` now reaches presize_for whole. `git merge-tree` with each of
the other six fix branches: clean.

## 3. Evidence on this machine

- No reproducer (not reachable here; `cfix-repro/M1-mark-presize-int32.nqp` stays guarded and was not run).
- Every reproducer, plain and ASAN (`run-all.sh -p cfix-M`, `-p cfix-M-asan`, 98 outputs; `cmp.txt`): 95 same,
  3 differ, all noise that varies on the baseline too: B1's raku program, O1 int64, and the plain B-buf-grid
  (`cfix-B-raw/grid-check.py base cfix-M --unchanged`: 128 lines of bytes read past a block differ, 0 others).
- Suites (section 4): the collector runs throughout both.

## 4. Suites

`cfix-maketest-driver.sh cfix-M-raw/suites cfix-M` (probes map `/tmp/claude-1000/cfix-M/lib/libmoar.so`):

| project | exit | Files / Tests | Result | per-file list vs cfix-base |
|---|---:|---|---|---|
| nqp 305ff2f77 | 0 | 150 / 13746 | PASS (18 s, load 1.22) | identical (`diff` empty) |
| rakudo c6d6fc3c6b | 0 | 599 / 11162 | PASS (128 s, load 1.35) | identical (`diff` empty) |

## 5. Draft PR text

Title: **Make the GC worklist's item counts 64-bit**

Body:

> I found this by reading the code and have not reproduced it. Reproducing it needs an object array of
> about 2**31 elements, which is 16 GiB of slots plus a worklist of the same size, and that is more memory
> than the machine I found it on has.
>
> The worklist's `items` and `alloc` were MVMuint32, and `MVM_gc_worklist_presize_for` took its count as
> MVMint32. VMArray's gc_mark passes the array's `elems`, an MVMuint64, to that presize, then adds one
> entry per slot with the `_nocheck` macros. A full collection adds every slot of an object array, null or
> not. Two things go wrong, at two sizes:
>
> - Once `alloc` reaches 2**31, the doubling in `MVM_gc_worklist_add_slow` wraps in 32 bits. The result is
>   smaller than `items`, and exactly 0 when `alloc` is 2**31. The list is reallocated to that size and the
>   next add writes past it. After an array's slots are added, the list is exactly full, so the first object
>   marked next gets there. An array of about 2**31 elements is enough, although the presize itself still
>   comes out right at that size: the MVMint32 is negative, but the unsigned 32-bit sum is correct.
> - Once `items + elems` reaches 2**32, the presize sum wraps too. The presize allocates too little (for
>   2**32 + 16 elements, nothing at all), the `_nocheck` adds write past the list, and `items` wraps.
>
> MVMHash's gc_mark (`2 * elems`) and any worklist that grows that far by ordinary adds have the same
> limits. Adding a fallback to the checked add in VMArray would not help, because the checked add is where
> the first problem happens.
>
> This change makes `items`, `alloc` and presize_for's count MVMuint64. So are the two local copies of
> `items`, in process_worklist and MVM_gc_root_add_gen2s_to_worklist. The GC debug log lines that print
> `items` now use PRIu64; they are compiled even with logging off, and with `%d` they would give eight
> -Wformat warnings. With 64-bit counts, neither the presize sum nor the doubling can wrap for any list that
> fits in memory. To check the arithmetic without the memory, I mirrored the counter code of worklist.{h,c}
> in a small C program, with every store checked against the last allocation's size. With the old types,
> arrays of 2**31 - 100, 2**31, 3 * 2**30, 2**32 - 296, 2**32 + 16 and 2**33 elements all write past the
> list. With the new types none of them do. Smaller sizes behave the same with both.
>
> The struct grows by 8 bytes and `include_gen2` moves. Inside MoarVM, every user of the fields is
> compiled against the header: worklist.c, the macros, the two functions above, and the gc_mark functions
> that test `include_gen2`. Nothing in the JIT or spesh knows the layout. Code built against the old header
> that uses the worklist macros (a REPR's gc_mark in an extension) has to be rebuilt; Rakudo's dynops don't
> use them. I have not measured performance. If 64-bit counts on 32-bit hosts are unwelcome, `size_t`
> would do as well (a list cannot hold more entries than the address space); I can change it. `make test` of nqp and Rakudo gives the same per-file results
> as before.
>
> Found by reading while porting the VMArray REPR to Zig; not reproduced.
>
> 🤖 Generated with [Claude Code](https://claude.com/claude-code)
