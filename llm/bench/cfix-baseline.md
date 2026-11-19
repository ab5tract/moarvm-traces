# cfix baseline: unmodified origin/main builds, a reproducer for every bug, and the classification (Task 1)

```
Plan:      traces/llm/plans/2026-11-19-vmarray-c-fixes.md, Task 1 (the bug table: section "The bugs")
MoarVM:    origin/main f112c3998, checked out in P as local branch cfix-baseline, built from `git archive`
           copies (P itself is not built in): /tmp/claude-1000/cfix-base (defaults: gcc -O3, mimalloc) and
           /tmp/claude-1000/cfix-asan (--asan --no-mimalloc); moar --version "2026.11" (VERSION file, no .git)
nqp:       305ff2f77 (= nqp origin/main), rakudo c6d6fc3c6b (= rakudo origin/main), both `git archive`d from
           the local checkouts (read only) into /tmp/claude-1000/cfix-ws/{nqp,rakudo}, built and installed
           into cfix-base. Checkouts: nqp at 41e7210ba, rakudo at 042608fb82, `git status --short` empty
           before and after
Raw:       cfix-baseline-raw/build/ (scripts, configure logs, gzipped make logs, info), cfix-baseline-raw/repro/
           (every reproducer's output: <file>[.<case>].{base,asan}.txt), cfix-baseline-raw/suites/ (make test)
Programs:  cfix-repro/*.nqp, *.raku (header of each: what it does, what a correct VM prints, what the bug
           does), cfix-repro/run.sh (one program, both builds), cfix-repro/run-all.sh (all of them),
           cfix-maketest-driver.sh (the suites, any prefix)
```

## 1. What runs under what

