# Zig port of the MoarVM garbage collector: design

Status: executed and accepted; see the plan's Acceptance. The one row outside its rule (crc-getter plain A/B at 100k: 1.1 percent wall, 1.5 percent RSS, spreads overlapping, spectest gate passed) was accepted by the user on 2026-11-08 as transitional: the line-by-line translation is the foundation, and the cost is expected to fall as the port moves to Zig-native shapes. Approved by the user 2026-11-04 ("let's go!") after the builder check; plan `traces/llm/plans/2026-11-04-zig-gc-port.md`. Campaign 4 of the Zig migration (after the hash engine, its tuning and bake-off, and the internal-tables campaign). The full-Zig build stack (migration phases 3-6) is deferred; this campaign runs on the existing `-Dzig-impl` build of MoarVM with nqp and rakudo built by the Perl path, as the hash campaigns did.

## 1. Intent

Port everything under `src/gc/` to Zig behind the same C symbols, as a faithful reproduction of the current collector: the same nursery, the same promotion rule, the same gen2 size classes and page layout, the same root sets, the same write barrier semantics, the same stop-the-world orchestration and work stealing across threads, the same finalization and object-id behaviour. The user's words: the collector is the product of a great deal of careful work by its author and the port must reproduce that judgment, not second-guess it. Improvements are a later campaign, if any.

Two reasons the user gave: learning the VM by porting it piece by piece (the hash engine was the first piece), and keeping the door open to measurable speedups that could lead to adoption of the Zig work. This campaign is the first; it earns the second only by being a correct, no-regression port that later work can build on (a comptime-derived `gc_mark` per REPR body is the next step after this one, per the step-zero spec's Appendix A and the user's note on the heap allocator question).

## 2. Goals, non-goals, anti-goals

