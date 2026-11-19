# cfix baseline: unmodified origin/main builds, a reproducer for every bug, and the classification (Task 1)

(Revised at Task 1's fix round 1: E2 added, S/P/R/O/E/D/M rulings applied, wording corrected.)

```
Plan:      traces/llm/plans/2026-11-19-vmarray-c-fixes.md, Task 1 (the bug table: section "The bugs")
MoarVM:    origin/main f112c3998, checked out in P as local branch cfix-baseline, built from `git archive`
           copies (P itself is not built in): /tmp/claude-1000/cfix-base (defaults: gcc -O3, mimalloc) and
           /tmp/claude-1000/cfix-asan (--asan --no-mimalloc); moar --version "2026.11" (VERSION file, no .git)
nqp:       305ff2f77 (= nqp origin/main), rakudo c6d6fc3c6b (= rakudo origin/main), both `git archive`d from
           the local checkouts (read only) into /tmp/claude-1000/cfix-ws/{nqp,rakudo}, built and installed
           into cfix-base. Checkouts: nqp at 41e7210ba, rakudo at 042608fb82, `git status --short` empty
           before and after
Raw:       cfix-baseline-raw/build/ (scripts, configure logs, gzipped make logs, info), cfix-baseline-raw/ifunc/
           (memcpy/memmove binding check), cfix-baseline-raw/repro/
           (every reproducer's output: <file>[.<case>].{base,asan}.txt), cfix-baseline-raw/suites/ (make test)
Programs:  cfix-repro/*.nqp, *.raku (header of each: what it does, what a correct VM prints, what the bug
           does), cfix-repro/run.sh (one program, both builds), cfix-repro/run-all.sh (all of them),
           cfix-maketest-driver.sh (the suites, any prefix)
```

## 1. What runs under what

| run | runner | libmoar it maps (probe, see below) |
|---|---|---|
| plain reproducer | `/tmp/claude-1000/cfix-base/bin/nqp-m` or `rakudo-m` with `LD_LIBRARY_PATH=/tmp/claude-1000/cfix-base/lib` | `/tmp/claude-1000/cfix-base/lib/libmoar.so` |
| ASAN reproducer | the same runners, `LD_LIBRARY_PATH=/tmp/claude-1000/cfix-asan/lib LD_PRELOAD=/usr/lib/libasan.so.8 ASAN_OPTIONS=detect_leaks=0:abort_on_error=0:symbolize=1` (LD_LIBRARY_PATH wins over the runners' RUNPATH) | `/tmp/claude-1000/cfix-asan/lib/libmoar.so` |
| nqp `make test` | `/tmp/claude-1000/cfix-ws/nqp`, `LD_LIBRARY_PATH=/tmp/claude-1000/cfix-base/lib` | `/tmp/claude-1000/cfix-base/lib/libmoar.so` |
| rakudo `make test` | `/tmp/claude-1000/cfix-ws/rakudo`, the same | `/tmp/claude-1000/cfix-base/lib/libmoar.so` |

The probe is a separate process (the same runner, a one-line program printing the libmoar line of its
`/proc/self/maps`) started with the same environment just before each run, not the reproducer process
itself; its result is the first line of every output file in `cfix-baseline-raw/repro/` and the
`*.probe` files of the suites. A fix branch's
libmoar is used the same way: `run.sh -p cfix-<area> PROGRAM`, `run-all.sh -p cfix-<area>`,
`cfix-maketest-driver.sh OUTDIR cfix-<area>` (same nqp and rakudo bytecode, only the libmoar changes).

Every reproducer run: `ulimit -c 0`, `timeout` (60-120 s), `systemd-run --user --scope -q -p MemoryMax=4G
-p MemorySwapMax=0` (2G for G1, G2, N2). "timeout: the monitored command dumped core" in an output is
timeout's wording for a signal death; no core was stored (`coredumpctl`: COREFILE none for all of them).

## 2. Classification

20 bugs (the plan's 19 and E2, added at the Task 1 review): **17 reproduced, 1 not reachable here (M1),
1 not a bug (G2), 1 needs a decision → ruled: found-by-reading PR (D1).** "plain" is cfix-base, "ASAN"
cfix-asan; file names are under `cfix-repro/` and `cfix-baseline-raw/repro/`.

| id | verdict | program | plain build | ASAN build |
|---|---|---|---|---|
| S1 | **reproduced**: UB on the fast path (ASAN), and on the element-by-element path a result that depends on kind and GC generation | `S1-self-splice-overlap.nqp` | fast-path kinds (i64 .. i8, OBJ in the nursery) print the memmove result here (§3); STR and an OBJ array promoted to gen2 print the forward element-wise copy: `obj gen2 1,0: 1 1 1 1 1 1 1 1 1 1 1 4 7 ...` vs `obj nursery 1,0: 1 1 4 7 10 ...` for the same splice (deterministic: identical over three runs) | `memcpy-param-overlap` in `copy_elements` at the first fast-path case ("obj nursery", offset 1: two 80-byte ranges 8 bytes apart); the "obj gen2" line before it is printed |
| G1 | **reproduced** | `G1-size-wrap.nqp` | `setelems(2**64 - 4096): returned, elems -4096`, then SIGSEGV (exit 139) reading element 10**9 | `negative-size-param: (size=-65536)` in memset (set_elems → set_size_internal → zero_slots, inlined), on address 0x10000 (realloc(p, 0) returned NULL) |
| G2 | **not a bug** (§3) | `G2-limit-boundary.nqp {over,limit,under,far}` | over (2**60+1): `DIED Unable to allocate an array of 1152921504606846977 elements`; limit (2**60), under (2**60-1), far (2**45): `MoarVM panic: Memory allocation failed; could not allocate N bytes` (exit 1) | over: the same exception; the others: `allocation-size-too-big` in malloc (ASAN's own limit) |
| P1 | **reproduced** | `P1-splice-from-non-vmarray.nqp` | SIGSEGV (exit 139) | `SEGV on unknown address 0x000000000008` in `copy_elements` (reading `s_repr_data->slot_type`) |
| P2 | **reproduced** (reachable only after recomposing a live array's type) | `P2-splice-no-storage-kind.nqp {target,source}` | SIGABRT (exit 134), no message, both cases | the same (abort is not an ASAN error) |
| P3 | **reproduced** | `P3-splice-cross-kind.nqp {int-into-obj,obj-into-int,num-from-int}`; controls `{str-into-obj,empty-other}` | int-into-obj: splice returns, then SIGSEGV in the collection; obj-into-int: element 1 is an address (a different one every run); num-from-int: `element 0 = 1` (the bits of 1.0). Controls: `str-into-obj: elems 3, element 1: MVMString` (survives a collection); `str: a c`, `u8: 1 3 (elems 2)` | int-into-obj: `SEGV on unknown address 0x0008a827a829` in `VMArray_gc_mark`; the rest as plain |
| T1 | **reproduced** | `T1-rejected-pop.nqp`, `... control` | `pop_i: DIED MVMArray: pop expected object register`, `elems now: 1`, grown back to 2, SIGSEGV using element 1; control (setelems 1 instead): `element 1: null`, exit 0 | the same up to the SEGV (in MVM_interp_run, near address 0x38); control exit 0 |
| T2 | **reproduced** | `T2-rejected-unshift.nqp`, `... control` | `unshift_i: DIED ...`, then `elems 2, element 1 is "b"` (should be "c"), SIGSEGV using element 0 (the dead "a"); control: `element 1 is "c"`, `element 0: VMArray, first "b"` | the same, SEGV in MVM_interp_run; control exit 0 |
| T3 | **reproduced** (area S) | `T3-self-splice-shifted.nqp`, `... control` | `spliced: elems 4`, SIGSEGV using element 0 (the dead "a"); control (splice from a clone): `elems 4: c d c d` | the same, SEGV in MVM_interp_run near 0x38; control `c d c d` |
| B1 | **reproduced** (also from plain Raku) | `B1-read-buf-past-storage.nqp`, `.raku` | `past1: 8`, `past4: 526343` (bytes after the 8-byte block; Raku: other bytes each run) | `heap-buffer-overflow ... 0 bytes after 8-byte region` READ in `read_buf` (nqp and Raku) |
| B2 | **reproduced** (also from plain Raku) | `B2-buf-offset-wrap.nqp`, `.raku` | `i64 read at 2305843009213693953: 2`, write returns, `after: 1 99 3 4`; the same for i32 at 2**62+1; Raku buf64/buf32 the same | identical (no memory outside the array is touched) |
| B3 | **reproduced** (reachable only after recomposing a live array's type) | `B3-writeint-no-storage-kind.nqp` | first write returns, `elems 8`; second `DIED MVMArray: Unhandled slot type`; third returns (into mimalloc's minimal block), exit 0 | third write: `SEGV on unknown address 0x000000000000` (memcpy to the NULL that realloc(p, 0) left in slots) |
| M1 | **not reachable here** (§3) | `M1-mark-presize-int32.nqp` (guarded, not run) | not run | not run |
| R1 | **reproduced** | `R1-recompose-object-type.nqp` | `recompose to an object type: returned`, then `push an object: DIED MVMArray: push expected int register`, `push_i: returned, elems 1`; the type composed once: `push an object: returned` | identical |
| N1 | **reproduced** | `N1-normalize-ssize-bytes.nqp` | exit 0, right values (the overrun is silent here) | `heap-buffer-overflow ... 0 bytes after 528-byte region` WRITE in `MVM_VMArray_push`; region allocated in `MVM_unicode_normalize_codepoints` |
| N2 | **reproduced** | `N2-strtocodes-leak.nqp`, `... control` | case: RSS +416 MB over 100 rounds; control: +18 MB | case +396 MB, control +280 MB (ASAN's quarantine holds freed blocks; the plain build is the evidence) |
| O1 | **reproduced** (nqp only: Rakudo passes buf8) | `O1-procasync-buf-type.nqp {int64,hash}` | int64: `got 100 elements`, element 99 garbage, exit 0; hash: SIGSEGV in `nqp::elems` on the overwritten hash | int64: `heap-buffer-overflow` READ in `MVM_VMArray_at_pos`, 664 bytes past the adopted 128-byte buffer (ASAN's "located ... after 128-byte region" names the nearest chunk, a freed earlier read buffer); hash: SEGV in `elems` (MVMHash) |
| E1 | **reproduced** (the 32-bit truncation part not reachable here: a 4 GiB array) | `E1-encode-append-offset.nqp` | `u16: 1 97 98 0` (want `1 2 97 98`), `u8s: 2 97 98 0` (want `2 3 97 98`), `u8: 1 2 97 98` | identical |
| E2 | **reproduced** (new at the review) | `E2-encode-append-rounding.nqp` | SIGSEGV (exit 139) before printing, every run (four runs) | `heap-buffer-overflow WRITE of size 17 ... 0 bytes after 16-byte region` in `MVM_string_encode_to_buf_config` (memmove) |
| D1 | **needs a decision → ruled: found-by-reading PR** (real by argument, not reproduced; §3) | `D1-read-array-var-root.nqp` (argument only) | - | - |

Also run: `X1-recompose-wider-kind.nqp`, a defect not on the list, seen on the way, now named under area R
(§4, §5): plain `element 7: 524296` and `bound element 7: 42` on an 8-byte buffer; ASAN
`heap-buffer-overflow` READ in `MVM_VMArray_at_pos`.

**E2** (src/strings/ops.c:1906-1911, the append branch of `MVM_string_encode_to_buf_config`): the array is
grown by `output_size / elem_size` elements, rounded down, and then `output_size` bytes are moved in. When
`output_size % elem_size != 0` the trailing bytes have no element, and when the storage is exactly full they
land past it: a uint16 array with ssize 8 (16 bytes) and elems 0, 17 bytes of utf8 → `set_elems(8)` (no
growth), memmove of 17 bytes. Found by the Task 1 review (its program, verified here and adopted as E2 with
this record's header conventions). E1's wrong offset hides most such cases today (it starts the copy too
early); with E1 alone fixed, any tight ssize would overflow by up to elem_size - 1 bytes, so E1 and E2 are
fixed together.

## 3. The arguments for the cases that are not plain reproductions

**S1 on this toolchain.** The reproducer reaches `memcpy` with overlapping ranges (ASAN:
memcpy-param-overlap). On the plain build the fast-path lines equal the memmove result in every case tried
(offsets 1, 2, 5 on 10 elements; 1, 3, 4500 on 9000; 8-, 4-, 2- and 1-byte kinds; OBJ in the nursery). Why,
as far as checked (`cfix-baseline-raw/ifunc/`): libmoar's `copy_elements` tail-calls `memcpy@plt`
(`memcpy@GLIBC_2.14`); this machine has glibc 2.44 on an AMD Ryzen 9 5900X (avx2, erms, fsrm, no avx512f);
and in a process there, `memcpy` and `memmove` resolve to the same address (a small C program compares the
two IFUNC-resolved pointers: "same: yes"). Which named variant that is was not determined (libc.so.6 has no
local symbols here). That is a property of this glibc version, this CPU and the variant its resolver picks,
not anything memcpy guarantees: glibc's memcpy variants are not promised to be overlap-safe, and campaign
8's libmoar, which linked its own memcpy, printed patterns that were neither the memmove result nor a
forward copy (`va-differential.md` section 5).
**What will and will not flip on a plain build after area S's fix** (the amended Task 2 gate): the
fast-path lines will not change (they already print the memmove result here); the fast path's evidence is
the ASAN run going clean. The lines that go element by element will change: every "str" line and the "obj
gen2" line of S1, and T3's case (from a SIGSEGV to `c d c d`). In campaign 8's differential those are the
STR self-splice lines and the promoted-OBJ ones (`*.gc.selfsplice.promoted`, `gc.splice.promoted`), which
that record counted as defined; under the ruling they become the memmove result.

**G2, not a bug; no PR.** The budget is `2**(64 - elem_addr_size)` elements with elem_addr_size 4/3/2/1 for
8/4/2/1-byte elements, so the largest request the check lets through is 2**63 bytes for every element size:
`ssize * elem_size` cannot wrap (`elem_addr_size` is one bit more conservative than needed). Exactly at the
limit (2**60 eight-byte slots), just under it (2**60 - 1) and far under it (2**45) the request reaches malloc
and fails the same way, with MoarVM's general `MVM_panic_allocation_failed`; changing `>` to `>=` moves one
size from the panic to the exception and leaves every other unsatisfiable size as it is. (Seen on the way: a
size the OS lets mmap reserve, 2**40 slots = 8 TiB under overcommit, is then written by zero_slots page by
page; that first "far" run was killed by its 2G MemoryMax, exit 137, and was changed to 2**45 so that no case
touches memory. Its output files were not kept.)

**M1, not reachable here.** `VMArray_gc_mark` passes `elems` (MVMuint64) as `MVM_gc_worklist_presize_for`'s
MVMint32 count (worklist.c:24); the worklist's `items` and `alloc` are MVMuint32 (worklist.h:21-25), and the
following adds are the unchecked `_nocheck` macros. The presize is short once `items + elems` reaches 2**32
(for `elems` in [2**31, 2**32) the int32 is negative and the unsigned sum happens to bring it back). The bug
triggers with an OBJ or STR array of about 2**32 elements, i.e. about 32 GiB of slots: the worklist is
presized short and the adds then write past it. (A correct VM would need about 64 GiB to finish such a
collection: the slots plus a worklist of the same size.) This machine has 32 GB and no swap. Found by
reading, not reproduced. Note for the fix: chunked presizing alone does not help, because `items` itself is
32-bit and wraps at 2**32 entries; Task 4 first evaluates whether widening the worklist's counters and the
presize parameter is small and contained (85 files mention `MVMGCWorklist`, 11 call sites of
`presize_for`, outside the Zig tree).

**D1, ruled: found-by-reading PR.** What the code shows:
- A collection cannot *move* `result`. Every path to `read_array_var` runs with `tc->allocate_in_gen2 > 0`.
  It has two callers: `MVM_serialization_read_ref` (serialization.c:1939), called from REPR, STable and
  context deserialization, and `deserialize_stable` directly, for a parameterized type's parameters
  (serialization.c:2631). Both run inside `MVM_serialization_deserialize` (gen2 set at 3202, cleared at
  3273) or the demand functions (`demand_object` 2872-2885, `demand_stable` 2929-2942, `demand_code`
  2966-2978); the counter is nested, not a flag (allocation.h:26-35). So `MVM_gc_allocate_object` puts
  `result` in gen2, gen2 objects never move, and the loop's own allocations also go to gen2, so this thread
  never starts a nursery collection from the allocator.
- But a collection can *free* it. read_ref → read_obj_ref → MVM_sc_get_object → demand_object takes the SC's
  reentrant mutex; for an SC this thread does not hold (an element in another SC not yet deserialized)
  `MVM_reentrantmutex_lock` marks the thread blocked around `uv_mutex_lock` (ReentrantMutex.c:145-149).
  Another thread can then run a collection with this thread's work stolen, and a full collection frees the
  unmarked gen2 objects of every thread it processed (orchestrate.c:217-223). `result` is referenced only
  from a C local, so it would be swept, and the next `bind_pos` writes into freed memory.
- `read_hash_str_var` (1827-1849) has the same shape, plus `key`: `key` is reachable (the reader's string
  heap, marked through the SCRef, SCRef.c:104, or the compilation unit's string table, `MVM_cu_string`), so
  it cannot be freed, but it can be a nursery string, and a nursery collection run with this thread's work
  stolen in the same window moves it: the C local would then be stale when `MVMHash_bind_key` uses it. So
  the review's "root `key` too" is right, for the moving reason.
- Not reproduced; it needs two threads, lazy deserialization of a BOOTArray- or BOOTHash-valued slot whose
  elements live in another SC not yet deserialized, and a collection started by another thread in that
  window.

## 4. Areas and the fixes proposed (none written in this task; controller's rulings applied)

The table's grouping with these changes: **T3 is in area S**; **E2 is added to area E**; **G2 is dropped (no
PR)**; **X1 is named under R**; M1 and D1 go ahead as found-by-reading candidates (M1 after Task 4's
evaluation).

| area (branch) | bugs | fix, and the behaviour it defines |
|---|---|---|
| S self-splice (`vmarray-self-splice-memmove`) | S1, T3 | S1: `memcpy` → `memmove` in copy_elements' fast path (VMArray.c:951), **and** make the element-by-element path (VMArray.c:956-965) overlap-safe when source and target are the same array: copy backwards when the target range lies above the source range. Defines: a self-splice gives the memmove result (the source as it stood) whatever the kind or GC generation. T3: skip the offset-0 start adjustment (VMArray.c:1065-1082) when `from == root`, so the shifted-off slots are never re-exposed. In T3's case (start 2, elems 2, ssize 8) the ordinary path then moves nothing in set_size_internal (n + start = 6 ≤ ssize, so it only sets elems = 4), the tail memmove (VMArray.c:1109-1115) copies `c d` to positions 2-3, and the copy of the array onto itself leaves `c d c d`. |
| G growth (`vmarray-size-overflow`) | G1 | In the `ssize >= 8192` branch of set_size_internal, treat a rounded size that wrapped (`ssize < n`) as over the limit and throw "Unable to allocate an array of %"PRIu64" elements" before any realloc, printing `n` (the existing message prints `ssize`, which would read "... of 0 elements"). Defines: the same catchable exception as every other too-large size. |
| P splice sources (`vmarray-splice-guards`) | P1, P2, P3 | All three checks go in asplice, before anything is changed (before the offset-0 adjustment and the resize, VMArray.c:1058-1116), and only when the source has elements to copy (`elems1 > 0`), so deletion through an empty source of any kind or REPR keeps working (Buf.rakumod:1345-1353 splices an empty `nqp::list_i` into any Buf; Str.rakumod:22 and NFA.nqp:1048 an empty `nqp::list`). P1: throw if `from` is not a VMArray. P2: throw if either kind has no storage (elem_size 0) and the kinds differ (same kind: copies nothing today, keep), instead of reaching `abort()`. P3: throw only in the unsafe or meaningless directions: reference ↔ numeric (OBJ or STR on one side, an int/uint/num kind on the other), OBJ → STR, and int/uint ↔ num. Unchanged: int ↔ uint of any width (numeric conversion, works today) and STR → OBJ, which is memory-safe today: the register holds an `MVMString *`, and `struct MVMString` begins with `MVMObject common` (MVMString.h:72-75), so the OBJ array receives a real object of REPR MVMString (the control prints `element 1: MVMString` and survives a collection). Defines: an exception for a splice that would crash or reinterpret, with the array unchanged. |
| T stale slots (`vmarray-stale-slots`) | T1, T2 | Check the register kind before touching the array: in pop, decrement `elems` only after the kind check (VMArray.c:658); in unshift, move `start` (757) only after it (and ideally before making front room). Defines: a rejected pop or unshift leaves the array unchanged, as a rejected shift already does. |
| B buffers (`vmarray-buf-bounds`) | B1, B2, B3 | B1: compare against `elems * elem_size`, not `(start + elems) * elem_size` (VMArray.c:1026). B2: check the offset in elements before multiplying (read: `offset > elems` or too few remaining bytes → the existing "read_buf out of bounds"; write: an offset whose byte position wraps → "MVMArray: Index out of bounds", as for a negative offset). B3: refuse kinds without storage in write_buf with the existing "write_buf requires an integer type" check (`elem_size == 0`). read_buf needs no such check: with elem_size 0 its bounds check (VMArray.c:1026, `0 < count`) already throws for every count > 0. Defines: the existing exceptions for out-of-range or unsupported accesses. |
| M mark (`vmarray-mark-presize`) | M1 | Found by reading only. Task 4 first evaluates whether widening `MVMGCWorklist`'s `items`/`alloc` and `presize_for`'s parameter to 64 bits is small and contained; chunked presizing alone does not help (`items` is 32-bit). If it is not contained, the controller decides whether to offer anything. |
| R recompose (`vmarray-recompose`) | R1, X1 | Option (b), ruled: refuse a second compose that would change the element kind. Precisely: compose computes the new `(slot_type, elem_size)` from the element type, with the object-type case (`BP_NONE`) giving OBJ / `sizeof(MVMObject *)` (the default arm R1 lacks); if `repr_data->elem_type != NULL` (an element type was composed before) and the new pair differs from the current one, throw (P6opaque's wording, "Type %s is already composed", P6opaque.c:735-737, or a VMArray-specific one); otherwise store the type and the kind. A recompose to the same kind stays allowed (also with a different object element type: the kind stays OBJ). Why `elem_type != NULL` is the right test, from the C: `type_object_for` sets `elem_type = NULL` with kind OBJ (VMArray.c:33-35); compose sets `elem_type` only when the `array` info has a non-null `type` (1325-1331), for object element types as well as native ones; `deserialize_repr_data` restores it from the stream (1350-1351). So `elem_type != NULL` means exactly "composed with an element type", for an object-element array too. A type never composed with an element type (elem_type NULL, kind OBJ, e.g. BOOTArray) may still be composed once with any type, as today: OBJ → a native kind never widens past 8 bytes, so arrays alive at that point are not overrun (their pointers would be read as numbers). Defines: an exception for a recompose that would change the kind of arrays that may be alive; closes R1, X1, and the only routes to P2 and B3. Rakudo composes each type once (REPRComposeProtocol.nqp, `$!composed_repr`); nqp code that recomposes a VMArray type to another kind would now die. |
| N normalizer (`normalize-array-result`) | N1, N2 | N1: `ssize = result_alloc` (elements, as the sibling site normalize.c:203 does) instead of `result_pos * sizeof(MVMuint32)` (normalize.c:90). N2: free `out`'s previous slots before adopting the result, as MVM_unicode_normalize_codepoints does (normalize.c:82-84). Defines: correct capacity, no leak. |
| O process output (`procops-buf-type`) | O1 | Read from the code: `si->callbacks` is the caller's config hash itself (procops.c:1323), and async_read looks `buf_type` up in it at every read (681-683), so a check made only at spawn could be bypassed by rebinding `buf_type` afterwards, and a missing key yields a null type at read time. The right fix: at spawn, when any `*_bytes` callback is configured (the keys tested at 935-967), require `buf_type` to be present and a VMArray type of uint8/int8 (as asyncsocket.c:192-196 and Decoder.c:320-324 check), throw otherwise, and capture the checked type in a new SpawnInfo field (marked in spawn_gc_mark, 1214-1218) that async_read uses instead of the hash. That gives the caller a synchronous error and cannot be bypassed. The alternative, checking again in async_read, would detect it only on the event-loop thread, where the error has to go through the callback's error argument (the third element, as the read-error branch at 728-737 does). |
| E encode append (`encode-append-offset`) | E1, E2 | In the append branch (src/strings/ops.c:1906-1911): grow by the rounded-up element count, `(output_size + elem_size - 1) / elem_size` (E2), with `prev_elems` an MVMuint64 (E1's truncation); then read `start` **after** `MVM_repr_pos_set_elems`, because set_size_internal can compact the array (VMArray.c:414-421 moves the elements down and sets start = 0), and copy to `slots + (start + prev_elems) * elem_size` (E1). The spare bytes of the last element stay zero (set_size_internal zeroes new slots). Defines: encoding appends after the existing elements for every element size and start, without overrunning. The alternative for E2: refuse an output whose byte count is not a multiple of the element size. |
| D deserialization (`serialization-root-array-var`) | D1 | Ruled: a found-by-reading PR. `MVMROOT(tc, result)` around the element loop of read_array_var, and `MVMROOT2(tc, result, key)` (key rooted across read_ref) in read_hash_str_var. The PR notes both callers of read_array_var (read_ref, serialization.c:1939, and deserialize_stable, 2631) and that it was not reproduced. |

Hunk adjacency in VMArray.c: S (copy_elements 951 and the element loop 956-965; asplice 1065), P (asplice,
before line 1058), T (pop 651-658; unshift 757), B (write_buf 995-1011; read_buf 1026), G (set_size_internal
446-462), R (spec_to_repr_data / compose 1224-1333). With P's checks all in asplice before
`enter_single_user` and S's in copy_elements and on line 1065, the two branches' hunks are separate, a few
lines apart in asplice.

## 5. Seen on the way (reported, not on the list)

- **E2**, added to the list at the review (§2): the encode append's rounding-down overrun.
- **S1's generation dependence**: the same self-splice gives the memmove result on a nursery OBJ array and the
  forward copy once it is in gen2 (`S1-self-splice-overlap.nqp`, "obj nursery"/"obj gen2"); fixed by area S's
  overlap-safe element path.
- **X1, recompose to a wider kind with a live array** (`X1-recompose-wider-kind.nqp`): an int8 array's 8-byte
  buffer read and written as 8 int64 slots: heap-buffer-overflow (ASAN). Closed by area R's ruling.
- **O1's live config**: `buf_type` is re-read from the caller's hash at each read, and a missing key is not
  handled (§4, O row).
- **D1's `key`**: in read_hash_str_var it can be a nursery string that moves (§3).
- A rejected `push` or `bindpos` has already grown the array (the new slot zeroed: wrong `elems`, no memory
  hazard) (`va-differential.md` section 4); not on the list, not proposed for these branches.
- `write_buf` grows to `offset + count` elements where `count` is bytes (over-allocation for wide kinds;
  `va-differential.md` section 4); not on the list.
- set_size_internal for a kind without storage reallocs to 0 bytes, stores the pointer and then dies in
  zero_slots before updating ssize, leaving a stale ssize over a freed (glibc/ASAN: NULL) buffer; B3's fix in
  write_buf is what makes that state unreachable for writes (every other op throws on the kind).
- `MVM_realloc(p, 0)` returns NULL under glibc and ASAN (and frees p) and a minimal block under mimalloc:
  several crash shapes above differ between the two builds for that reason only.
- N2's reach, completed: besides `nqp::create(...)`, some Rakudo callers pass a fresh `my int32 @codes`
  (src/core.c/RakuAST/Fixups.rakumod:602, :1035, :1166) and core.e/Fixups.rakumod:306 an
  `nqp::create(array[uint32])`: all storage-less, so the leak still needs nqp ops.

## 6. Baseline suites (cfix-base)

`cfix-maketest-driver.sh cfix-baseline-raw/suites cfix-base` (`summary.tsv`; per-file verdict lists
`nqp-cfix-base.list`, `rakudo-cfix-base.list`; full outputs `*.out`; probes `*.probe`, both mapping
`/tmp/claude-1000/cfix-base/lib/libmoar.so`):

| project | finished | load before | exit | Files / Tests | Result | per-file verdicts |
|---|---|---:|---:|---|---|---|
| nqp (305ff2f77) | 2026-11-19 16:33:54 | 0.87 | 0 | 150 / 13746 | PASS | 147 ok, 3 skipped (t/hll/02-modules.t, 03-exports.t, 04-import.t: "design changes, need re-work") |
| rakudo (c6d6fc3c6b) | 2026-11-19 16:36:19 | 0.94 | 0 | 599 / 11162 | PASS | 599 ok (TODO passed: t/09-moar/Line_Break__LineBreak.t 1-2, t/12-rakuast/xx-fixed-in-rakuast.rakutest 76) |

Unlike every run of campaigns 4-8 (`va-suites.md` section 2), `t/04-nativecall/02-simple-args.t` passes
here: those runs used the checkout's rakudo (zig-build-spec) built against tune-zig-prefix, this one
upstream rakudo c6d6fc3c6b built against upstream MoarVM. Not investigated further (outside this task).

The later tasks compare a fix branch's lists with these two, line for line.