| run | runner | libmoar it maps (probe of /proc/self/maps, every run) |
|---|---|---|
| plain reproducer | `/tmp/claude-1000/cfix-base/bin/nqp-m` or `rakudo-m` with `LD_LIBRARY_PATH=/tmp/claude-1000/cfix-base/lib` | `/tmp/claude-1000/cfix-base/lib/libmoar.so` |
| ASAN reproducer | the same runners, `LD_LIBRARY_PATH=/tmp/claude-1000/cfix-asan/lib LD_PRELOAD=/usr/lib/libasan.so.8 ASAN_OPTIONS=detect_leaks=0:abort_on_error=0:symbolize=1` (LD_LIBRARY_PATH wins over the runners' RUNPATH) | `/tmp/claude-1000/cfix-asan/lib/libmoar.so` |
| nqp `make test` | `/tmp/claude-1000/cfix-ws/nqp`, `LD_LIBRARY_PATH=/tmp/claude-1000/cfix-base/lib` | `/tmp/claude-1000/cfix-base/lib/libmoar.so` |
| rakudo `make test` | `/tmp/claude-1000/cfix-ws/rakudo`, the same | `/tmp/claude-1000/cfix-base/lib/libmoar.so` |

The first line of every output file in `cfix-baseline-raw/repro/` is that run's probe. A fix branch's
libmoar is used the same way: `run.sh -p cfix-<area> PROGRAM`, `run-all.sh -p cfix-<area>`,
`cfix-maketest-driver.sh OUTDIR cfix-<area>` (same nqp and rakudo bytecode, only the libmoar changes).

Every reproducer run: `ulimit -c 0`, `timeout` (60-120 s), `systemd-run --user --scope -q -p MemoryMax=4G
-p MemorySwapMax=0` (2G for G1, G2, N2). "timeout: the monitored command dumped core" in an output is
timeout's wording for a signal death; no core was stored (`coredumpctl`: COREFILE none for all of them).

## 2. Classification

19 bugs: **16 reproduced, 1 not reachable here (M1), 1 not a bug (G2), 1 needs a decision (D1).**
"plain" is cfix-base, "ASAN" cfix-asan; file names are under `cfix-repro/` and `cfix-baseline-raw/repro/`.

| id | verdict | program | plain build | ASAN build |
|---|---|---|---|---|
| S1 | **reproduced** (UB shown by ASAN; the wrong value is not visible with this glibc) | `S1-self-splice-overlap.nqp` | exit 0; every fast-path kind prints the memmove result (glibc's x86-64 memcpy is its memmove), small and 9000-element cases; the STR lines print the element-wise forward copy (`str 1,0: 1 1 1 1 1 1 1 1 1 1 1 4 7 ...`) | `memcpy-param-overlap` in `copy_elements` at the first fast-path case (i64, offset 1: two 80-byte ranges 8 bytes apart) |
| G1 | **reproduced** | `G1-size-wrap.nqp` | `setelems(2**64 - 4096): returned, elems -4096`, then SIGSEGV (exit 139) reading element 10**9 | `negative-size-param: (size=-65536)` in memset (set_elems → set_size_internal → zero_slots, inlined), on address 0x10000 (realloc(p, 0) returned NULL) |
| G2 | **not a bug** (see §3) | `G2-limit-boundary.nqp {over,limit,under,far}` | over (2**60+1): `DIED Unable to allocate an array of 1152921504606846977 elements`; limit (2**60), under (2**60-1) and far (2**45): `MoarVM panic: Memory allocation failed; could not allocate N bytes` (exit 1) | over: the same exception; the others: `allocation-size-too-big` in malloc (ASAN's own limit) |
| P1 | **reproduced** | `P1-splice-from-non-vmarray.nqp` | SIGSEGV (exit 139) | `SEGV on unknown address 0x000000000008` in `copy_elements` (reading `s_repr_data->slot_type`) |
| P2 | **reproduced** (reachable only after recomposing a live array's type) | `P2-splice-no-storage-kind.nqp {target,source}` | SIGABRT (exit 134), no message, both cases | the same (abort is not an ASAN error) |
| P3 | **reproduced** | `P3-splice-cross-kind.nqp {int-into-obj,obj-into-int,num-from-int}` | int-into-obj: splice returns, then SIGSEGV in the collection; obj-into-int: `element 1 = 3239214825368` (an address; a different one every run); num-from-int: `element 0 = 1` (the bits of 1.0) | int-into-obj: `SEGV on unknown address 0x0008a827a829` in `VMArray_gc_mark` (process_worklist, MVM_gc_collect); the other two as plain |
| T1 | **reproduced** | `T1-rejected-pop.nqp`, `... control` | `pop_i: DIED MVMArray: pop expected object register`, `elems now: 1`, grown back to 2, SIGSEGV using element 1; control (setelems 1 instead): `element 1: null`, exit 0 | the same up to the SEGV (in MVM_interp_run, near address 0x38); control exit 0 |
| T2 | **reproduced** | `T2-rejected-unshift.nqp`, `... control` | `unshift_i: DIED ...`, then `elems 2, element 1 is "b"` (should be "c"), SIGSEGV using element 0 (the dead "a"); control: `element 1 is "c"`, `element 0: VMArray, first "b"` | the same, SEGV in MVM_interp_run; control exit 0 |
| T3 | **reproduced** | `T3-self-splice-shifted.nqp`, `... control` | `spliced: elems 4`, SIGSEGV using element 0 (the dead "a"); control (splice from a clone): `elems 4: c d c d` | the same, SEGV in MVM_interp_run near 0x38; control `c d c d` |
| B1 | **reproduced** (also from plain Raku) | `B1-read-buf-past-storage.nqp`, `.raku` | `past1: 8`, `past4: 526343` (bytes after the 8-byte block; Raku: other bytes each run, e.g. `past1: 232`, `past4: 1676150791`) | `heap-buffer-overflow ... 0 bytes after 8-byte region` READ in `read_buf` (nqp and Raku) |
| B2 | **reproduced** (also from plain Raku) | `B2-buf-offset-wrap.nqp`, `.raku` | `i64 read at 2305843009213693953: 2`, write returns, `after: 1 99 3 4`; the same for i32 at 2**62+1; Raku buf64/buf32 the same | identical (no memory outside the array is touched) |
| B3 | **reproduced** (reachable only after recomposing a live array's type) | `B3-writeint-no-storage-kind.nqp` | first write returns, `elems 8`; second `DIED MVMArray: Unhandled slot type`; third returns (into mimalloc's minimal block), exit 0 | third write: `SEGV on unknown address 0x000000000000` (memcpy to the NULL that realloc(p, 0) left in slots) |
| M1 | **not reachable here** (see §3) | `M1-mark-presize-int32.nqp` (guarded, not run) | not run | not run |
| R1 | **reproduced** (fix needs a choice, §4) | `R1-recompose-object-type.nqp` | `push an object: DIED MVMArray: push expected int register`, `push_i: returned, elems 1`; the type composed once: `push an object: returned` | identical |
| N1 | **reproduced** | `N1-normalize-ssize-bytes.nqp` | exit 0, prints the right values (the overrun is silent here) | `heap-buffer-overflow ... 0 bytes after 528-byte region` WRITE in `MVM_VMArray_push`; region allocated in `MVM_unicode_normalize_codepoints` |
| N2 | **reproduced** | `N2-strtocodes-leak.nqp`, `... control` | case: RSS +416 MB over 100 rounds; control: +18 MB | case +396 MB, control +280 MB (ASAN's quarantine holds freed blocks; the plain build is the evidence) |
| O1 | **reproduced** (nqp only: Rakudo passes buf8) | `O1-procasync-buf-type.nqp {int64,hash}` | int64: `got 100 elements`, element 99 = garbage (`5934412989304`), exit 0; hash: SIGSEGV in `nqp::elems` on the overwritten hash | int64: `heap-buffer-overflow` READ in `MVM_VMArray_at_pos` (the 128-byte buffer from `on_alloc`); hash: SEGV in `elems` (MVMHash) |
| E1 | **reproduced** (the 32-bit truncation part not reachable here: a 4 GiB array) | `E1-encode-append-offset.nqp` | `u16: 1 97 98 0` (want `1 2 97 98`), `u8s: 2 97 98 0` (want `2 3 97 98`), `u8: 1 2 97 98` | identical |
| D1 | **needs a decision** (real by argument, not reproduced; §3) | `D1-read-array-var-root.nqp` (argument only) | - | - |

Also run: `X1-recompose-wider-kind.nqp`, a defect not on the list, seen on the way (§5): plain `element 7:
524296` and `bound element 7: 42` on an 8-byte buffer; ASAN `heap-buffer-overflow` READ in
`MVM_VMArray_at_pos`.

## 3. The arguments for the four that are not plain reproductions

**S1 on this toolchain.** The reproducer reaches `memcpy` with overlapping ranges (ASAN: memcpy-param-overlap,
first case). The plain build's output equals the memmove result in every case tried (offsets 1, 2, 5 on 10
elements; 1, 3, 4500 on 9000; 8-, 4-, 2- and 1-byte kinds): glibc on x86-64 implements memcpy with its
memmove code. Campaign 8's wrong lines ("neither" patterns, `va-differential.md` section 5) came from a
libmoar that links its own memcpy. It is undefined behaviour either way; what a given libc prints is not
something to rely on.

**G2, not a bug.** The budget is `2**(64 - elem_addr_size)` elements with elem_addr_size 4/3/2/1 for
8/4/2/1-byte elements, so the largest request the check lets through is 2**63 bytes for every element size:
`ssize * elem_size` cannot wrap (`elem_addr_size` is one bit more conservative than needed). Exactly at the
limit (2**60 eight-byte slots), just under it (2**60 - 1) and far under it (2**45) the request reaches malloc
and fails the same way, with MoarVM's general `MVM_panic_allocation_failed`; changing `>` to `>=` moves one
size from the panic to the exception and leaves every other unsatisfiable size as it is. So the panic is
MoarVM's out-of-memory behaviour, not a boundary defect. (Seen on the way: a size the OS lets mmap reserve,
2**40 slots = 8 TiB under overcommit, is then written by zero_slots page by page; that first "far" run was
killed by its 2G MemoryMax, exit 137, and was changed to 2**45 so that no case touches memory. Its output
files were not kept. Same OOM behaviour as any other huge allocation; not a VMArray defect.)

**M1, not reachable here.** `VMArray_gc_mark` passes `elems` (MVMuint64) as `MVM_gc_worklist_presize_for`'s
MVMint32 count (worklist.c:24); the worklist's `items` and `alloc` are MVMuint32 (worklist.h:21-25), and the
following adds are the unchecked `_nocheck` macros. The presize is short once `items + elems` reaches 2**32
(and for `elems` in [2**31, 2**32) the int32 is negative, which the unsigned sum happens to bring back). To
overflow, an OBJ or STR array needs about 2**32 elements: 32 GiB of slots, and the collection then needs a
worklist of the same size: about 64 GiB in all, on a machine with 32 GB and no swap. A machine with well
over 64 GiB of RAM would show it with the guarded program. Found by reading, not reproduced.

**D1, needs a decision.** What the code shows:
- A collection cannot *move* `result`. Every path to `read_array_var` runs with `tc->allocate_in_gen2 > 0`:
  it is reached only through `MVM_serialization_read_ref`, called from REPR/STable/context deserialization
  inside `MVM_serialization_deserialize` (gen2 set at serialization.c:3202, cleared at 3273) or the demand
  functions (`demand_object` 2872-2885, `demand_stable` 2929-2942, `demand_code` 2966-2978); the
  counter is nested, not a flag (allocation.h:26-35). So `MVM_gc_allocate_object` puts `result` in gen2,
  gen2 objects never move, and read_ref's own allocations also go to gen2, so this thread never starts a
  nursery collection from the allocator during the loop.
- But a collection can *free* it. read_ref → read_obj_ref → MVM_sc_get_object → demand_object takes the SC's
  reentrant mutex; for an SC this thread does not hold (an element in another SC that is not yet
  deserialized) `MVM_reentrantmutex_lock` marks the thread blocked around `uv_mutex_lock`
  (ReentrantMutex.c:145-149). Another thread can then run a collection with this thread's work stolen, and
  a full collection frees the unmarked gen2 objects of every thread it processed (orchestrate.c:217-223).
  `result` is referenced only from a C local, so it would be swept, and the next `bind_pos` writes into
  freed memory. `read_hash_str_var` (1827-1849) has the same shape.
- It needs: two threads, lazy deserialization of a BOOTArray-valued slot whose elements live in another SC
  not yet deserialized, and a full collection started by another thread in that window. Not reproduced;
  no deterministic program exists here.
The decision: offer `MVMROOT(tc, result)` (and the same in read_hash_str_var) as a "found by reading, not
reproduced" PR, or drop it. The code around it already roots objects under gen2 allocation
(`install_object_repos`, `demand_object`'s `MVMROOT(tc, sc)` around the lock), so the fix would match local
practice.

## 4. Areas and the fixes proposed (none written in this task)

The table's grouping, with one change: **T3 moves to area S.** T3 and S1 happen only when a splice's source
is the array itself, are driven by the same kind of program, and are fixed in the same function pair
(`asplice` for T3, `copy_elements` for S1, on different lines); T1 and T2 are both "a rejected register kind
has already changed the array", one defect shape with one fix shape. G2 drops out (not a bug); M1 and D1
are found-by-reading candidates that need the controller's yes.

| area (branch) | bugs | fix, and the behaviour it defines |
|---|---|---|
| S self-splice (`vmarray-self-splice-memmove`) | S1, T3 | S1: `memcpy` → `memmove` in copy_elements' fast path (VMArray.c:951): a self-splice copies the source as it stood (memmove semantics, the ruling for the Zig port). The element-by-element path (STR, promoted OBJ) stays a forward copy, which is defined but gives a different result (`str 1,0: 1 1 1 1 ...`): **a choice** for the maintainers whether to make that path overlap-aware too (copy backwards when the target is above the source in the same array); the minimal fix leaves it. T3: skip the offset-0 start adjustment (VMArray.c:1065-1082) when `from == root`, so the shifted-off slots are never re-exposed; the splice then takes the ordinary path (set_size_internal moves the elements down and zeroes the rest) and prints `c d c d`. |
| G growth (`vmarray-size-overflow`) | G1 | In the `ssize >= 8192` branch of set_size_internal, treat a rounded size that wrapped (`ssize < n`) as over the limit and throw the existing "Unable to allocate an array of %"PRIu64" elements" (VMArray.c:459-461), before any realloc. Defines: the same catchable exception as every other too-large size. |
| P splice sources (`vmarray-splice-guards`) | P1, P2, P3 | P1: in asplice, before changing the array, throw if `from` is not a VMArray and has elements to copy (an empty non-VMArray source keeps working: `<kind>.splice.fromhash` deletes). P2: refuse kinds without storage instead of `abort()`: throw "MVMArray: Unhandled slot type" (zero_slots' message for these kinds) from slot_type_to_kind's default (it needs `tc`), or check in asplice first. P3: when the source and target register kinds differ, throw unless both are integer kinds (int↔uint works today and Rakudo's Buf code may rely on it): so OBJ↔STR, reference↔native and int/uint↔num throw. **A choice:** the code's own comment says "should coerce"; converting int↔num instead of throwing is the alternative for the numeric pair. |
| T stale slots (`vmarray-stale-slots`) | T1, T2 | Check the register kind before touching the array: in pop, decrement `elems` only after the kind check (VMArray.c:658); in unshift, move `start` (757) only after it (and ideally before making front room). Defines: a rejected pop or unshift leaves the array unchanged, as a rejected shift already does. |
| B buffers (`vmarray-buf-bounds`) | B1, B2, B3 | B1: compare against `elems * elem_size`, not `(start + elems) * elem_size` (VMArray.c:1026). B2: check the offset in elements before multiplying (read: `offset > elems` or the remaining bytes too few → the existing "read_buf out of bounds"; write: an offset whose byte position wraps → "MVMArray: Index out of bounds", as for a negative offset). B3: refuse kinds without storage in write_buf (and read_buf) with the existing "write_buf requires an integer type" check (`elem_size == 0`). All three define: the existing exceptions for out-of-range or unsupported accesses. |
| M mark (`vmarray-mark-presize`) | M1 | Found by reading only. Presize and add in chunks that fit the MVMint32 parameter (or pass a checked count); the worklist itself stays 32-bit, a structural limit beyond this fix. Offer as found-by-reading, or drop: controller's call. |
| R recompose (`vmarray-recompose`) | R1 | **A choice.** (a) Minimal: give spec_to_repr_data a default arm that sets OBJ and `sizeof(MVMObject *)`, so a recompose to an object element type gives an object array. But a recompose changes the kind of arrays already alive (§5, X1), and with (a) a live int array recomposed to an object type would have its integers marked as pointers: (a) makes that path more dangerous. (b) Refuse a second compose that changes the element kind ("Type %s is already composed", as P6opaque.c:735-737 does for any second compose); this also closes the only route to P2 and B3 and to X1. Rakudo composes each type once (REPRComposeProtocol.nqp, `$!composed_repr`), so (b) should not affect it; nqp code that recomposes VMArray types would break. |
| N normalizer (`normalize-array-result`) | N1, N2 | N1: `ssize = result_alloc` (elements, as the sibling site normalize.c:203 does) instead of `result_pos * sizeof(MVMuint32)` (normalize.c:90). N2: free `out`'s previous slots before adopting the result, as MVM_unicode_normalize_codepoints does (normalize.c:82-84). Defines: correct capacity, no leak. |
| O process output (`procops-buf-type`) | O1 | Check `buf_type` as the socket and decoder sites do (asyncsocket.c:192-196, Decoder.c:320-324): a VMArray of 8-bit integers, else throw (at spawnprocasync, before the process starts, is the cleanest place; in async_read the error would have to go to the callback). Defines: an exception for a buffer type that cannot hold bytes. |
| E encode append (`encode-append-offset`) | E1 | Offset the append by `(start + prev_elems) * elem_size` bytes with `prev_elems` an MVMuint64 (src/strings/ops.c:1908-1910). Defines: encoding appends after the existing elements, for every element size and start. |
| D deserialization (`serialization-root-array-var`) | D1 | Decision first (§3). If yes: `MVMROOT(tc, result)` around the element loop of read_array_var (and read_hash_str_var), offered as found by reading, not reproduced. |

Hunk adjacency in VMArray.c: S (copy_elements line 951; asplice 1065-1082), P (copy_elements 943-958 and
slot_type_to_kind 928-929; asplice start), T (pop 651-658; unshift 757), B (write_buf 995-1011; read_buf
1022-1027), G (set_size_internal 446-462), R (spec_to_repr_data or compose 1224-1333). S and P both touch
copy_elements and asplice: S1's line (951) is inside the fast path that P's guard lines (943-947, 957-958)
surround, so the two branches' hunks are a few lines apart; if both P1's check and T3's condition go at the
top of asplice's body they would be adjacent hunks (keepable apart: P1's check before `enter_single_user`,
T3's condition on line 1065).

## 5. Seen on the way (reported, not on the list)

- **X1, recompose to a wider kind with a live array** (`X1-recompose-wider-kind.nqp`): an int8 array's 8-byte
  buffer read and written as 8 int64 slots: heap-buffer-overflow (ASAN). Same root as P2/B3's route
  (compose rewrites the kind of live arrays); option (b) of area R closes it.
- A rejected `push` or `bindpos` has already grown the array (the new slot zeroed: wrong `elems`, no memory
  hazard) (`va-differential.md` section 4); not on the list, not proposed for these branches.
- `write_buf` grows to `offset + count` elements where `count` is bytes (over-allocation for wide kinds;
  `va-differential.md` section 4); not on the list.
- set_size_internal for a kind without storage reallocs to 0 bytes, stores the pointer and then dies in
  zero_slots before updating ssize, leaving a stale ssize over a freed (glibc/ASAN: NULL) buffer; B3's fix in
  write_buf is what makes that state unreachable for writes (every other op throws on the kind).
- `MVM_realloc(p, 0)` returns NULL under glibc and ASAN (and frees p) and a minimal block under mimalloc:
  several crash shapes above differ between the two builds for that reason only.

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
