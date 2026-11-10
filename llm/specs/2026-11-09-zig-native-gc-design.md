# Zig-native garbage collector: design

Status: draft for the user's approval (2026-11-09). Campaign 6 of the Zig migration, after the faithful GC port (Campaign 4, `2026-11-04-zig-gc-port-design.md`) and the Zig 0.17 migration (Campaign 5, `../plans/2026-11-08-zig-017-migration.md`). The user asked for this campaign on 2026-11-08 when accepting Campaign 4's one open row as transitional ("the theory is that performance will become better as we migrate from a line-by-line translation to a more zig-native one"), asked to brainstorm its spec, and then said "let's skip questions this time"; so every open choice below is my call, marked as such, for the user to overrule while reading.

## 1. Intent

Campaign 4 replaced every C file of `src/gc/` with a Zig port that follows the C statement by statement. That shape was the point: it made the port checkable against the C line by line, and the fidelity oracle showed the two collectors making identical decisions. Its cost was small and real: on the crc-getter proving ground the Zig collector ran 1.1 percent slower than the C one on Zig 0.16, and 2.2 to 2.7 percent slower on Zig 0.17 (clang 22 sped the C collector up more than Zig 0.17 sped up the port; `../bench/z017-crc-ab.md`). The spectest, the primary gate, is within noise on both toolchains.

This campaign tests the user's theory. It rewrites the port from a transliteration into the shape a Zig programmer would have written, under one invariant: the collector's decisions do not change. The oracle that proved Campaign 4 proves this one, collection by collection, against the C collector built from the same tree. Every step is measured, and before any shape changes a profile of both collectors says where the gap actually is, so that the rewrite aims at evidence and the result, whichever way it comes out, is explained.

Two further purposes. The user is learning the VM by porting it; the first pass through the collector was a transcription, this one is a reading, and each task records what the native shape made visible that the transliteration hid. And every later GC comparison needs the control configuration "C collector, Zig hash engine", which today exists only by editing a scratch copy of the tree (Campaign 5, Task 5); this campaign gives it a build switch first.

## 2. Goals, non-goals, anti-goals

Goals:
- A build switch that keeps the collector in C while the rest of the Zig implementations stay Zig, honoured by both builds, so the control prefix of every GC comparison comes from the tree (section 3).
- A profile of the C collector and the faithful port on the proving ground, attributing the wall-clock gap to functions, taken before the rewrite and again after it (section 7).
- The ten Zig GC files rewritten in native shapes (section 8), file by file, each step passing the oracle and measured against the C control.
- Fidelity shown as before: oracle byte-identical at both tiers, the nqp and rakudo suites and the stress configuration identical, the spectest with zero new failures (sections 5 and 9).
- Performance: the aim is to recover Campaign 4's transitional acceptance, that is a crc-getter ratio within the C control's spread or at most 1.00, for wall and peak RSS. The aim is reported, not gated (section 6 has the gate). The acceptance states the final ratio and the after-profile's account of what remains, whichever way it comes out.
- Reading notes: one record collecting, per file, what the collector does that the native reading made clearer (section 10, Task 9).

Non-goals:
- Any change to collection policy, sizes, thresholds, data-structure layout, atomic orderings or the order of root walks. The C side's layouts are the layouts; Zig views them.
- The REPRs' `gc_mark`/`gc_free` and a comptime-derived `gc_mark` per REPR body: the next campaign (step-zero spec, Appendix A item 6; `gc-heap-allocator-and-escape-analysis` memory), not this one.
- Moving the inline fast paths of the C headers (`MVM_gc_allocate`, the `MVM_gc_worklist_add` macros, `MVM_gc_write_barrier`, the temp-root push and pop) into Zig. Their C callers need them inline in C; they stay.
- Changing C files or headers. `build/sources.list` changes (the new section), nothing under `src/*.c` or `src/**/*.h` does.
- The full-Zig build stack; Windows or non-x86_64 targets.

Anti-goals (what makes this a failure even if the gates pass):
- A native shape that changes a decision and shows up only as a rare crash under threads. Fidelity evidence outranks speed evidence throughout; the orchestration task gets the same threaded stress as Campaign 4's did.
- Tuning by superstition: a change kept because "it should be faster" with no profile line that says why, or a change claimed as a win inside the spread. The profile and the A/B conventions decide; a shape with no measurable effect is kept only on clarity grounds and said so.
- Cleanups of the C side "while here".