Goals:
- Every C file in `src/gc/` (allocation, collect, debug, finalize, gen2, objectid, orchestrate, roots, wb, worklist) replaced by Zig under `-Dzig-impl`, selectable file by file against its C original during the campaign, the C files untouched except for three bounded kinds of edit (my call after the builder check; section 3): a header declaring a formerly inline function `extern` under `MVM_ZIG_IMPL` (the hash engine's pattern), `#ifndef` guards on the two hard-coded constants the stress build overrides, and debug-only instrumentation compiled out at debug level 0 (the per-collection log and the RSS pin of section 5), which must exist in the C collector too so the oracle compares like with like.
- Fidelity shown, not assumed: collection-by-collection parity with the C collector on a deterministic workload (section 5), the nqp and rakudo test suites green under both builds in normal and stress configurations, and the spectest with zero new failures.
- No performance or memory regression against the C collector: spectest wall and RSS within the campaign's conventions, and the proving-ground program (section 6) not slower and not larger in peak RSS.
- Zig's native features used wherever they make the port clearer or safer without changing behaviour (section 8).
- A reference record of the collector's behaviour under memory pressure (the hundred-million-object stall, section 7), taken on the C collector before the port and reproduced by the port.

Non-goals:
- Any change to collection policy, sizes, thresholds, or data-structure layout. Not even "obvious" ones; they go on a list for a later campaign.
- Porting the REPRs' `gc_mark`/`gc_free`/`gc_cleanup` functions, the callstack, spesh's GC interaction, or the profiler/heap-snapshot code. They stay in C and are called through their existing tables and functions.
- The full-Zig build stack (nqp and rakudo `build.zig`).
- Windows or non-x86_64 targets (the Zig build is linux x86_64 only today).

Anti-goals (what makes this a failure even if the gates pass):
- A port that silently changes a promotion, barrier, or orchestration decision and only shows up as a rare crash under threads. Fidelity evidence outranks speed evidence throughout.
- A port that compiles the C collector's debug checks into the release path, or drops them from the debug path.
- "While I'm here" cleanups of the C side.

## 3. Constraints

- Build: the existing Zig build of MoarVM (`zig build install --prefix <P>`, LTO, ReleaseFast, x86-64-v3; `-Dzig-impl` on by default). A replaced C file is declared in the `[zig]` section of `build/sources.list` (`<zig file>: <c file>`), its symbols exported from a `*_exports.zig` with `callconv(.c)`, the C headers reached through the translate-c view of `moar.h` (`src/zig/moar_c.h`, `moar.c`). Zig 0.16 as pinned by the repo.
- Measurement: the hash campaigns' conventions (`traces/llm/plans/2026-11-03-zig-hash-internal-tables.md`, "Measurement conventions"): variants as libmoar builds in their own prefixes, run through `LD_LIBRARY_PATH` against one installed nqp and rakudo; interleaved rounds, medians of at least five runs per round, spreads as the min and max of round medians; load under 2.0 before a run and recorded; nothing judged from a single run; records under `traces/llm/bench/gc-*` with the header fields of `bakeoff-scoreboard.md`.
- Machine: 32 GB, no swap, no OOM daemon. Every memory-heavy run goes under a hard cap (`ulimit -v`, or a cgroup if `ulimit -v` breaks moar's mmap use; the builder checks which) and never alongside another heavy job; the other campaign's eval-server bench (`pgrep -af "context-bench|rakudo-image|eval-serve"`) must be absent before a run.
- Process: no git worktrees (user rule); work in the main checkout on a branch from `zig-hash-engine`; the campaign's records live in the `traces/llm` submodule; no merge until the user says.
- Threads: the orchestration port must preserve the C code's atomic orderings exactly (the `AO_*` and `MVM_cas`/`MVM_load`/`MVM_store` sites); where the C side uses a full barrier, the Zig side uses `.seq_cst`, not a weaker ordering chosen by reasoning.

## 4. What is being ported (the shape of the C collector, for the builder)

Sizes: 2,762 lines of C in `src/gc/*.c` plus about 620 in the headers. Entry points per file (exported, must keep their names and signatures):
- `allocation.c`: `MVM_gc_allocate_nursery`, `MVM_gc_allocate_object`, `MVM_gc_allocate_type_object`, `MVM_gc_allocate_stable`, `MVM_gc_allocate_frame`; the inline `MVM_gc_allocate`, `MVM_gc_allocate_zeroed`, and the gen2-default set/clear in `allocation.h` stay C inline (they only test `tc->allocate_in_gen2` and bump the nursery pointer; the builder may move them to Zig only if the hash engine's precedent for inline headers applies cleanly, otherwise they stay).
- `collect.c`: `MVM_gc_collect`, `MVM_gc_mark_collectable`, `MVM_gc_collect_free_nursery_uncopied`, `MVM_gc_collect_free_gen2_unmarked`, `MVM_gc_collect_free_stables`, `MVM_gc_collect_enqueue_stable_for_deletion`, `MVM_gc_new_thread_nursery_size`. The copying collector: nursery to-space, promotion on the second survival (`MVM_CF_NURSERY_SEEN` then `MVM_CF_SECOND_GEN`), the forwarding pointer, the worklist loop that marks through objects, STables, frames and the REPR tables, gen2 freeing on full collections, STable deletion queue.
- `gen2.c`: `MVM_gc_gen2_create/destroy`, `MVM_gc_gen2_allocate`, `MVM_gc_gen2_allocate_zeroed`, `MVM_gc_gen2_transfer`, `MVM_gc_gen2_compact_overflows`: the size-class allocator (`MVM_GEN2_BIN_BITS` 3, `MVM_GEN2_BINS` 40, `MVM_GEN2_PAGE_ITEMS` 256), free lists, pages, and the overflow list for large objects.
- `roots.c`: permanent roots, instance roots, thread-context roots, temp roots (stack with mark/reset), the gen2 root list (inter-generational references), frame roots and frame registers to the worklist, the gen2-to-snapshot variant for the heap profiler.
- `worklist.c`/`worklist.h`: the mark worklist with its inline fast-path add and the slow-path grow.
- `orchestrate.c`: `MVM_gc_enter_from_allocator`, `MVM_gc_enter_from_interrupt`, `MVM_gc_mark_thread_blocked/unblocked`, `MVM_gc_is_thread_blocked`, `MVM_gc_global_destruction`: the stop-the-world protocol over `tc->gc_status` (`NONE`, `INTERRUPT`, `UNABLE`, `STOLEN` with the suspend-request states), the coordinator election, work stealing of blocked threads' collections, the per-run sequence number, the full-collection decision from promoted bytes since the last full run, finalization and profiler hooks, thread cleanup.
- `finalize.c`, `objectid.c`, `debug.c`, `wb.c`: small; the write barrier's inline fast path lives in `wb.h` and stays C inline unless the builder has a clean way to keep it inline from Zig.

Constants to carry verbatim: `MVM_NURSERY_SIZE` 16 MiB, `MVM_NURSERY_THREAD_START` 512 KiB and the nursery growth rule in `collect.c`, the gen2 bin parameters, the `MVM_GC_DEBUG` 0-3 assert semantics (`MVM_ASSERT_NOT_FROMSPACE`, `MVM_CHECK_CALLER_CHAIN`, collect-on-every-allocation at 3). `MVM_GC_DEBUG_LOG_FLAGS` is a hard-coded 0 with its flag enum mostly commented out (`orchestrate.h:47`); it is not a semantics to carry, only the `GCDEBUG_LOG` macro shape.

One fact the builder must plan around (builder check): the full-versus-nursery decision in `orchestrate.c` (about lines 409-426) reads the live resident set size through `uv_resident_set_memory` once the promoted bytes since the last full run pass a threshold. RSS depends on malloc and page state, not only on the allocation sequence, so that one decision is not deterministic across runs even within one build. Section 5 handles it.

## 5. Fidelity oracle (the decisive evidence)

On a single thread the allocation sequence of a deterministic program is identical under both builds, so a faithful port must make identical decisions. The oracle is a per-collection log, produced by both builds, compared line by line:
- Fields per collection: sequence number, full or nursery, the thread responsible, nursery from-space size, bytes promoted this run (per thread and instance totals), gen2 bytes freed on a full run, STables freed, finalization queue length, and the nursery size chosen for the next run.
- Source of the log (my call): not the profiler. Profiling perturbs allocation (it allocates, and `orchestrate.c` special-cases promoted-bytes accounting under it) and `MVMProfileGC` lacks half the fields. Instead, a dedicated per-collection log line emitted from the orchestration at the end of each run, compiled in only at GC debug level 1 or above (a `GCDEBUG_LOG`-style macro in C, a comptime-gated call in Zig), written to a file named by an environment variable, one line per collection with the fields above and the thread id. It is added to the C collector as debug-only instrumentation (section 3) so both builds produce it from the same code path, and it vanishes from release builds.
- The RSS-dependent decision (my call): the oracle has two tiers. Tier 1, on the release-equivalent path (debug level 1, no pin): every field except the full-versus-nursery flag and the gen2-freed bytes must match exactly; those two are reported but not compared. Tier 2, with the RSS read pinned to a fixed value through a debug-level-only environment override in both collectors: every field must match exactly, including the full-run decisions. Tier 2 is the fidelity claim for the full-collection logic; tier 1 shows the pin itself changes nothing else.
- Workload: a sequential reduction of the user's crc-getter program (section 6): the same `Package` objects (a string attribute and a uint32 attribute), built `xx $volume` and held in one array; per batch, the same `crc32` call per item with the same comparison; the supplies, the `react` block and the `start` block removed; sizes 10 000, 100 000 and 1 000 000; `--bad-packages` on and off. Written once under `tools/bench/gc/` (my call on the location) with the vendored pure-Raku `String::CRC32` beside it under an include path, so no `zef` install is needed.
- Pass rule: identical logs (per tier) at every size, every setting, repeated three times per build to show the log is itself deterministic. Any difference is a fidelity failure, not a tuning question.
- Threads in the oracle (my call): the reduction runs with the spesh worker disabled (`MVM_SPESH_DISABLE=1`); the log carries the thread id; the main thread's collections are compared exactly, and any other thread's (event loop, signal thread) must have zero collections or an identical count, else the first task reworks the reduction until the log is repeatable. Task 1 proves repeatability before any port starts.
- Threaded fidelity: no exact oracle exists for the orchestration (thread timing is nondeterministic). Evidence instead: the full crc-getter program and the test suites under the stress configuration (section 9) on both builds, repeated, with the debug checks on; and the C orchestration's atomics mapped one to one (section 3).

## 6. Performance and memory gate (the user's bar: not slower, not more memory)

Proving ground: the user's crc-getter program (`https://5ab5traction5.bearblog.dev/an-initial-investigation-into-using-zig-to-speed-up-raku-code/`, gist `ab5tract/61e08cfaf0bb3e67b3a3dc009fa3cc7a`, file `crc-getter.raku`), the pure-Raku baseline, with `use v6.*`, `--runs=5`, `--volume=N`. It allocates N small objects held across batches (all promoted to gen2) and churns the nursery with a `crc32` per item per batch. Vendored copy under `tools/bench/gc/` with the module beside it.
- A/B unit: volume 1 000 000, both settings of `--bad-packages`, interleaved rounds, medians of at least five runs per round, wall and peak RSS through `tools/bench/timev.py`. Rule: head within the round spread of base, or at most 1.00 on the median ratio for both wall and RSS (a faithful port has no reason to win or lose; a loss outside spread fails, a win outside spread is reported and investigated, since it may mean a behaviour change).
- One run per side at volume 10 000 000 (the user measured about 700 s and 2 GB on an M2; expect similar here), wall and RSS reported, same rule applied loosely (single run, so only a loss beyond 5 percent fails).
- Spectest: the campaign's standard A/B (rakudo checkout, roast pinned at fb1d87214, `TEST_JOBS=24`, `make -o spectest_update spectest`, order base head head base base head, `timev.py`): wall and RSS medians within spread or 1 percent, zero new failures.

## 7. Reference record: the collector under pressure

Before any port lands, on the C collector: run crc-getter at volume 100 000 000 under a hard memory cap (24 GB; the machine has 32 GB and no swap) with the per-collection log on, and record `traces/llm/bench/gc-reference-stall.md`: the collection log, the gen2 growth curve (bytes promoted per run, full-run cadence, RSS over time sampled every second), where and how it stalls or is killed by the cap, and the wall at which that happens. The user has seen this run stall with memory growing and shrinking; the record is the reference behaviour the port must reproduce (same log up to the stall on the sequential variant; same qualitative curve on the real program). This is a characterization, not an investigation: no hypotheses about why, no fixes.

## 8. Where Zig earns its place (without changing behaviour)

The rule: a Zig feature is used when it makes the port clearer, safer, or cheaper to verify, and it is not used if it changes a decision, a layout, an ordering, or the release code path. Each use is named in the plan task that makes it, and the task review checks the "no behaviour change" claim.

- Comptime-generated tables: the gen2 bin sizes and the page geometry derived at comptime from the three constants, with a comptime assertion that they equal the C header's values and the C `MVMGen2Allocator` layout.
- Comptime debug levels: `MVM_GC_DEBUG` 0-3 and the debug-log flags become comptime constants (from a build option that defaults to 0, wired like `-Dhash-stats`), so the checks are `if (comptime level >= 1)` blocks that vanish at 0 and cannot be left in the release path by mistake.
- Typed atomics: `tc->gc_status` and the instance's GC counters accessed through `@atomicLoad`/`@atomicStore`/`@cmpxchgStrong` with the C orderings made explicit at each site; a comment at each site names the C macro it replaces.
- Layout checks: comptime assertions on the fields the collector depends on (`MVMCollectable` flags and forwarding pointer, `MVMThreadContext` nursery and gen2 fields, `MVMFrame` header) against the translate-c view, so a header change fails the build.
- Typed worklist: the mark worklist as a small generic over the collectable pointer type with the same growth policy; the inline fast path (`MVM_gc_worklist_add`) stays a C inline in the header unless the hash engine's precedent for exporting inline bodies applies.
- Error handling: `MVM_panic` and `MVM_oops` call sites preserved as calls into C; no Zig error unions on the hot path.
- Tests: Zig unit tests for the pure parts (gen2 allocator, worklist, temp-root stack, the promotion-state transitions on a fake collectable) with `std.testing.allocator` leak checks, following the hash engine's test layout.
- Not used: `std.mem.Allocator` over the GC heap (ruled out earlier), Zig's own `std.Thread` primitives in place of the VM's (orchestration uses the VM's mutexes and condition variables through C), any change to `MVM_malloc`-backed allocations' sizes.

## 9. Testing and stress configuration

- Zig unit tests per ported file (section 8), run by `zig build unit-test`.
- `zig build test` (moar `--version` plus nqp stage0 smoke) after every file swap.
- nqp `make test` and rakudo `make test` under both builds, normal configuration.
- Stress configuration, both builds: the debug level at 3 (collect on every allocation) is too slow for the suites, so the stress run uses level 1 with a small nursery. `MVM_NURSERY_SIZE` (`collect.h:3`) and `MVM_GC_DEBUG` (`debug.h:7`) are unconditional `#define`s, so the stress build needs `#ifndef` guards on both (my call: a two-line C edit with no effect at the defaults) and two build options (`-Dgc-debug=N`, `-Dnursery-size=N`) wired like `-Dhash-stats`, which the C path honours through the same defines. The stress prefixes: nursery 512 KiB, debug level 1, one for the C collector and one for the Zig collector. The performance base prefix is built at the defaults, where the guarded headers produce the identical binary. The rakudo `make test` suite and the crc-getter program at 100 000 run on both stress prefixes; any difference in outcome is a fidelity failure.
- The spectest as in section 6.

## 10. Task ladder (one plan task per C file, dependency order)

1. Campaign setup: branch, the per-collection log, the sequential crc-getter reduction and the vendored module, the stress prefixes, the reference records on the C collector (sections 5-7), the base prefix of the C collector for every later A/B.
2. `worklist.c`.
3. `allocation.c`.
4. `gen2.c`.
5. `roots.c`.
6. `collect.c`.
7. `wb.c`, `objectid.c`, `debug.c`, `finalize.c` (one task; small).
8. `orchestrate.c`.
9. Acceptance: oracle, stress, suites, spectest A/B, proving-ground A/B, the reference stall reproduced; docs (`docs/zig-build.md` gains the GC section and the new options); errata.

Each file task: port, unit tests, the swap line in `build/sources.list`, `zig build test`, the oracle at 100 000 (every file task re-runs the oracle, it is cheap), commit. The C file stays in the tree and buildable with `-Dzig-impl=false` until the campaign closes. Selectability is the linear ladder only (my call): at each step the files ported so far are Zig and the rest C, and `-Dzig-impl=false` gives all-C; arbitrary mixes are not supported. Where a later C file reaches a `static` helper of an earlier ported one, the helper is exported under `MVM_ZIG_IMPL` for the duration of the ladder and the export removed at acceptance.

## 11. Risks the builder should plan around

- Inline fast paths in headers (`allocation.h`, `worklist.h`, `wb.h`, `roots.h` temp-root push/pop): the hash engine turned some inline functions into `extern` declarations under `MVM_ZIG_IMPL`; for the GC's hottest paths (allocation bump, worklist add, write barrier check) that would cost a call per operation. The design prefers leaving those inline bodies in C; the plan must measure any that move.
- translate-c and `_Atomic`: the shim defines `_Atomic(T)` as `T`; Zig must access those fields only through atomic builtins, never as plain loads, where the C side uses atomics.
- The orchestration's thread-list walks, `MVM_gc_mark_thread_blocked` races, and the interrupt path through the interpreter are the hardest part; the plan gives this task its own review focus and a threaded stress run.
- Determinism of the oracle: anything in the VM that allocates on a timer or from another thread (the spesh worker thread, the event loop) can perturb the log. The reduction should run with the spesh worker disabled (`MVM_SPESH_DISABLE=1`, or whichever setting the builder verifies gives identical logs across repeats) and the first task proves the log is repeatable before any port starts.

## 12. Left to the builder

- The exact mechanism of the per-collection log and its output format.
- File-internal structure of each Zig module and its tests.
- Which inline header functions, if any, move to Zig, each with a measurement.
- The memory-cap mechanism for the hundred-million run: a cgroup memory limit (`systemd-run --user -p MemoryMax=24G --wait`) is preferred because moar reserves address space it does not touch, so a virtual-memory `ulimit` would kill earlier than the user's experience; `ulimit -v` is the fallback if user cgroup delegation is unavailable, and whichever is used is fixed for both builds and named in the record (my call).
- The order of the small-files task's contents.

## 13. Decisions recorded from the brainstorm (the user's, verbatim in spirit)

- Faithful port first; improvements maybe later.
- "Not slower and doesn't take more memory" is the bar.
- All of `src/gc/` in one campaign ("go all in"), orchestration included.
- The crc-getter program from the user's blog post is the proving ground.
- The hundred-million stall is recorded as the reference behaviour, not investigated.
- The full-Zig build stack stays deferred.

## Errata

- 2026-11-04, user ruling during Task 2: section 7 (the hundred-million reference stall) and the stall reproduction in Task 10 are struck: "let's ignore the 100 million bench after all. it's going to take way too long". The proving ground stays the one- and ten-million sizes of section 6.
- 2026-11-08, user ruling during Task 9: the crc-getter proving ground is capped at 100 000 objects for this campaign (oracle and A/B); the 1 000 000 and 10 000 000 sizes of section 6 are struck ("1 million objects will be useful for finding the bottleneck/bug but that's not what we are up to at the moment"). The spectest A/B becomes the primary performance gate.
- 2026-11-08, Task 10 (what the tasks changed against this text; the plan's Acceptance has the evidence):
  - Prefix names (Task 3 ruling): the install prefix is baked into libmoar's config strings, and a head prefix of a different length promoted 56 more bytes at `seq=2` in every oracle cell. Every pair of compared prefixes therefore has paths of equal length (`/tmp/claude-1000/gc-c-base` and `gc-z-base`, `gc-c-oracle` and `gc-z-oracle`, `gc-c-stress` and `gc-z-stress`), and `oracle.sh` and `ab.sh` refuse an unequal pair (exit 4).
  - Section 5's log mechanism, as built: one C writer `MVM_gc_debug_log_collection` in `src/gc/debug.c` (Task 1), called from `finish_gc` by both collectors until Task 8 ported `debug.c`, after which the Zig writer (`src/zig/gc/debug.zig`, the same `fprintf` format string) produced identical logs. "The thread responsible" is `coord=1`, the thread that started the run (`thread_to_blame_for_gc`); `stables_freed` lands on the coordinator's line of the run that frees them; nothing is logged for the frees at global destruction, which happen outside any run. The oracle compares every thread's lines in order; the workload has only `tid=1`.
  - Section 5's workload: the reduction also sets `RAKUDO_NO_PRECOMPILATION=1` and takes durations as `now.Num - $time.Num` (Task 2 ruling), because precompiled-module loading and Rat clock arithmetic made the allocation sequence vary from run to run.
  - Section 8, gen2 bin geometry (Task 5): the plan's interface text gave `binOf(size) = (size >> MVM_GEN2_BIN_BITS) - 1`; `gen2.c:66-68` rounds up (`size >> MVM_GEN2_BIN_BITS`, less one only when `size` is a multiple of 8; so size 12 is bin 1 and sizes from 321, not 328, go to the overflows). The port follows the C.
  - Section 8, typed atomics: Zig 0.16 has no `@fence`; `src/zig/gc/atomic.zig`'s `fence` emits `mfence` (with a memory clobber) on x86_64, what C compilers emit for the seq_cst fence. `add`, `incr` and `decr` take only `usize`-wide slots, as the C's `AO_t`.
  - Section 8, layout checks: `MVMDebugServerData` has bit-fields that translate-c leaves opaque, so `orchestrate.zig` mirrors it as an `extern struct`, its size and the offsets of the four fields the port touches probed against the C compiler (`src/zig/test/layout_probe.c`) at both debug levels (Task 9 ruling).
  - Section 11: a `[*c]` pointer's array field must be indexed as `p[0].field[i]` (or through a `*S`), never `p.*.field[i]`, which in Zig 0.16 indexes whole arrays past the field (Task 7 finding; the earlier ports had no occurrence).
  - Section 10's selectability: no static helper of a ported file was reached from a later C file, so no temporary export had to be removed at acceptance.
