# Zig GC Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every C file under `src/gc/` with a Zig file exporting the same symbols, behaving identically collection by collection, no slower and no larger in memory than the C collector.

**Architecture:** One Zig file per C file under `src/zig/gc/`, each exporting its C symbols with `callconv(.c)` through the hash engine's `@export`/visibility pattern and swapped in through the `[zig]` section of `build/sources.list`; the C headers, the inline fast paths they define, every struct layout and every caller stay as they are. Two build options (`-Dgc-debug`, `-Dnursery-size`) feed the existing C `#define`s, so the stress and oracle builds exist for both collectors, and the Zig side reads those constants at comptime through translate-c. Fidelity is proven by a per-collection log that both collectors emit from the same debug-only instrumentation.

**Tech Stack:** Zig 0.16 (ports, unit tests, build), C (debug-only instrumentation, header guards), Raku (workloads), sh and Python (runners; `tools/bench/timev.py`).

**Spec:** `traces/llm/specs/2026-11-04-zig-gc-port-design.md` (approved 2026-11-04). The signature inventory the plan quotes from is `.superpowers/gc-inventory.md` in the MoarVM checkout (scratch, not committed); implementers read the C source, not the inventory.

## Global Constraints

- MoarVM work on branch `zig-gc-port` from `zig-hash-engine` 2baef20b7, in the main checkout. **No git worktrees** (the user's standing instruction). Records in the `traces/llm` submodule under `bench/gc-*`; commit there first, then the pointer.
- Faithful port: no change to any collection policy, size, threshold, flag transition, atomic ordering, or data-structure layout (spec sections 1-2). Every `MVM_load`/`MVM_store`/`MVM_add`/`MVM_incr`/`MVM_decr`/`MVM_cas`/`MVM_trycas`/`MVM_barrier` site maps to a `.seq_cst` Zig builtin with a comment naming the C macro and line it replaces. `MVM_panic`/`MVM_oops`/`MVM_exception_throw_adhoc` calls stay calls into C with the same messages.
- The C collector stays in the tree and `zig build -Dzig-impl=false install` plus `zig build test` pass after every task. Only three kinds of C edit are allowed (spec section 3): `#if MVM_ZIG_IMPL` extern declarations for a formerly inline function (none planned), `#ifndef` guards on `MVM_GC_DEBUG`, `MVM_NURSERY_SIZE`, `MVM_NURSERY_THREAD_START`, and instrumentation under `#if MVM_GC_DEBUG` (Task 1). Nothing else in C changes; a port that needs more reports BLOCKED.
- Selectability is the linear ladder: after Task N the files of Tasks 3..N are Zig and the rest C. Each task adds exactly one `[zig]` line (Task 8 adds four) and one `root.zig` import per Zig file.
- Builds: `rm -f src/gen/config.h src/gen/config.c src/gen/config.o` before any `zig build` without `-Dconfig-h`; default options (`zig build install --prefix <P>`: LTO, ReleaseFast, x86-64-v3, `-Dzig-impl=true`, `-Dgc-debug=0`); always an absolute `--prefix`. Prefixes (names of equal length per pair, ruled after Task 3: the prefix path is baked into libmoar's config strings and a different length shifts the allocation sequence, 56 bytes at seq=2): `/tmp/claude-1000/gc-c-base` (Task 1's commit 139d404ed, the C collector with the Zig hash engine: the base of every A/B) and `/tmp/claude-1000/gc-z-base` (the current ladder head, default options); `/tmp/claude-1000/gc-c-stress` and `/tmp/claude-1000/gc-z-stress` (`-Dgc-debug=1 -Dnursery-size=524288`); `/tmp/claude-1000/gc-c-oracle` and `/tmp/claude-1000/gc-z-oracle` (`-Dgc-debug=1`, default nursery). `oracle.sh` and `ab.sh` refuse base/head prefix paths of unequal length (exit 4). Variants run against the one installed nqp and rakudo of `/tmp/claude-1000/tune-zig-prefix` through `LD_LIBRARY_PATH=<prefix>/lib`.
- Measurement conventions: interleaved rounds with the variant order rotated per round; medians of at least five runs per round; spreads are the min and max of round medians; 1-minute load under 2.0 before every run and recorded; nothing judged from a single run; `tools/bench/timev.py <out>.time <cmd>` for wall and peak RSS; records with the header fields of `bakeoff-scoreboard.md`.
- Machine rules: 32 GB, no swap; `pgrep -af "context-bench|rakudo-image|eval-serve|native-eval"` must print nothing and the load must be under 2.0 before every build, spectest or benchmark round (wait, polling every 5 minutes); one build at a time; never two spectests at once; never `pkill -f`/`pgrep -f` with a pattern that appears in your own command line; any new wrapper gets a dry run under `ulimit -v 400000`; long runs with `run_in_background: true`; (the hundred-million run was struck from the campaign on 2026-11-04).
- Spectest recipe: rakudo checkout, roast pinned at fb1d87214 (verify `git -C t/spec rev-parse --short HEAD` before each run), `.precomp` dirs under `t/spec` removed, `TEST_JOBS=24`, `python3 <MoarVM>/tools/bench/timev.py <out>.time make -o spectest_update spectest`, stats off, no harness shims.
- `zig fmt --check` clean on every Zig file touched; `perl -c`, `sh -n`, `python3 -m py_compile` on touched scripts; test output pristine.
- Commit attribution lines as the session reminder gives them.

## Rulings made while planning

- **The inline header fast paths stay in C** (`allocation.h`: `MVM_gc_allocate`, `_zeroed`, gen2-default set/clear; `roots.h`: temp-root push/pop and the `MVMROOT*` macros; `wb.h`: `MVM_gc_write_barrier*` and `MVM_ASSIGN_REF`; `worklist.h`: `MVM_gc_worklist_add*`/`_get` macros). They touch only `tc` fields and call the exported slow paths, and moving them would cost a call per allocation, push or barrier. The Zig ports call them through translate-c where they need them. No `#if MVM_ZIG_IMPL` header edit is planned.
- **`MVM_gc_global_destruction` is ported as written**, including its CAS on the caller's own `tc` inside the loop over other threads (orchestrate.c:769-807). Faithful means faithful; the plan records it under "C observations for a later campaign" and the port's comment says so.
- **The stress and oracle builds change `MVMThreadContext`'s layout** (`in_spesh` exists only under `MVM_GC_DEBUG`, and Task 1 adds debug-only counters). That is acceptable because both collectors are built with the same flags for every comparison, and the layout probe test (`src/zig/test/layout_probe.c`) checks the translated layout against the C compiler at every level.
- **Zig reads `MVM_GC_DEBUG` and `MVM_NURSERY_SIZE` through translate-c** (`c.MVM_GC_DEBUG`, `c.MVM_NURSERY_SIZE`), which the build defines on the translate step and on the C compile from the two options. No separate Zig option; the two sides cannot disagree.
- **Exports use the hash engine's pattern:** a `comptime { @export(&f, .{ .name = "MVM_...", .visibility = visibility }); }` block per file with `visibility` `.protected` under `-Dlto` (so LTO inlines into C callers) and `.default` otherwise; functions are `fn ... callconv(.c)` over translated C types (`[*c]c.MVMThreadContext` etc.), never `export fn`.
- **Atomics:** `src/zig/gc/atomic.zig` provides `load`, `store`, `add`, `incr`, `decr`, `cas` (returns the previous value) and `fence`, all `.seq_cst`, over `*usize`, `*u32` and pointer slots; the existing `moar.trycas` stays for the `MVM_trycas` sites. The C helpers are unlinkable from Zig (translate-c leaves them undefined), so every ported atomic site uses this file.
- **The per-collection log is a C function in `debug.c`** (`MVM_gc_debug_log_collection`, Task 1) under `#if MVM_GC_DEBUG`, called by the coordinator at the end of `finish_gc` for every thread's run and by non-coordinators for theirs; the port of `debug.c` (Task 8) carries it. The same source line emits the same bytes from both collectors until Task 8, and Task 8's oracle run proves the Zig writer matches.
- **Tier 1 and tier 2 of the oracle are two runs of one script** (`tools/bench/gc/oracle.sh`): tier 2 sets `MVM_GC_DEBUG_RSS=104857600` (100 MiB, so promoted bytes of 20 MiB and up trigger full runs deterministically) in the environment of both collectors; tier 1 leaves it unset and drops the `full` and `gen2_freed` columns before diffing.
- **Workload sizes for the per-task oracle are 10 000 and 100 000** (seconds each); the 1 000 000 size and the real program run at acceptance (Task 10) and at the orchestration task (Task 9).

## Review Focus

- `gc_status` is read without an atomic at the allocation fast path (allocation.c:20) and the interrupt check must see the coordinator's CAS: pinned by Task 4's threaded test (allocate on one thread while another marks it blocked and unblocked; the allocation must observe INTERRUPT exactly as the C path does).
- A nursery request above `MVM_NURSERY_SIZE` panics with the C message, and a request that does not fit the remaining space triggers a collection and retries: Task 4's size-boundary test.
- Temp-root growth: the slow push doubles `alloc_temproots` from 16 and reallocates; a push at every boundary keeps earlier roots intact: Task 6's growth test.
- `MVMGCWorklist` is an ABI shared with every REPR's `gc_mark` macro: Task 3's comptime layout assertion plus a test that pushes through the C macro and pops through Zig.
- Work passed between threads through in-trays uses CAS loops on `gc_in_tray`; a lost item is a missed mark and a dangling pointer: Task 7's in-tray test with two threads pushing concurrently and the total counted.

---

### Task 1: Build options, header guards, debug instrumentation, per-collection log, RSS pin

**Files:**
- Modify: `build/zig/options.zig` (two options), `build/zig/moar.zig` (cflags), `build/zig/zigimpl.zig` (translate defines), `build/config.h.in` and `Configure.pl` only if the Perl path needs the defines passed (it does not: the Perl path keeps the defaults).
- Modify: `src/gc/debug.h:7`, `src/gc/collect.h:3,10` (`#ifndef` guards), `src/core/threadcontext.h` (debug-only counters next to `in_spesh`), `src/core/instance.h` (debug-only `gc_debug_rss_override`), `src/moar.c` (read `MVM_GC_DEBUG_RSS` and `MVM_GC_LOG` under `#if MVM_GC_DEBUG`), `src/gc/orchestrate.c` (`is_full_collection` uses the override; `finish_gc` calls the log), `src/gc/collect.c` (count gen2 freed bytes and STables freed under `#if MVM_GC_DEBUG`), `src/gc/debug.c` (the log writer).
- Test: `build/zig/options.zig` unit test (options parse), `src/zig/moar.zig` layout probe (unchanged, run at `-Dgc-debug=1`).

**Interfaces:**
- Produces: options `gc_debug: u8` (0-3, default 0) and `nursery_size: u32` (default 16777216) on `Options`; C defines `-DMVM_GC_DEBUG=<n> -DMVM_NURSERY_SIZE=<n>` on every C compile and on the translate-c step; `MVM_NURSERY_THREAD_START` keeps its default (guarded, no option).
- Produces (C, under `#if MVM_GC_DEBUG`): `tc->gc_debug_gen2_freed_bytes` (`MVMuint64`), `tc->gc_debug_stables_freed` (`MVMuint32`), `instance->gc_debug_rss_override` (`size_t`, 0 = unset), `instance->gc_debug_log` (`FILE *`, NULL = off); `void MVM_gc_debug_log_collection(MVMThreadContext *tc, MVMThreadContext *for_tc, MVMuint8 full)` writing one line `seq=<n> tid=<id> full=<0|1> coord=<0|1> from=<nursery_fromspace_size> next=<nursery_tospace_size> promoted=<gc_promoted_bytes> since_full=<gc_promoted_bytes_since_last_full> gen2_freed=<n> stables_freed=<n> finalizing=<num_finalizing>` with `\n`, flushed, to `instance->gc_debug_log`.
- Produces: `is_full_collection` returns `percent_growth` computed against `gc_debug_rss_override` when it is non-zero (debug builds only); release builds are byte-identical to before.

- [ ] **Step 1: Write the failing options test** in `build/zig/options.zig`: `test "gc-debug and nursery-size default and parse"` asserting defaults `0` and `16777216` and that `gc_debug` above 3 is rejected with the message `-Dgc-debug must be 0..3`.
- [ ] **Step 2: Run `zig build unit-test`**; expected: FAIL (fields missing).
- [ ] **Step 3: Add the options** (`b.option(u8, "gc-debug", ...)`, `b.option(u32, "nursery-size", ...)`), add `-DMVM_GC_DEBUG=` and `-DMVM_NURSERY_SIZE=` to `moar.cflags` and to `moar.defines` (the translate step), and guard the three `#define`s with `#ifndef`.
- [ ] **Step 4: Add the debug-only fields and the log writer**, the env reads in `src/moar.c` (`MVM_GC_DEBUG_RSS` parsed as bytes, `MVM_GC_LOG` opened for append), the counters in `collect.c` (`MVM_gc_collect_free_gen2_unmarked` adds the size of each freed gen2 object, `MVM_gc_collect_free_stables` counts), the override in `is_full_collection`, and the call at the end of `finish_gc` (coordinator: once per thread in `tc->gc_work`, with that thread's `tc` as `for_tc`; non-coordinator: its own).
- [ ] **Step 5: Build four prefixes** at this commit: `gc-c-base` (defaults), `gc-c-oracle` (`-Dgc-debug=1`), `gc-c-stress` (`-Dgc-debug=1 -Dnursery-size=524288`), and a `-Dzig-impl=false` build into `/tmp/claude-1000/gc-allc-check` (then deleted); `zig build test` and `zig build unit-test` on each. Expected: all green; `objdump -d` of `MVM_gc_enter_from_allocator` in `gc-c-base` identical to the same function in `/tmp/claude-1000/tune-zig-prefix/lib/libmoar.so` (the release path is byte-identical).
- [ ] **Step 6: Smoke the log**: `MVM_GC_LOG=/tmp/claude-1000/gc-smoke.log LD_LIBRARY_PATH=/tmp/claude-1000/gc-c-oracle/lib /tmp/claude-1000/tune-zig-prefix/bin/moar --version` and a `raku -e` loop allocating 10 million short strings; expected: lines in the format above, `seq` strictly increasing by 1, `promoted` non-zero on at least one line.
- [ ] **Step 7: Commit** `git commit -m "GC: -Dgc-debug and -Dnursery-size options; debug-only per-collection log and RSS override"`.

### Task 2: Workloads, oracle script, A/B runner, reference records

**Files:**
- Create: `tools/bench/gc/crc-getter.raku` (the user's program, verbatim from the gist `ab5tract/61e08cfaf0bb3e67b3a3dc009fa3cc7a`), `tools/bench/gc/crc-sequential.raku`, `tools/bench/gc/lib/String/CRC32.rakumod` (vendored from the REA archive `zef info String::CRC32` names, version 0.05, with its license file beside it), `tools/bench/gc/oracle.sh`, `tools/bench/gc/ab.sh`, `tools/bench/gc/README.md`.
- Test: `tools/bench/t/gc-oracle.t` (Perl TAP: `oracle.sh` on the C oracle prefix against itself passes; a log with one altered `promoted` value fails with the differing line printed).
- Record: `gc-oracle-repeatability.md` (the stall record was struck, see Step 5).

**Interfaces:**
- Produces: `crc-sequential.raku --volume=N --runs=5 [--bad-packages]`: the `Package` class, `@packages` and the per-batch `map` of crc32 checks exactly as `crc-getter.raku`, with the supplies, `react` and `start` removed; one `say "RUN $n: {$duration}s"` per batch; exit 0.
- Produces: `oracle.sh --base=<prefix> --head=<prefix> --volume=N [--bad-packages] [--tier=1|2] --out=<dir>`: runs the sequential program under each prefix three times with `MVM_SPESH_DISABLE=1`, `MVM_GC_LOG=<out>/<side>-<i>.log`, `RAKULIB=tools/bench/gc/lib`, and for tier 2 `MVM_GC_DEBUG_RSS=104857600`; checks the three logs of each side are identical (else exit 2 "not repeatable" with the first differing line); diffs base against head (tier 1 after deleting the `full=` and `gen2_freed=` fields); exit 0 on identical, 1 with the first differing line otherwise.
- Produces: `ab.sh --base=<lib> --head=<lib> --rounds=R --runs=K --volume=N [--bad-packages] --out=<dir>`: interleaved, order rotated per round, `timev.py` per run, waits for load under 2.0 with a 30-minute timeout, writes `<out>/<side>-r<round>-<run>.time`, `<out>/load.log`, and `<out>/summary.md` with per-side round medians, min-max of round medians, and the median ratios for wall and RSS.

- [ ] **Step 1: Write the failing TAP test** `tools/bench/t/gc-oracle.t` (two cases above) and run `prove tools/bench/t/gc-oracle.t`; expected: FAIL (script missing).
- [ ] **Step 2: Vendor the program and the module**, write `crc-sequential.raku`, verify `LD_LIBRARY_PATH=/tmp/claude-1000/gc-c-base/lib RAKULIB=tools/bench/gc/lib /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m tools/bench/gc/crc-sequential.raku --volume=10000` prints five RUN lines and that `crc-getter.raku --volume=10000` prints five RUN lines and exits 0.
- [ ] **Step 3: Write `oracle.sh` and `ab.sh`** (`sh -n`, then a dry run of each under `ulimit -v 400000` on `--volume=1000`); run the TAP test; expected: PASS.
- [ ] **Step 4: Repeatability record**: `oracle.sh` with base and head both `gc-c-oracle`, volumes 10 000, 100 000, 1 000 000, both settings, both tiers. Expected: exit 0 everywhere. If tier 1 is not repeatable at some size, find which field moves (threads: the log carries `tid`; the main thread's lines must be identical and other threads' line counts equal) and adjust the reduction or the script's filtering until it is; record what was needed in `gc-oracle-repeatability.md` with the twelve results.
- [x] ~~**Step 5: Reference stall record**~~ STRUCK 2026-11-04 by the user ("let's ignore the 100 million bench after all. it's going to take way too long"): no hundred-million run, no `gc-reference-stall.md`. Spec section 7 is void (erratum recorded in the spec).
- [ ] **Step 6: Commit** MoarVM (`"tools/bench/gc: crc-getter workloads, oracle and A/B runners"`), traces (`"gc: oracle repeatability and reference stall"`), pointer.

### Task 3: `worklist.c` to `src/zig/gc/worklist.zig`

**Files:**
- Create: `src/zig/gc/worklist.zig`, `src/zig/gc/gc_test.zig` (libmoar-linked test root registered in `build.zig` next to `hash-str-test`, binary `gc-test`), `src/zig/gc/test/worklist_test.zig`.
- Modify: `build/sources.list` (`src/zig/gc/worklist.zig: src/gc/worklist.c`), `src/zig/root.zig`, `build.zig:149-152` (the new root).

**Interfaces:**
- Produces (exported, signatures from `worklist.h`): `MVM_gc_worklist_create(tc, include_gen2: MVMuint8) *MVMGCWorklist`, `MVM_gc_worklist_add_slow(tc, worklist, item: **MVMCollectable) void`, `MVM_gc_worklist_presize_for(tc, worklist, items: MVMint32) void`, `MVM_gc_worklist_destroy(tc, worklist) void`. `MVM_GC_WORKLIST_START_SIZE` 256 and the doubling-on-full growth of `add_slow` as in `worklist.c:14-22`; allocation through `MVM_malloc`/`MVM_realloc`/`MVM_free` (via `c.`), not `mvm_allocator`, so the C macros' `list` pointer stays valid.
- Produces: `comptime` assertions `@sizeOf(c.MVMGCWorklist) == 24` on x86_64 and `@offsetOf(c.MVMGCWorklist, "items") == 8`, `"alloc" == 12`, `"include_gen2" == 16`.

- [ ] **Step 1: Write the failing tests** in `test/worklist_test.zig` (booting a VM as `moar.zig`'s tests do; the tests call the Zig functions through `@import("../worklist.zig")` so they fail until the file exists): `"create gives alloc 256, items 0 and include_gen2 as passed"`, `"add_slow past alloc doubles alloc and keeps every item in push order"` (push 1000 distinct pointers through `add_slow`, assert `alloc == 1024` and `list[i]` is the i-th pointer), `"presize_for 5000 then 5000 pushes leaves alloc unchanged"`, `"the C add macro and a Zig pop agree"` (Review Focus: push one item with the translated `MVM_gc_worklist_add_include_gen2_nocheck`, read it back with `list[items - 1]`), `"destroy then create again works"`.
- [ ] **Step 2: Register the root** (`gc-test`) in `build.zig` and run `zig build unit-test`; expected: FAIL (`worklist.zig` not found).
- [ ] **Step 3: Implement `worklist.zig`** with the four functions and the export block; add the `[zig]` line and the root import; `zig build install --prefix /tmp/claude-1000/gc-z-base`; `zig build unit-test`, `zig build test`; expected: PASS, pristine.
- [ ] **Step 4: Oracle**: `oracle.sh --base=/tmp/claude-1000/gc-c-oracle --head=<gc-head rebuilt with -Dgc-debug=1 into /tmp/claude-1000/gc-z-oracle> --volume=100000` both tiers, both settings; expected: exit 0 on all four.
- [ ] **Step 5: `zig fmt --check src/zig/gc`; commit** `"GC: worklist in Zig"`.

### Task 4: `allocation.c` to `src/zig/gc/allocation.zig`

**Files:**
- Create: `src/zig/gc/allocation.zig`, `src/zig/gc/test/allocation_test.zig`.
- Modify: `build/sources.list`, `src/zig/root.zig`, `src/zig/gc/gc_test.zig`.

**Interfaces:**
- Produces: `comptime` assertions on the `MVMThreadContext` fields the nursery path uses (`nursery_fromspace`, `nursery_tospace`, `nursery_alloc`, `nursery_alloc_limit`, `gc_status`, `nursery_fromspace_size`, `nursery_tospace_size`, `allocate_in_gen2`) existing with the translated types `?*anyopaque`/`usize`/`u32`, and `@offsetOf(c.MVMThreadContext, "num_temproots")` equal to the layout probe's value (spec section 8, layout checks).
- Produces (exported, `allocation.h` signatures): `MVM_gc_allocate_nursery(tc, size: usize) ?*anyopaque`, `MVM_gc_allocate_stable(tc, repr: *const MVMREPROps, how: ?*MVMObject) *MVMSTable`, `MVM_gc_allocate_type_object(tc, st) *MVMObject`, `MVM_gc_allocate_object(tc, st) *MVMObject`, `MVM_gc_allocate_frame(tc) *MVMFrame`. The nursery path: `MVM_ALIGN_SIZE`, the `#if MVM_GC_DEBUG < 3` retry loop as `if (comptime c.MVM_GC_DEBUG < 3)`, the plain read of `tc->gc_status` at the interrupt check exactly where allocation.c:20 reads it, `MVM_gc_enter_from_allocator` on `INTERRUPT`, the panic `"Attempt to allocate more than the maximum nursery size"` for `size > MVM_NURSERY_SIZE`, zeroing as the C does (`memset` of the returned block), the stable/type-object/object/frame field initialisation in the C order.

- [ ] **Step 1: Write the failing tests**: `"nursery allocation is 8-aligned, zeroed and bumps alloc"`, `"request above MVM_NURSERY_SIZE panics with the C message"` (expect the process to abort: run in a child via `std.process.Child` on the test binary with a filter arg, as the spec's "panic" tests must), `"request larger than the remaining space collects and retries"` (fill the nursery to within 100 bytes of `nursery_alloc_limit`, allocate 200, assert `tc->instance->gc_seq_number` advanced by 1 and the object is in the new to-space), `"allocate_object sets st, owner thread id and header flags as C"` (compare every header byte of an object from the Zig path with one from `c.MVM_gc_allocate_object` is impossible once swapped; instead assert `flags1`, `flags2`, `owner`, `st`, `sc_forward_u` against the values `allocation.c:84-96` writes), and the Review Focus threaded test `"allocation observes INTERRUPT set by another thread"` (a second `std.Thread` calls `c.MVM_gc_mark_thread_blocked` on its own tc after `MVM_tc_create`, the main thread allocates until a collection runs; assert the collection's `seq` advanced and both threads' `gc_status` return to NONE/UNABLE as the C transitions table says).
- [ ] **Step 2: Run `zig build unit-test`**; expected: FAIL (file not found).
- [ ] **Step 3: Implement**, add the `[zig]` line and root import, rebuild `gc-z-base`; `zig build unit-test`, `zig build test`; expected: PASS.
- [ ] **Step 4: Oracle** at 100 000, both tiers and settings; expected: exit 0.
- [ ] **Step 5: Commit** `"GC: nursery and object allocation in Zig"`.

### Task 5: `gen2.c` to `src/zig/gc/gen2.zig`

**Files:**
- Create: `src/zig/gc/gen2.zig`, `src/zig/gc/test/gen2_test.zig` (pure Zig where possible: the allocator takes an `MVMInstance *` only for `MVM_malloc` accounting, so the tests boot a VM like the others).
- Modify: `build/sources.list`, `src/zig/root.zig`, `src/zig/gc/gc_test.zig`, `build.zig:128` (add `src/zig/gc/gen2.zig` to the pure unit-test roots only if its comptime tables can be tested without a VM; otherwise skip).

**Interfaces:**
- Produces (exported, `gen2.h` signatures): `MVM_gc_gen2_create(i) *MVMGen2Allocator`, `MVM_gc_gen2_allocate(al, size: MVMuint32) ?*anyopaque`, `MVM_gc_gen2_allocate_zeroed`, `MVM_gc_gen2_destroy(i, al)`, `MVM_gc_gen2_transfer(src_tc, dest_tc)`, `MVM_gc_gen2_compact_overflows(al)`. Bin geometry at comptime: `binOf(size)` = `size >> MVM_GEN2_BIN_BITS`, less one when `size` is a multiple of 8, as `gen2.c:60-70` computes it (corrected at Task 10: this text first said `(size >> MVM_GEN2_BIN_BITS) - 1`, which is wrong for sizes that are not multiples of 8; the C rounds up, Task 5 followed the C), `sizeOfBin(bin)` = `(bin + 1) << MVM_GEN2_BIN_BITS`, pages of `MVM_GEN2_PAGE_ITEMS` items, overflows list growth from `MVM_GEN2_OVERFLOWS` 32 doubling, free-list threading through the first word of a freed item, the `MVM_CF_DEBUG_IN_GEN2_FREE_LIST` flag under `comptime c.MVM_GC_DEBUG != 0`.
- Produces: `comptime` assertions that `sizeOfBin(MVM_GEN2_BINS - 1) == 320` and `@sizeOf(c.MVMGen2SizeClass) == 40`, `@sizeOf(c.MVMGen2Allocator) == 24`.

- [ ] **Step 1: Write the failing tests**: `"bin geometry matches gen2.c"` (table of (size, bin, item size) for sizes 8, 16, 24, 320, and that 321 and above go to overflows; corrected at Task 10 from 328), `"allocate returns page items in order and reuses the free list"`, `"allocate_zeroed zeroes"`, `"transfer moves every page and overflow to dest and leaves src empty"`, `"compact_overflows drops NULL entries and keeps order"`, `"destroy frees every page"` (count `MVM_malloc`/`MVM_free` through the test's own wrappers is not possible; assert `destroy` returns and a second `create` works).
- [ ] **Step 2: Run `zig build unit-test`**; expected: FAIL.
- [ ] **Step 3: Implement**, swap line, root import, rebuild; suites PASS.
- [ ] **Step 4: Oracle** at 100 000, both tiers and settings; expected: exit 0.
- [ ] **Step 5: Commit** `"GC: gen2 size-class allocator in Zig"`.

### Task 6: `roots.c` to `src/zig/gc/roots.zig`

**Files:**
- Create: `src/zig/gc/roots.zig`, `src/zig/gc/test/roots_test.zig`.
- Modify: `build/sources.list`, `src/zig/root.zig`, `src/zig/gc/gc_test.zig`.

**Interfaces:**
- Produces (exported, all 16 `roots.h` declarations with their signatures: `MVM_gc_root_add_permanent_desc`, `_add_permanent`, `_add_permanents_to_worklist`, `_add_instance_roots_to_worklist`, `_add_tc_roots_to_worklist`, `_temp_push_slow`, `_temp_mark`, `_temp_mark_reset`, `_temp_pop_all`, `_add_temps_to_worklist`, `_gen2_add`, `_add_gen2s_to_worklist`, `_add_gen2s_to_snapshot`, `_gen2_cleanup`, `_add_frame_roots_to_worklist`, `_add_frame_registers_to_worklist`). The `add_collectable` macro of roots.c:54 becomes a comptime-dispatched helper over `worklist == null` (heap snapshot path, calling `c.MVM_profile_heap_add_collectable_rel_const_cstr`). The instance- and tc-root lists are walked in the C order (roots.c:67-241); the order determines marking order and therefore to-space layout, so it is part of fidelity.
- Produces: `scan_lexicals` and `is_stack_frame` private.

- [ ] **Step 1: Write the failing tests**: `"temp root push grows from 16 doubling and keeps roots"` (Review Focus: push 1000 refs through the slow path, assert `alloc_temproots` is 1024 and every slot points where it did), `"mark and mark_reset restore num_temproots"`, `"gen2_add sets IN_GEN2_ROOT_LIST and gen2_cleanup drops entries whose referents moved to gen2"` (construct a gen2 object referencing a nursery object via `MVM_ASSIGN_REF`, run `c.MVM_gc_enter_from_allocator` twice, assert the flag transitions `roots.c:304-407` make), `"instance roots are added in the C order"` (count worklist items after `add_instance_roots_to_worklist` on a fresh instance against a constant captured from the C build in Task 2's prefix: the test's expected value is written into the test from one run of the C collector and documented as such), `"frame registers add only object and string registers"`.
- [ ] **Step 2: Run**; expected: FAIL.
- [ ] **Step 3: Implement**, swap, import, rebuild; suites PASS.
- [ ] **Step 4: Oracle** at 100 000, both tiers and settings; expected: exit 0.
- [ ] **Step 5: Commit** `"GC: root sets in Zig"`.

### Task 7: `collect.c` to `src/zig/gc/collect.zig` (and `atomic.zig`)

**Files:**
- Create: `src/zig/gc/atomic.zig`, `src/zig/gc/collect.zig`, `src/zig/gc/test/atomic_test.zig` (pure Zig, host), `src/zig/gc/test/collect_test.zig`.
- Modify: `build/sources.list`, `src/zig/root.zig`, `src/zig/gc/gc_test.zig`, `build.zig:128` (add `src/zig/gc/atomic.zig` to the pure unit-test roots).

**Interfaces:**
- Produces: `atomic.zig`: `pub fn load(ptr: anytype) @TypeOf(ptr.*)`, `store(ptr, v)`, `add(ptr, v) old`, `incr(ptr) old`, `decr(ptr) old`, `cas(ptr, old, new) prev` (`@cmpxchgStrong`, returning the previous value as `MVM_cas` does), `fence()` (`@fence(.seq_cst)`), all `.seq_cst`, accepting `*usize`, `*u32`, `*u64` and `*?*T`.
- Produces (exported, `collect.h` signatures): `MVM_gc_new_thread_nursery_size(i) MVMuint32`, `MVM_gc_collect(tc, what_to_do: MVMuint8, gen: MVMuint8)`, `MVM_gc_mark_collectable(tc, worklist, item)`, `MVM_gc_collect_free_nursery_uncopied(executing_thread, tc, limit)`, `MVM_gc_collect_free_gen2_unmarked(executing_thread, tc, global_destruction: MVMint32)`, `MVM_gc_collect_free_stables(tc)`; private: `process_worklist`, `pass_work_item`, `pass_leftover_work`, `add_in_tray_to_worklist`, `push_work_to_thread_in_tray`, `enqueue_stable_for_deletion`, the `WorkToPass`/`ThreadWork` types. The copy-versus-promote decision (`MVM_CF_NURSERY_SEEN` then `MVM_CF_SECOND_GEN`), the forwarding pointer, the nursery doubling rule (`collect.c:88-96`), `MVM_GC_PASS_WORK_SIZE` 62, the REPR hook calls (`gc_mark`, `gc_free`, `gc_cleanup`, `gc_free_repr_data`, `gc_mark_repr_data`), the STable deletion CAS (`moar.trycas`), and the Task 1 debug counters, all as in C.

- [ ] **Step 1: Write the failing tests**: `atomic_test.zig` (`cas` returns the previous value and leaves the slot on mismatch; `add` returns old; works on a pointer slot); `collect_test.zig`: `"an object surviving two collections is promoted and its forwarding pointer followed"` (allocate, root it, `enter_from_allocator` twice, assert `MVM_CF_SECOND_GEN` set after the second and the root updated), `"promoted bytes count the object's size"` (read `tc->gc_promoted_bytes` after the promotion run, compare to the object's `st->size` as rounded by `MVM_ALIGN_SIZE`), `"unreferenced gen2 object is freed on a full run"` (tier-2 style: set `instance->gc_debug_rss_override` in a `-Dgc-debug=1` test build only; otherwise skip with a message), the Review Focus in-tray test `"work pushed to a thread's in-tray from two threads is all there"` (two `std.Thread`s each push 1000 `MVMGCPassedWork` blocks onto a third tc's `gc_in_tray` through the same CAS loop `collect.c:417-449` uses, exposed to the test as a `pub` function of `collect.zig`; the main thread then walks the list and counts 2000 blocks), `"nursery doubles after a run that filled it, up to MVM_NURSERY_SIZE"`.
- [ ] **Step 2: Run**; expected: FAIL.
- [ ] **Step 3: Implement `atomic.zig`** then `collect.zig`; swap, import, rebuild; `zig build unit-test` (pure and linked), `zig build test`; expected: PASS.
- [ ] **Step 4: Oracle** at 10 000 and 100 000, both tiers and settings; expected: exit 0. Then the stress prefixes: rebuild `gc-z-stress` from this head; nqp `make test` under `gc-c-stress` and `gc-z-stress` (`LD_LIBRARY_PATH`): identical pass/fail lists.
- [ ] **Step 5: Commit** `"GC: collector and atomics helper in Zig"`.

### Task 8: `wb.c`, `objectid.c`, `debug.c`, `finalize.c` to Zig

**Files:**
- Create: `src/zig/gc/wb.zig`, `src/zig/gc/objectid.zig`, `src/zig/gc/debug.zig`, `src/zig/gc/finalize.zig`, `src/zig/gc/test/small_test.zig`.
- Modify: `build/sources.list` (four lines), `src/zig/root.zig`, `src/zig/gc/gc_test.zig`.

**Interfaces:**
- Produces (exported): `MVM_gc_write_barrier_hit(tc, update_root)`, `MVM_gc_write_barrier_hit_by(tc, update_root, referenced)` (both call `MVM_gc_root_gen2_add` as `wb.c` does); `MVM_gc_object_id(tc, obj) MVMuint64`, `MVM_gc_object_id_use_allocation(tc, item) ?*anyopaque`, `MVM_gc_object_id_clear(tc, item)` (the `MVM_ptr_hash_*` calls go through `c.`, which resolves to the Zig hash engine's exports); `MVM_gc_debug_find_region(tc, ptr)` and `MVM_gc_debug_log_collection(tc, for_tc, full)` (Task 1's writer; byte-identical output, `std.fmt` formatting through a `c.fprintf` call to keep one code path: use `c.fprintf` with the same format string); `MVM_gc_finalize_set`, `MVM_gc_finalize_add_to_queue`, `MVM_finalize_walk_queues`, `MVM_gc_finalize_run_handler`, plus `reinstate_last_handler_result` and `mark_last_handler_result` exported under their C names (they are passed by address to `MVM_callstack_allocate_special_return`).
- `debug.zig`'s body is `if (comptime c.MVM_GC_DEBUG == 0) {}` empty, matching `#if MVM_GC_DEBUG` wrapping all of `debug.c`; the export block exports only when non-zero.

- [ ] **Step 1: Write the failing tests**: `"write barrier hit adds the root to the gen2 root list once"`, `"object_id is stable across a collection and clear removes it"`, `"finalize_set marks the type and add_to_queue grows the queue"`, `"finalize queue walk moves finalizable dead objects to finalizing"` (allocate a finalizable object, drop the root, run a collection, assert `tc->num_finalizing` is 1), and at `-Dgc-debug=1` only: `"log_collection writes the Task 1 format"` (write to a temp file, compare against a string built from the tc fields).
- [ ] **Step 2: Run**; expected: FAIL.
- [ ] **Step 3: Implement the four files**, four swap lines, imports, rebuild; suites PASS.
- [ ] **Step 4: Oracle** at 100 000, both tiers and settings, with `gc-z-oracle` rebuilt from this head (the log writer is now Zig): exit 0 proves the writer matches byte for byte.
- [ ] **Step 5: Commit** `"GC: write barrier, object ids, finalization and debug helpers in Zig"`.

### Task 9: `orchestrate.c` to `src/zig/gc/orchestrate.zig`

**Files:**
- Create: `src/zig/gc/orchestrate.zig`, `src/zig/gc/test/orchestrate_test.zig`.
- Modify: `build/sources.list`, `src/zig/root.zig`, `src/zig/gc/gc_test.zig`.

**Interfaces:**
- Produces (exported, `orchestrate.h` signatures): `MVM_gc_enter_from_allocator(tc)`, `MVM_gc_enter_from_interrupt(tc)`, `MVM_gc_mark_thread_blocked(tc)`, `MVM_gc_mark_thread_unblocked(tc)`, `MVM_gc_is_thread_blocked(tc) MVMint32`, `MVM_gc_global_destruction(tc)`; private `add_work`, `signal_one_thread`, `signal_all`, `process_in_tray`, `clear_intrays`, `finish_gc`, `is_full_collection` (with Task 1's override), `run_gc`, `react_to_debugserver_request`. Every status transition of the inventory's table (orchestrate.c lines 35, 51, 66, 270, 276, 280, 327, 331, 337, 341, 350, 367, 376, 668, 783, 791) as a `atomic.cas` with the same from/to values and the same panic messages; the `thread_obj->body.stage` writes at 237 and 252; `gc_seq_number` increment; `gc_promoted_bytes_since_last_full` add and reset; the `uv_mutex`/`uv_cond` calls through `c.`; the `#if MVM_GC_DEBUG >= 3` memset and the `in_spesh` panic as comptime blocks; the profiler and heap-snapshot hooks; `MVM_gc_global_destruction` ported as written (ruling above).

- [ ] **Step 1: Write the failing tests**: `"a single thread's collection advances gc_seq_number by one and returns status NONE"`, `"mark_thread_blocked then unblocked round-trips through UNABLE"`, `"a blocked thread's collection is stolen by the coordinator"` (second thread allocates a rooted object then blocks; main thread forces a collection; assert the second thread's `gc_status` went through STOLEN (observe via the Task 1 log: its line has `coord=0` and the sequence number of the main thread's run) and its object was moved), `"global_destruction requests suspend on the calling tc"` (asserts the as-written behaviour: after the call the caller's own `gc_status` carries `SUSPEND_REQUEST`), `"is_full_collection uses the RSS override at gc-debug 1"` (skip at 0).
- [ ] **Step 2: Run**; expected: FAIL.
- [ ] **Step 3: Implement**, swap, import, rebuild; suites PASS; `zig build -Dzig-impl=false install --prefix /tmp/claude-1000/gc-allc-check` still builds and `zig build test` passes there.
- [ ] **Step 4: Oracle** at 10 000 and 100 000, both tiers and settings; expected: exit 0 on all eight. (The 1 000 000 cells were struck 2026-11-08 by the user: the crc-getter workload is capped at 100 000 for this campaign; a million objects is for a later bottleneck investigation.)
- [ ] **Step 5: Stress and threads**: rebuild `gc-z-stress`; rakudo `make test` under both stress prefixes: identical pass/fail lists; `crc-getter.raku --volume=100000 --runs=20` under both stress prefixes five times each: all exit 0, output identical modulo the timing values.
- [ ] **Step 6: Commit** `"GC: orchestration in Zig; the C collector is fully replaced under -Dzig-impl"`.

### Task 10: Acceptance, docs, errata

**Files:**
- Modify: `docs/zig-build.md` (a "## Garbage collector" section: the file map, the two options, the oracle and stress recipes, the log format), the spec (status line "executed; see the plan's Acceptance"; errata for anything a task changed), this plan ("## Acceptance" table).
- Record: `traces/llm/bench/gc-final-oracle.md`, `gc-final-crc-ab.md` (+ raw), `gc-final-spectest.txt`.

- [ ] **Step 1: Final oracle**: `gc-c-oracle` against `gc-z-oracle` rebuilt from HEAD: volumes 10 000 and 100 000 (the 1 000 000 size struck 2026-11-08, user ruling), both settings, both tiers, three repeats each side; expected: exit 0 on every cell; record `gc-final-oracle.md`.
- [ ] **Step 2: Proving-ground A/B**: `ab.sh --base=/tmp/claude-1000/gc-c-base/lib --head=/tmp/claude-1000/gc-z-base/lib --rounds=7 --runs=5 --volume=100000 --runs-per-batch` as the script takes it (the workload is capped at 100 000 objects by the user's ruling of 2026-11-08; the 1 000 000 unit and the 10 000 000 single run are struck), both `--bad-packages` settings; rule: head within the round spread of base, or median ratio at most 1.00, for wall and RSS; a win beyond the spread is reported and investigated (it may be a behaviour change). Record `gc-final-crc-ab.md`. The spectest A/B of Step 3 is the primary performance gate at this size.
- [ ] **Step 3: Spectest A/B**: order base head head base base head per the recipe; medians of three; rule: wall and RSS within spread or 1 percent, zero new failures; record `gc-final-spectest.txt` in the format of `bakeoff-final-spectest.txt`.
- [x] ~~**Step 4: Reference stall reproduced**~~ STRUCK 2026-11-04 with Task 2 Step 5 (user ruling): no `gc-final-stall.md`.
- [ ] **Step 5: Suites**: `zig build unit-test`, `zig build test` (both `-Dzig-impl`, with `-Dgc-debug=0` and `=1`), `zig build strategy-test -Dnqp-prefix=/tmp/claude-1000/tune-zig-prefix`, `prove tools/bench/t/`, `zig fmt --check src/zig`, `perl -c`, `sh -n` on the scripts; output pristine. Normal-configuration suites under both collectors (spec section 9): nqp `make test` and rakudo `make test` with `LD_LIBRARY_PATH` of `gc-c-base` and then of `gc-z-base`; identical pass/fail lists.
- [ ] **Step 6: Docs, errata, the Acceptance table** (the spec's goals of section 2 as rows: evidence path per row), and a "## C observations for a later campaign" list (the `MVM_gc_global_destruction` tc CAS; anything else the ports noticed, with file:line and no fix).
- [ ] **Step 7: Commit** MoarVM (`"GC in Zig: docs, final acceptance"`), traces (`"gc: acceptance"`), pointer. Do not merge into `zig-hash-engine`; the user says when.

---

## Measurement conventions (for every task that measures)

As the Global Constraints state; records under `traces/llm/bench/gc-*` with: date, MoarVM and traces shas, build options per prefix, CPU, 1-minute load before each run, the exact commands, raw file names. The oracle's logs are raw files; the A/B's `.time` files are raw files.

## Acceptance

Task 10, 2026-11-08, MoarVM e0444fc47 (the last port commit 5abaf4507). Rows: the goals of the spec's section 2. Records under `traces/llm/bench/`.

| goal (spec section 2) | verdict | evidence |
|---|---|---|
| Every C file in `src/gc/` replaced by Zig under `-Dzig-impl`, selectable along the ladder, the C files untouched except the three bounded kinds of edit | met: ten `[zig]` lines in `build/sources.list` (Tasks 3-9); `git diff 139d404ed e0444fc47 -- src/gc src/core src/moar.c` is empty, so the only C edits are Task 1's guards and debug-only instrumentation; the all-C fallback (`-Dzig-impl=false`) builds and passes `zig build test` | `bench/gc-final-suites.md` (the all-C row), `docs/zig-build.md` "Garbage collector" (the file map) |
| Fidelity: collection-by-collection parity on the deterministic workload | met: eight cells (10 000 and 100 000, both settings, both tiers), exit 0 everywhere, each side repeatable, base and head byte-identical even before the tier filter | `bench/gc-final-oracle.md` |
| Fidelity: nqp and rakudo test suites green under both builds, normal and stress | met: identical per-file lists in all four pairs; the one rakudo failure (`t/04-nativecall/02-simple-args.t` 17-18) is the same under every prefix, the C collector included | `bench/gc-final-suites.md` |
| Fidelity: the spectest with zero new failures | met: six runs, all PASS, Files=1365, Tests=138715, identical summary lists | `bench/gc-final-spectest.txt` |
| No regression: spectest wall and RSS within spread or 1 percent (the primary gate at the capped size) | met: wall 1.006, RSS 0.999 (medians of three) | `bench/gc-final-spectest.txt` |
| No regression: crc-getter not slower, not larger (volume 100 000 by the 2026-11-08 cap) | not met in one setting: plain wall 1.011 and RSS 1.015, both just outside base's round spread; `--bad-packages` wall 1.003 and RSS 1.005, within spread. No win to investigate; not rerun, not tuned | `bench/gc-final-crc-ab.md` |
| Zig features where they make the port clearer or safer, without changing behaviour (section 8) | met: comptime debug levels (`c.MVM_GC_DEBUG` blocks), typed seq_cst atomics with a C-site comment each (`atomic.zig`), comptime layout and gen2 geometry assertions, the layout probes, unit tests per file; the worklist stays the C ABI rather than a generic (the C macros share it) | `docs/zig-build.md` "Garbage collector", `bench/gc-final-suites.md` (unit tests) |
| Reference record of the hundred-million stall, reproduced by the port | struck by the user on 2026-11-04 (spec section 7 erratum); no record | spec "Errata" |

## C observations for a later campaign

Noticed while porting, ported as written (the Zig file's comment names each), never acted on in this campaign. No fix is proposed here.

- `src/gc/orchestrate.c:802` and `:810` (`MVM_gc_global_destruction`, inside the loop over the other threads that starts at :798): both `MVM_cas` calls and the `MVM_load` at :817 operate on the caller's own `tc->gc_status`, not on `cur_thread->body.tc->gc_status`, so the other threads are never asked to suspend; the first CAS succeeds on the caller's own status (NONE) for the first other thread, and for every later one the third check finds the caller's own SUSPEND_REQUEST and breaks. Zig: `src/zig/gc/orchestrate.zig:1002-1005`.
- `src/gc/roots.c:136-139` (`MVM_gc_root_add_instance_roots_to_worklist`): `subscriptions.GCEvent` is added twice, the second time under the description "VM Event SpeshOverviewEvent type"; `subscriptions.SpeshOverviewEvent` (`src/core/instance.h:122`, set in `src/moar.c:947-950`, read by `src/spesh/worker.c:129`) is never marked. Zig: `src/zig/gc/roots.zig:146-149`.
- `src/gc/roots.c:233-237` (`MVM_gc_root_add_tc_roots_to_worklist`): the `mark_args` loop calls `MVM_gc_worklist_add` directly instead of `add_collectable`, so on the heap-snapshot path (worklist NULL, snapshot set) it would add to a NULL worklist rather than describe the roots to the snapshot. Zig: `src/zig/gc/roots.zig:243-246`.