## 3. Constraints

- Toolchain and build: Zig 0.17.1 (`/usr/bin/zig`), the existing `zig build install --prefix <P>` (LTO, `-Doptimize=fast`, x86-64-v3, `-Dzig-impl` on), the `translate_c` package. The deprecated-API policy of Campaign 5 stays: no API the 0.17 release notes deprecate.
- The build switch (my call on the shape): `build/sources.list` gains a section `[zig-gc]` holding the ten `src/zig/gc/*.zig: src/gc/*.c` lines, moved out of `[zig]`. `zig build -Dzig-gc=false` (default true; an error with `-Dzig-impl=false`, which already builds all-C) leaves that section out: the ten C files compile, the Zig GC files are not imported (`src/zig/root.zig` gates its `gc/` imports on a `zig_options` boolean), and the root-reference check in `build/zig/zigimpl.zig` applies per section. The Perl build parses the section as part of the Zig groups (so `--zig=PATH` builds what it builds today); a Perl-side switch is not required. Exported symbol sets and `nqp::backendconfig` of a `-Dzig-gc=false` build must equal the Campaign 5 scratch-copy control's (`/tmp/claude-1000/g7-c-base`) apart from path and version.
- Fidelity: the oracle of Campaign 4 (`tools/bench/gc/oracle.sh`, the per-collection log at `-Dgc-debug=1`, tiers 1 and 2, `crc-sequential.raku` at 10 000 and 100 000, plain and `--bad-packages`) byte-identical between the C control and the native collector at every task. Every test suite the same list of names and verdicts as the C control.
- Measurement conventions as in Campaigns 4 and 5: interleaved rounds, rotated side order, medians of at least five runs per round, spreads the min and max of round medians, 1-minute load under 2.0 before every run and recorded, nothing judged from one run; the spectest recipe (`TEST_JOBS=24 python3 <MoarVM>/tools/bench/timev.py <out>.time make -o spectest_update spectest`, roast fb1d87214, `.precomp` removed before each run, order base head head base base head); records under `traces/llm/bench/ngc-*` with the header fields of the earlier records.
- Prefix names in a comparison have equal length (the install path is baked into libmoar's config strings and changes allocation sizes; Campaign 4, Task 3). The sides and their names, all under `/tmp/claude-1000/`: `ng-c-*` the C control (`-Dzig-gc=false`), `ng-f-*` the faithful port (the branch base, kept as a second control), `ng-n-*` the native collector (head); suffixes `-oracle` (`-Dgc-debug=1`), `-base` (defaults), `-stress` (`-Dgc-debug=1 -Dnursery-size=524288`). Scripts reach a prefix through `LD_LIBRARY_PATH=<P>/lib` with the rakudo and nqp of `/tmp/claude-1000/tune-zig-prefix`, as before; no per-prefix nqp or rakudo.
- Machine and process: 32 GB, no swap, no OOM daemon; everything that can grow under `systemd-run --user --scope -q -p MemoryMax=…`; kill by PID only; no git worktrees; work in the main checkout on branch `zig-native-gc` from `zig-hash-engine`; records in the `traces/llm` submodule, committed before the MoarVM pointer; no merge until the user says.
- Threads: the orchestration's atomic sites keep their C orderings (`.seq_cst` where the C uses a full barrier); a native shape may change how a site is spelled, never which operation or ordering it performs, and the site keeps its comment naming the C macro and line.

## 4. The starting point (the shape of the port, for the builder)

`src/zig/gc/`: 3,517 lines in the ten port files plus 125 in `atomic.zig`, and 1,902 lines of tests under `test/` (`zig build unit-test`, the libmoar-linked `gc-test` binary, 332/346 at debug 0 and 335/346 at debug 1 after Campaign 5; the 14 and 11 that are not passes are skips, tests that apply only at the other debug level, not failures, and the rewrite keeps them as skips). The shapes the rewrite replaces, with where they come from:

- C pointers everywhere: `const Tc = [*c]c.MVMThreadContext;` and the like, 118 `[*c]` sites, with `@ptrCast(@alignCast(…))` at every view change (collectable to object, STable or frame). The translate-c types are the only types.
- C-typed locals declared `undefined` at the top of the function (`var item_ptr: ColPtr = undefined;`), `while (true)` and `while (i < n) : (i += 1)` loops, integer flag masks (`item.*.flags2 & c.MVM_CF_SECOND_GEN != 0`), `gc_status` as a `usize` compared with integer constants.
- Zig calling Zig through C: `collect.zig` reaches the roots, gen2, worklist and object-id ports as `c.MVM_gc_root_add_frame_roots_to_worklist`, `c.MVM_gc_gen2_allocate`, `c.MVM_gc_worklist_create`, `c.MVM_gc_object_id_use_allocation`: calls through the exported C symbols, with C-ABI signatures, which the Zig compiler cannot see into (LTO may, at link time, under `.protected` visibility).
- Exports: a `comptime { @export(&f, .{ .name = "MVM_…", .visibility = … }); }` block per file; the exported functions are the implementation, with `callconv(.c)` and translate-c types in their signatures.
- Work passing with `MVM_realloc` and `MVM_calloc` on hand-rolled arrays (`WorkToPass`, `ThreadWork`, `extern struct`s that are never shared with C).
- Debug blocks: `if (comptime c.MVM_GC_DEBUG != 0)` and `if (comptime gcDebugEnabled(flags))` blocks that vanish at level 0: already the right shape, kept.
- Atomics through `atomic.zig` (`load`, `store`, `add`, `incr`, `decr`, `cas`, `fence` over `*usize`, `*u32` and pointer slots; `fence` is inline-asm `mfence`, Zig having no `@fence`); `moar.trycas` for `MVM_trycas`. 118 atomic sites in `orchestrate.zig` alone, each commented with the C line.
- `MVMDebugServerData` mirrored as an `extern struct` because translate-c leaves bit-fields opaque; its size and the touched offsets probed against the C compiler (`src/zig/test/layout_probe.c`).
- The inline fast paths in the C headers call the Zig slow paths (`MVM_gc_allocate_nursery`, `MVM_gc_worklist_add_slow`, `MVM_gc_write_barrier_hit`, `MVM_gc_root_temp_push_slow`); the Zig allocators call the translated inline `MVM_gc_allocate_zeroed`, which inlines.

What the profile (section 7) must settle before the shapes are chosen: whether the gap is inside the collector's own functions at all, and if so in which; the candidates from the shapes above are the C-ABI boundaries between Zig files (b of section 8) and the pointer and flag code (a and c), and the alternative is that the gap lives in the C callers of the GC fast paths (code layout, LTO inlining decisions at the `.protected` exports) rather than in the collector, which no rewrite of the collector would change.

## 5. Fidelity oracle (the decisive evidence, unchanged in mechanism)

As Campaign 4, section 5, as built (that spec's Errata): the per-collection log written by `debug.zig`/`debug.c` at `-Dgc-debug=1` into `$MVM_GC_LOG`, tier 1 (release-equivalent, the `full` and `gen2_freed` columns dropped) and tier 2 (`MVM_GC_DEBUG_RSS=104857600` pins the full-collection decision), `crc-sequential.raku` with `MVM_SPESH_DISABLE=1` and `RAKUDO_NO_PRECOMPILATION=1`, three runs per side to show repeatability. Groups, every task that changes a GC file, at 10 000 and 100 000, plain and `--bad-packages`, tiers 1 and 2 (16 cells per group):

- (a) `ng-c-oracle` against `ng-n-oracle`: the C control against the native collector. The fidelity claim.
- (b) `ng-f-oracle` against `ng-n-oracle`: the faithful port against the native one. Redundant with (a) if (c) holds; it localises a difference to the rewrite when (a) fails.
- (c) `ng-c-oracle` against `ng-f-oracle`: run once at Task 1 and once at acceptance; shows the controls themselves did not drift.

Pass rule as before: identical logs per tier in every cell; any difference is a fidelity failure, not a tuning question, and the task does not complete until the log matches. The oracle's workload has one collecting thread, so the threaded paths (work passing, in-trays, stealing, suspend and resume, global destruction) are covered by section 9's stress and full-cleanup runs instead.

Equal-length names let (a) compare logs byte for byte before any filtering, as Campaign 4 did.

## 6. Performance and memory gate

Proving ground as before: `tools/bench/gc/crc-getter.raku` at volume 100 000 (the user capped it there on 2026-11-08), `--runs=5`, plain and `--bad-packages`, through `tools/bench/gc/ab.sh --rounds=7 --runs=5 --volume=100000`, wall and peak RSS by `timev.py`.

- The gate (stop and report): at any task, a crc-getter wall or RSS ratio native/C above the faithful port's ratio by more than the C control's spread, or a spectest regression, stops the task; the controller rules on reverting the shape or redesigning it. The faithful port's ratio is a fixed baseline: `ng-f-base` against `ng-c-base` measured once at Task 1 (seven rounds, plain setting) and not re-measured per task, so three sides never run in a tripwire and small regressions cannot accumulate past one spread above the faithful port's number. This is a tripwire against a rewrite that costs; it does not demand a gain per task.
- The aim (reported at acceptance, not gated): native/C within the C control's spread or at most 1.00 on both measures, both settings; the campaign started at 1.022/0.994 (plain wall/RSS) and 1.027/1.001 (`--bad-packages`) on Zig 0.17 (`../bench/z017-crc-ab.md`).
- Three-sided A/B at acceptance: C control, faithful port and native collector in one interleaved run per setting (`ab.sh` gains a third side, or two pairs with the C control shared, builder's call), so the faithful port's number is measured on the same day as the native one and the gain is read off two ratios that share a base.
- Per-task tripwire: a shorter A/B, three rounds of five runs, native against the C control, plain setting only; the seven-round, both-setting A/B at acceptance is the number.
- Spectest: the standard A/B, C control against native, as the primary gate: wall and RSS within spread or 1 percent, zero new failures (an intermittent known from earlier records is re-run, as Campaign 5 did).

## 7. Profile protocol (the evidence the shapes aim at)

Taken at Task 2 on the C control and the faithful port, repeated at acceptance on the C control and the native collector; recorded in `traces/llm/bench/ngc-profile.md` with raw data beside it.

- Builds: the three `-base` prefixes rebuilt once with `-Dstrip=false` into equal-length sibling names (`ng-c-syms`, `ng-f-syms`, `ng-n-syms`), everything else at the defaults, so the profiled binary is the shipped code with symbols. The record proves the `.text` of a `-syms` build equals its stripped sibling's (`objcopy --dump-section .text` or `readelf` sizes; builder's call) before any profile is read; if they differ, the `-syms` builds are profiled anyway, the difference is recorded, and a three-round crc-getter A/B of `-syms` against stripped shows the two perform within spread, else the profile is labelled as taken on a different binary.
- Counters: `perf stat -e cycles:u,instructions:u,branch-misses:u,cache-misses:u,L1-dcache-load-misses:u` over the crc-getter run at 100 000, both settings, five runs per side, medians; the machine's `perf_event_paranoid` is 2, which permits user-space counters of one's own processes and nothing else, so every event carries `:u`.
- Samples: `perf record -e cycles:u -F 4000` (no call graph by default; the shipped build has no frame pointers, and `--call-graph dwarf` on a 300 MB process is the builder's call if a flat profile does not answer the question), `perf report --sort dso,symbol` with libmoar's symbols; the record lists the top 40 symbols per side with their cycle shares, the GC's total share (every `MVM_gc_*` export plus the Zig-internal functions, which have symbols in the `-syms` build and appear as their Zig names), and the per-symbol delta between sides, aligned by the C symbol name where the Zig function is exported and by the C function it ports otherwise.
- One more pass with `-Dlto=false` on both sides, labelled as such: inlining under LTO folds callees into callers and hides where the time went; the non-LTO profile attributes it, at the price of being a different binary. Conclusions drawn from it are marked as attribution only.
- The record ends with a one-paragraph finding: the share of the gap that lies in the collector's functions, the functions it lies in, and which shapes of section 8 the finding points at. Task 3 onwards cites it. The share is computed on `cycles:u`, not wall: collector share = (collector cycles on the faithful side minus collector cycles on the C side) divided by (total cycles faithful minus total cycles C), both medians of the five `perf stat` runs, where "collector cycles" is the sum over the `MVM_gc_*` exports and the Zig-internal functions in the sampled profile scaled to the run's total. If the total-cycle difference between the sides is smaller than either side's run-to-run spread, the gap is unresolvable at this size: the finding says so, the stop rule of section 11 does not fire, and the campaign continues on clarity grounds with the performance aim recorded as not resolvable at volume 100 000.

## 8. The native shapes (the catalogue; each applied only where it leaves decisions unchanged)

The rule of Campaign 4, section 8, stays: a Zig feature is used when it makes the code clearer, safer or cheaper to verify, and not when it changes a decision, a layout, an ordering or the release code path. New in this campaign: the shape is the point, so each file task applies the catalogue throughout its file, not only where it is cheap; and the profile says which items carry the performance aim.

- a. Typed pointers. `*c.MVMThreadContext`, `*c.MVMCollectable`, `*c.MVMGCWorklist` and `?*T` where the C can hold NULL, in place of `[*c]T`; the view changes (collectable as object, STable or frame) go through a handful of named accessors in one place (`src/zig/gc/view.zig`, my call on the name; `asObject`, `asStable`, `asFrame`, `header`), each a one-line `@ptrCast(@alignCast(…))` with the flag check that justifies the view at debug level 1 and up. `[*c]` survives only at the C ABI (export wrappers, callbacks the C calls, fields of C structs).
- b. Zig calling Zig. The ported functions get Zig-typed signatures (`fn allocate(al: *Gen2, size: u32) *anyopaque`) and the `MVM_…` exports become thin `callconv(.c)` wrappers over them, in the same file; `collect.zig` imports `roots.zig`, `gen2.zig`, `worklist.zig` and `objectid.zig` and calls them as Zig, so the compiler sees the bodies regardless of LTO. The exports stay for the C callers, with the `.protected` visibility rule under `-Dlto`.
- c. Flags as packed structs. `packed struct(u8)` views of `flags1` and `flags2` (`Flags1 { type_object: bool, stable: bool, frame: bool, has_object_id: bool, … }`), with a `comptime` block asserting that each field's bit equals its `MVM_CF_*` constant, so a header change fails the build; reads as `col.flags2.second_gen`, writes through the same view. The byte layout is the C's.
- d. GC status as a typed value. `gc_status` viewed as `packed struct(usize) { status: enum(u2) { none, interrupt, unable, stolen }, suspend: enum(u2) { none, request = 1, suspended = 3 }, _: u60 }` or an equivalent (`MVMGCStatus_*` 0-3, `MVMSuspendState_*` 0, 4, 12, `MVMSUSPENDSTATUS_MASK` 12, `src/core/threadcontext.h`), asserted at comptime against the C constants; `atomic.zig` gains typed `load`/`store`/`cas` over it so the 118 sites read as states, not numbers, and the orderings stay `.seq_cst`.
- e. Slices and ranges. The worklist as `list[0..items]`, the nursery scans (`freeNurseryUncopied`) as a cursor over `fromspace[0..used]`, gen2 as `size_classes[0..MVM_GEN2_BINS]` and `pages[0..num_pages]`, the overflow list as a slice; indices and lengths keep the C's widths (`u32`) where a C struct field holds them.
- f. Zig control flow. Locals initialised at declaration and `const` where unchanged; `for (0..n) |i|` and `for (slice) |x|`; early returns and labelled blocks in place of flag variables; `switch` on the collectable kind (type object, STable, frame, object) where the C tests the flags in sequence, with the C's precedence preserved exactly (a type object is tested before an STable, and so on).
- g. Comptime tables. The instance-root and thread-root walks (`roots.zig`: 40 instance roots with their description strings, then the thread roots) as comptime arrays of `(field path, description)` iterated with `inline for`, in the C's order, which the oracle makes load-bearing (the worklist order decides the copy order and so every address); the gen2 bin geometry as comptime constants asserted against the C header (Campaign 4 did this); the debug-level and debug-flag gates as they are.
- h. Work passing in Zig. `WorkToPass`/`ThreadWork` as plain Zig structs with an `std.ArrayListUnmanaged(ThreadWork)` over `moar.mvm_allocator` in place of the hand-rolled array, grown with `ensureTotalCapacityPrecise` one entry at a time so the `MVM_malloc`/`MVM_realloc` size sequence stays the C's; the oracle's single-threaded log cannot see this path, so the task that does it also shows peak RSS within spread on the full crc-getter program (its supplies, `react` and `start` blocks run on the thread pool, so the path is reached) and on the three-thread full-cleanup program of section 9. Any other change to an `MVM_malloc` size sequence needs a ledger ruling and the same evidence.
- i. Errors and panics. `MVM_panic`/`MVM_oops` stay calls into C; no error unions on the collector's paths.
- j. Tests. The unit tests are rewritten with their files (typed APIs make most of the `[*c]` scaffolding in `test/` go away); every behaviour a Campaign 4 test pins keeps a test, and the per-root pass counts do not decrease. `std.testing.allocator` for the pure parts, the VM-booting tests as they are.
- Not used: `std.mem.Allocator` over the GC heap (ruled out in 2026-11-02); `std.Thread` or `std.atomic.Value` over the VM's own structures (the fields are C fields; the builtins over them stay); any change to `MVMThreadContext`, `MVMGen2Allocator`, `MVMGCWorklist` or `MVMCollectable`.

## 9. Testing and stress configuration

- Zig unit tests per file (`zig build unit-test`, both debug levels), `zig fmt --check`, `zig build test` after every file task.
- The oracle groups of section 5 at every file task.
- The per-task tripwire A/B of section 6.
- nqp `make test` and rakudo `make test` under `ng-c-base` and `ng-n-base`, and under `ng-c-stress` and `ng-n-stress` (nursery 512 KiB, debug level 1), at Task 1 (controls), after the collect and orchestrate tasks, and at acceptance; per-file lists identical to the C control's.
- Threaded evidence for the orchestration task and at acceptance: the full crc-getter program under both stress prefixes; and the three full-cleanup programs of the Campaign 4 interlude (a thread allocating in a loop while the main thread returns; a thread blocked in `nqp::sleep`; three threads), which live only in `.superpowers/sdd/2026-11-04-zig-gc-port/interlude-pr.md` today and are added to `tools/bench/gc/` by Task 1, run 20 times each per side with `--full-cleanup` on the `-base` and `-stress` prefixes: every run exits 0 and prints its final line (Campaign 4's mirror: 480 of 480).
- The spectest A/B of section 6 at acceptance.

## 10. Task ladder

1. Campaign setup and the build switch: branch; the `[zig-gc]` section, `-Dzig-gc`, the `root.zig` gate, the per-section root check, Perl-path parity, docs; the three control prefixes `ng-c-*` from the tree and the three `ng-f-*` from the branch base; proof that `ng-c-*` equals the Campaign 5 scratch control (exports, backendconfig, `MVM_gc_*` symbol sizes) against `/tmp/claude-1000/g7-c-base` while it exists, else against the committed record (`../bench/z017-prefixes.md` and `z017-prefixes-raw/`: the export counts, the backendconfig dumps and the symbol sizes); oracle group (c); suites under both controls; the full-cleanup programs added to `tools/bench/gc/` and run once per side.
2. Profile (section 7): the `-syms` builds, counters, samples, the non-LTO attribution pass, the finding.
3. Foundations: `view.zig` (typed pointers, accessors, flag views, the status type), typed `atomic.zig`, the Zig-signature-plus-export-wrapper pattern, applied to `worklist.zig` and `allocation.zig` as the template the later tasks follow. Oracle, tripwire.
4. `gen2.zig`.
5. `roots.zig` (comptime root tables; order preserved).
6. `collect.zig` (direct Zig calls into roots, gen2, worklist, objectid; slices; flag views; kind switch).
7. `wb.zig`, `objectid.zig`, `finalize.zig`, `debug.zig` (one task; the log writer's bytes identical).
8. `orchestrate.zig` (the status type at every site, with the C line comments kept; work passing in Zig; the threaded evidence of section 9).
9. Acceptance: oracle groups (a), (b) and (c); the three-sided crc-getter A/B; the spectest A/B; suites; the after-profile and its comparison with the before-profile; the full-cleanup runs; docs (`docs/zig-build.md` "## Garbage collector": the switch, the shapes, the view module); this spec's errata; the plan's Outcome table; the reading notes collected from the task reports into `traces/llm/bench/ngc-reading-notes.md`.

Each file task: rewrite, tests, `zig build test`, the oracle groups (a) and (b), the tripwire A/B, a "reading notes" paragraph in the report, commit. The branch base's faithful port stays buildable only as the `ng-f-*` prefixes (built at Task 1 from the base commit), not from the tree; there is no per-file selectability between faithful and native.

## 11. Risks the builder should plan around

- The gap may not be in the collector. If Task 2's profile puts most of the native/C difference outside the `MVM_gc_*` functions and the Zig internals, the performance aim is out of this campaign's reach and the spec says so now: the rewrite proceeds on clarity grounds, the acceptance reports the ratio, and the finding names where the gap is for a later campaign. The user decides at that point whether to continue; the controller stops and reports after Task 2 if the finding says the collector holds less than a quarter of the gap.
- Noise floor. The per-task tripwire has spreads of about 1 percent; a single shape rarely moves the median outside them. Tasks report their ratio with the spread and claim nothing inside it; the acceptance's seven-round, three-sided A/B is the number.
- Zig-to-Zig calls change inlining and code layout; a step can move the ratio either way for reasons unrelated to the shape. The profile's per-symbol view at acceptance is what attributes it.
- Typed views of C fields must not change access width or atomicity: a `packed struct(u8)` read of `flags2` is one byte load, as before; the status view is one word; the task review checks the generated access is the same shape (`objdump -d` of the function if in doubt).
- The roots order and the description strings are load-bearing (oracle and heap snapshots); the comptime tables are checked by a test that walks the instance roots and compares the strings and their order against a golden list checked into the test and taken from `src/gc/roots.c` at authoring time (the way Campaign 4's `roots_test.zig` pins the C order today), not by a cross-binary comparison: one binary holds one collector. `zig build unit-test -Dzig-gc=false` builds and runs the non-GC test roots and leaves `gc-test` out; it is not required to test the C collector.
- The orchestration task is the hardest again; it gets its own review focus, the threaded stress and full-cleanup runs, and a reviewer mapping each of the 118 atomic sites from the faithful file to the native one.
- `-Dzig-gc=false` and `-Dzig-impl=false` must not be confused in records; every record names the option used and the prefix's exported-symbol count (2850 with the Zig hash engine, 2820 all-C, at Campaign 5's commit).

## 12. Left to the builder

- The exact `[zig-gc]` syntax and how the Perl build's parser (`build/setup.pm`, `Configure.pl`) learns the section while keeping `--zig=PATH` behaviour identical.
- The file split: whether the accessors, flag views and status type live in one `view.zig` or beside the structures they view; the test layout.
- The perf flags beyond those named, the `.text` equality method, and whether the non-LTO attribution pass is needed after the LTO profile.
- Whether `ab.sh` grows a third side or runs two pairs with the shared C control.
- The order within Task 7, and which of the catalogue's items each file task applies first.

## 13. Decisions recorded (the user's, verbatim in spirit) and my calls

The user's:
- Campaign 4's open row accepted as transitional; the theory that Zig-native shapes recover the cost is what this campaign tests.
- Migration to 0.17 first, then this campaign (done 2026-11-09).
- Brainstorm questions skipped ("let's skip questions this time").
- The crc-getter proving ground stays capped at 100 000; the spectest is the primary gate (rulings of 2026-11-08).

My calls (to overrule while reading):
- The switch is `-Dzig-gc` over a `[zig-gc]` section, honoured by both builds; the Perl path needs no flag.
- Three sides, with the faithful port kept as a control, measured on the same day as the native collector.
- A profile task before any shape changes, and a stop-and-report after it if the collector holds less than a quarter of the gap.
- The performance aim is reported, not gated; the gate is "no worse than the faithful port beyond spread" per task and the spectest at the end.
- The inline C fast paths stay in C; the derived `gc_mark` is the next campaign.
- The three full-cleanup programs move from the interlude's PR text into `tools/bench/gc/`.
- Reading notes as a deliverable.

## Errata (as built, recorded at acceptance 2026-11-10)

What the tasks found or changed against the text above; the text is left as approved.

- Section 5: "16 cells per group" -> 8 cells per group (2 volumes x 2 settings x 2 tiers), 24 cells over three groups (48 compared logs, one per side per cell; the acceptance brief's "48 cells" counted logs).
- Section 3 Threads / plan Atomics constraint: the fence shape (R5), user-approved 2026-11-10.
- Section 8 d: the status type lives in atomic.zig, re-exported by view.zig; field `suspend_state`; `Suspend` non-exhaustive.
- Section 8 g: 22 instance-root description sites (18 table entries), not 40; tables joined from segments.
- Section 8 h: the allocator needed a `remap` over MVM_realloc for the size AND operation sequence to be the C's.
- Section 11: "118 atomic sites" in orchestrate -> 68.
- Section 7: the `.text` equality check fails by construction for `-Dstrip=false` builds (std.debug code), so the fallback A/B is always needed.
- Section 13, "The inline C fast paths stay in C": they stay for the C callers, but the collector's own Zig callers got Zig copies that inline: the temp-root push and pop (`moar.root`/`TempRoot`, Rulings R6/R1, Task 3) and `MVM_gc_write_barrier_no_update_referenced` (`wb.noUpdateReferenced`, Ruling R11, Task 7). Added by Task 9 from the plan deviations.
