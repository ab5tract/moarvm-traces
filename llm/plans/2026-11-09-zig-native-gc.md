# Zig-native Garbage Collector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** executed 2026-11-09/10 on branch zig-native-gc; acceptance records traces/llm/bench/ngc-*; awaiting the whole-branch review and the user's merge decision

**Final review:** final review 2026-11-10 (fable): 0 Critical, 1 Important (fixed: NULL slice in finalize.zig/debug.zig on safety-checked builds), 13 Minor (fixed or deferred per the ledger); verdict "with fixes", fixes applied in MoarVM 071571830.

**Goal:** Rewrite the faithful Zig port of `src/gc/` into native Zig shapes while the collector's decisions stay byte-identical to the C collector's, with a build switch for the C-collector control, a profile before and after, and the performance aim (crc-getter native/C at or under 1.00) reported honestly.

**Architecture:** Task 1 adds the `[zig-gc]` section and `-Dzig-gc` so the control "C collector + Zig hash engine" is built from the tree, then freezes three prefix sets (C control, faithful port, native head). Task 2 profiles the C control against the faithful port and says where the gap is. Tasks 3-8 rewrite the ten files behind a new `view.zig` (typed pointers, flag and status views) with Zig-typed internals and thin C-ABI export wrappers, one file per task, each gated by the oracle and a short A/B. Task 9 is acceptance: oracle matrix, three-sided A/B, spectest, after-profile, docs, reading notes.

**Tech Stack:** Zig 0.17.1 (`/usr/bin/zig`), the `translate_c` package, perf 7.2 (`perf_event_paranoid` 2, user-space events only), the existing runners under `tools/bench/gc/` (`oracle.sh`, `ab.sh`, `crc-getter.raku`, `crc-sequential.raku`), `tools/bench/timev.py`, Perl for `Configure.pl`.

**Spec:** `traces/llm/specs/2026-11-09-zig-native-gc-design.md` (section numbers below refer to it). The Campaign 4 spec and plan (`2026-11-04-zig-gc-port-design.md`, `../plans/2026-11-04-zig-gc-port.md`) describe the port this plan rewrites; the Campaign 5 records (`../bench/z017-*`) are the starting numbers.

## Global Constraints

- Branch `zig-native-gc` from `zig-hash-engine` (1d53c28e0 or later), in the main checkout. **No git worktrees.** Address every repository with `git -C <absolute path>`; never rely on `cd` carrying between commands. Records go in the `traces/llm` submodule under `bench/ngc-*`; commit there first, then the pointer commit in MoarVM. Never add `.superpowers/` or `tools/lib/MAST/Ops.rakumod`.
- **No decision change.** No file under `src/*.c` or `src/**/*.h` changes. `build/sources.list` changes only by moving the ten GC lines into `[zig-gc]`. The oracle (spec 5) is byte-identical in every cell of groups (a) and (b) at every file task. Every test suite produces the same list of names and verdicts as the C control.
- **Prefixes** (all under `/tmp/claude-1000/`, equal-length names within a comparison): `ng-c-oracle`, `ng-c-base`, `ng-c-stress` (C control, `-Dzig-gc=false`); `ng-f-oracle`, `ng-f-base`, `ng-f-stress` (faithful port, built once at Task 1 and never rebuilt); `ng-n-oracle`, `ng-n-base`, `ng-n-stress` (native head, rebuilt by each file task). `-oracle` is `-Dgc-debug=1`, `-base` defaults, `-stress` `-Dgc-debug=1 -Dnursery-size=524288`. Profile builds: `ng-c-syms`, `ng-f-syms`, `ng-n-syms` (`-Dstrip=false`) and `ng-c-nlto`, `ng-f-nlto`, `ng-n-nlto` (`-Dlto=false -Dstrip=false`). Scripts reach a prefix through `LD_LIBRARY_PATH=<P>/lib` with the rakudo and nqp of `/tmp/claude-1000/tune-zig-prefix`.
- **Builds:** `rm -f src/gen/config.h src/gen/config.c src/gen/config.o` before any `zig build` without `-Dconfig-h`; 1-minute load under 2.0 before every build, test run or benchmark round (poll every 60 s; record the value); anything that can grow under `systemd-run --user --scope -q -p MemoryMax=8G <cmd>` (24G for the spectest); kill by PID only, never `pkill -f`/`pgrep -f`.
- **Measurement:** interleaved rounds, rotated side order, medians of at least five runs per round, spreads the min and max of round medians, load recorded before every run, nothing judged from one run. Per-task tripwire: `tools/bench/gc/ab.sh --rounds=3 --runs=5 --volume=100000` plain, `ng-n-base` against `ng-c-base`. Acceptance: `--rounds=7 --runs=5`, both settings, three sides. Spectest: `TEST_JOBS=24 python3 <MoarVM>/tools/bench/timev.py <out>.time make -o spectest_update spectest` in the rakudo checkout, roast fb1d87214, `.precomp` removed before each run, order base head head base base head, MemoryMax=24G.
- **Gate (spec 6):** a task stops and reports when its tripwire wall or RSS ratio exceeds the fixed baseline ratio of `ng-f-base`/`ng-c-base` (Task 1, `ngc-baseline-crc.md`) by more than the C control's spread (max minus min of its round medians, divided by its median), or when any oracle cell differs, or when a suite's list changes.
- **Deprecated-API policy** (Campaign 5): no API the Zig 0.17 release notes deprecate; `zig fmt --check src/zig build.zig build/zig tools/zig` clean after every task; `perl -c` on touched Perl, `sh -n` on touched shell; test output pristine.
- **Atomics:** every site keeps its C macro-and-line comment; the operation and `.seq_cst` ordering are unchanged; `atomic.fence()` stays as it is (Zig 0.17 has no `@fence`).
- **Exports:** the exported symbol set of `ng-n-base`'s libmoar equals `ng-c-base`'s (2850 names at Campaign 5's commit) at every task; export wrappers keep `callconv(.c)`, the translate-c types in their signatures, and `.protected` visibility under `-Dlto`.
- **Reports:** every file task's report has a "## Reading notes" section (spec 1: what the native reading made visible), collected by Task 9.
- Commit messages: imperative subject, body with the reasoning, then the two attribution lines exactly as the dispatching session gives them.

## Rulings made while planning

- `ab.sh` grows an optional third side (`--head2=LIBDIR`) rather than running two pairs: the three sides rotate within one round so they share the day, the load and the warm caches. Its `summary.md` adds `head2/base` ratios; the two-sided form is unchanged.
- `ng-f-*` are built at Task 1's commit (the switch does not touch the Zig GC files, so Task 1's tree is the faithful port) and frozen; no copy of an older tree is needed.
- A `-Dzig-gc` given explicitly with `-Dzig-impl=false` is a fatal configure error; `-Dzig-gc=false` with `-Dzig-impl=true` is the control; `-Dzig-impl=false` alone stays all-C.
- `view.zig` holds the typed pointer aliases, the flag views, the status type and the view-change accessors; `atomic.zig` gains the typed status operations. Both are plain modules under `src/zig/gc/` imported by the ports and the tests; neither exports anything.
- The faithful tests under `src/zig/gc/test/` are rewritten with their files; a test may be renamed when its subject is renamed, and the per-root pass counts of `gc-test` (49 and 52 at Campaign 5's commit, debug 0 and 1) do not decrease.

## Review Focus

1. A build with `-Dzig-gc=false -Dzig-impl=false` or `-Dzig-gc=true -Dzig-impl=false`: a person expects a clear error, not an all-C build that silently ignores the flag. Pinned by Task 1's options test.
2. A C header changes a `MVM_CF_*` bit or a `MVMGCStatus_*` value: a person expects the build to fail, not the collector to read the wrong bit. Pinned by Task 3's comptime assertions (one per constant) and its round-trip test.
3. The typed compare-and-swap on `gc_status` must return the previous value and fail on a mismatch exactly as `atomic.cas` does, or the orchestration's election changes. Pinned by Task 3's `atomic_test.zig` addition.
4. Direct Zig-to-Zig calls must not remove an export a C caller needs: a person building `-Dzig-gc=false` and `=true` expects the same dynamic symbol table. Pinned by the export-set check of every file task.
5. The instance-root walk order and its 40 description strings are load-bearing (oracle and heap snapshots): a comptime table that reorders one entry changes every address. Pinned by Task 5's golden-order test.

---

### Task 1: Build switch, controls, baseline

**Files:**
- Modify: `build/sources.list` (move the ten `src/zig/gc/*.zig: src/gc/*.c` lines into a new `[zig-gc]` section after `[zig]`), `build/zig/sources.zig`, `build/zig/options.zig`, `build/zig/zigimpl.zig`, `build.zig:33-39,145-160`, `src/zig/root.zig`, `Configure.pl:1129-1182` (`read_sources_list`), `docs/zig-build.md` (options table; "## Garbage collector" first paragraph), `tools/bench/gc/README.md`
- Create: `tools/bench/gc/cleanup/running.nqp`, `tools/bench/gc/cleanup/blocked.nqp`, `tools/bench/gc/cleanup/three.nqp` (verbatim from `.superpowers/sdd/2026-11-04-zig-gc-port/interlude-pr.md` lines 114-185), `tools/bench/gc/cleanup.sh`
- Records (traces `llm/bench/`): `ngc-prefixes.md` (+ `ngc-prefixes-raw/`), `ngc-oracle-c.md` (group (c)), `ngc-baseline-crc.md` (+ raw dir), `ngc-suites.md` (+ raw), `ngc-cleanup.md`, drivers `ngc-oracle-driver.sh`, `ngc-maketest-driver.sh` (copied from the `z017-*` drivers and re-pointed)

**Interfaces:**
- Produces: `sources.Lists.zig_gc: []const ZigEntry`; `sources.applyZig(allocator, lists, zig_gc: bool) Error!Lists` (when `zig_gc` is false the `[zig-gc]` entries are neither applied nor returned); `Options.zig_gc: bool`; `zigimpl.checkRootImports(b, lists, zig_gc: bool)`; the `zig_options` module gains `zig_gc: bool`; `src/zig/root.zig` imports the `gc/` files inside `if (@import("zig_options").zig_gc) { … }`; `tools/bench/gc/cleanup.sh --prefix=P --runs=N [--stress]` exits 0 when every run of the three programs exits 0 and prints `main returning`.

- [ ] **Step 1: Failing tests for the parser and the options**

In `build/zig/sources.zig` add tests: `"parse: [zig-gc] lines are ZigEntry and separate from [zig]"` (a `[zig]` line and a `[zig-gc]` line; expect `lists.zig.len == 1`, `lists.zig_gc.len == 1`), `"applyZig without gc keeps the gc C files"` (`applyZig(a, lists, false)` leaves `src/gc/x.c` in `core` and returns `zig_gc.len == 0`; with `true` removes it), `"validate: a C file replaced in both sections is ZigReplacesTwice"`. In `build/zig/options.zig` add `"zig-gc needs zig-impl"`: a pure helper `zigGc(zig_impl: bool, given: ?bool) error{ZigGcNeedsZigImpl}!bool` returns `given orelse true` when `zig_impl`, and the error when `!zig_impl and given != null`, `false` when `!zig_impl and given == null`.

- [ ] **Step 2: Run them to see them fail**

Run: `zig build unit-test 2>&1 | tail -20`. Expected: the new tests fail to compile (`zig_gc` unknown), the rest untouched.

- [ ] **Step 3: Implement the parser, the option, the root check, the gate**

`sources.zig`: `Section` gains `.zig_gc` (`"zig-gc"`); `parse` routes its lines through `parseZigLine` into `zig_gc`; `validateZig` checks both lists together (the twice-check spans them); `applyZig` takes `zig_gc: bool`. `options.zig`: field `zig_gc`, option `"zig-gc"` with help `"Build the Zig garbage collector from the [zig-gc] section of build/sources.list (default true); false keeps src/gc in C while the other Zig implementations stay Zig: the control of every GC comparison. Needs -Dzig-impl=true"`, resolved through `zigGc` (fatal on the error with that message). `zigimpl.zig`: `zig_opts.addOption(bool, "zig_gc", opts.zig_gc)`; `checkRootImports` checks `lists.zig_gc` too when `zig_gc`. `build.zig`: pass `opts.zig_gc` to `applyZig` and `checkRootImports`; register the `gc-test` root only when `opts.zig_gc`. `root.zig`: the gate. `Configure.pl` `read_sources_list`: treat `zig-gc` as `zig` (same line grammar, same `@zig` list, deleted from `%sections`, excluded from `%known`'s check). `build/sources.list`: the move, with a comment naming `-Dzig-gc`.

- [ ] **Step 4: Run the tests and the three build shapes**

Run: `zig build unit-test` (pass; the gc-test counts unchanged: 49 at debug 0), `zig build unit-test -Dgc-debug=1` (52), `zig build unit-test -Dzig-gc=false` (passes without a gc-test binary; say so in the report), `zig build -Dzig-gc=true -Dzig-impl=false 2>&1 | head -3` (the fatal message), `zig build test` (105/105 as Campaign 5), `zig build test -Dzig-gc=false` (passes; record the step count), `perl -c Configure.pl`, `perl Configure.pl --zig=/usr/bin/zig --prefix=/tmp/claude-1000/ngc/perl && make -j24 install` then the nqp smoke (`<P>/bin/moar --libpath=/tmp/claude-1000/tune-zig-prefix/share/nqp/lib /tmp/claude-1000/tune-zig-prefix/share/nqp/lib/nqp.moarvm -e 'say(6*7)'` prints 42), `make realclean`, delete the prefix, `git status --short` shows only the two known untracked items.

- [ ] **Step 5: The full-cleanup programs and their runner**

Copy the three programs from the interlude PR text into `tools/bench/gc/cleanup/`; write `cleanup.sh` (`sh -n` clean; `--help` exits 0; exits 64 on misuse): for each program, `--runs` times, `timeout 60 <P>/bin/moar --full-cleanup --libpath=<nqp lib> <nqp lib>/nqp.moarvm <prog>` with `<nqp lib>` = `/tmp/claude-1000/tune-zig-prefix/share/nqp/lib` (override `--nqp-lib=`), under `systemd-run … MemoryMax=8G`; a table of exit codes and whether the last line is `main returning`; exit 0 only if every run passes. README row for the directory and the script.

- [ ] **Step 6: Commit the switch**

```bash
git -C <MoarVM> add build/sources.list build/zig/sources.zig build/zig/options.zig build/zig/zigimpl.zig build.zig src/zig/root.zig Configure.pl docs/zig-build.md tools/bench/gc/README.md tools/bench/gc/cleanup tools/bench/gc/cleanup.sh
git -C <MoarVM> commit -m "Build: -Dzig-gc, the C-collector control from the tree"
```

- [ ] **Step 7: Build the nine prefixes**

From this commit: `ng-c-*` with `-Dzig-gc=false`, `ng-f-*` and `ng-n-*` at the defaults (the three `ng-n-*` are identical to `ng-f-*` now and are what the file tasks rebuild), each with its suffix's options. Record load, exit, seconds. Prove `ng-c-base` against `/tmp/claude-1000/g7-c-base` (if present, else against `../bench/z017-prefixes-raw/`): `nm -D --defined-only <P>/lib/libmoar.so | awk '{print $3}' | sort` identical; `nqp::backendconfig` dump differs only in path and version keys of equal length; `nm -S` sizes of `MVM_gc_collect`, `MVM_gc_enter_from_allocator`, `MVM_gc_root_add_permanent_desc` equal. Every version line 68 characters; nqp smoke 42 on each.

- [ ] **Step 8: Oracle group (c), suites, full-cleanup, baseline**

`ngc-oracle-driver.sh` (from `z017-oracle-matrix-driver.sh`: groups a, b, c over `ng-c`/`ng-f`/`ng-n`, volumes 10000 and 100000, plain and `--bad-packages`, tiers 1 and 2): run group (c) only, 8 cells, all exit 0, raw logs byte-identical. `ngc-maketest-driver.sh`: nqp `make test` under `ng-c-stress` and `ng-f-stress`, rakudo `make test` under `ng-f-base` and `ng-c-base`; per-file lists identical to `../bench/z017-suites-raw/`. `cleanup.sh --runs=20` on `ng-c-base`, `ng-f-base`, `ng-c-stress`, `ng-f-stress`: 240 of 240. Baseline: `ab.sh --base=/tmp/claude-1000/ng-c-base/lib --head=/tmp/claude-1000/ng-f-base/lib --rounds=7 --runs=5 --volume=100000 --out=…` plain (and once with `--bad-packages`); `ngc-baseline-crc.md` states the wall and RSS ratios, the C spread as a fraction of its median, and the resulting stop thresholds for the tripwire in one line each.

- [ ] **Step 9: Commit records and pointer**

traces `"ngc: controls, baseline, group (c)"`; MoarVM `"traces: ngc controls"`.

---

### Task 2: Profile

**Files:**
- Create: `tools/bench/gc/profile.sh`
- Records: `ngc-profile.md`, `ngc-profile-raw/` (perf stat outputs, `perf report` text, the `.text` comparison)

**Interfaces:**
- Consumes: the `-base` prefixes of Task 1.
- Produces: `profile.sh --lib=LIBDIR --out=DIR [--bad-packages] [--stat-runs=5] [--record]`: `perf stat -e cycles:u,instructions:u,branch-misses:u,cache-misses:u,L1-dcache-load-misses:u -x,` per run of `crc-getter.raku --volume=100000 --runs=5` (load under 2.0 before each, one warm-up at `--volume=1`), medians in `stat.tsv`; with `--record`, one `perf record -e cycles:u -F 4000 -o DIR/perf.data` run and `perf report -i … --sort dso,symbol --stdio -n > report.txt`. The record's finding paragraph (spec 7) and the collector share computed as spec 7 defines.

- [ ] **Step 1: The symbol builds and their `.text`**

Build `ng-c-syms`, `ng-f-syms` (`-Dstrip=false`, else defaults) and `ng-c-nlto`, `ng-f-nlto` (`-Dlto=false -Dstrip=false`). For each `-syms` build: `objcopy -O binary --only-section=.text <P>/lib/libmoar.so /tmp/claude-1000/ngc/<P>.text` and `cmp` against the matching `-base` prefix's; record identical or not (spec 7's fallback if not).

- [ ] **Step 2: Write and smoke the script**

`sh -n`; `--help`; a `--stat-runs=1` smoke on `ng-c-syms`.

- [ ] **Step 3: Counters and samples, both sides, both settings**

`profile.sh` on `ng-c-syms` and `ng-f-syms`, plain and `--bad-packages`, `--stat-runs=5 --record`; then on the `-nlto` pair, plain only, `--record` (attribution pass). Interleave the sides (c, f, f, c, c, f per setting) by invoking the script per run order; the script itself runs one side.

- [ ] **Step 4: The record**

`ngc-profile.md`: the header fields; the stat medians per side and setting with the f/c ratios; the top-40 symbols per side from the LTO profile with cycle shares; the aligned delta table (C name against Zig name); the collector share per spec 7 (cycles, medians, the unresolvable rule); the non-LTO attribution as a separate section marked as such; the finding paragraph naming which of spec 8's items the evidence points at; the stop-rule verdict (collector share under a quarter: stop and report; else continue).

- [ ] **Step 5: Commit**

MoarVM `"Bench: perf profile runner for the GC A/B"`; traces `"ngc: profile before"`; pointer. The controller rules on the stop before Task 3 is dispatched.

---

### Task 3: Foundations: view.zig, typed atomics, the wrapper pattern on worklist and allocation

**Files:**
- Create: `src/zig/gc/view.zig`, `src/zig/gc/test/view_test.zig`
- Modify: `src/zig/gc/atomic.zig`, `src/zig/gc/test/atomic_test.zig`, `src/zig/gc/worklist.zig`, `src/zig/gc/allocation.zig`, `src/zig/gc/test/worklist_test.zig`, `src/zig/gc/test/allocation_test.zig`, `src/zig/gc/gc_test.zig` (add `view_test.zig`), `docs/zig-build.md` (one paragraph in "## Garbage collector": the view module and the wrapper pattern)

**Interfaces:**
- Produces, in `view.zig`: `pub const Tc = *c.MVMThreadContext; Instance = *c.MVMInstance; Col = *c.MVMCollectable; ColSlot = *?*c.MVMCollectable; Object = *c.MVMObject; STable = *c.MVMSTable; Frame = *c.MVMFrame; Worklist = *c.MVMGCWorklist; Gen2 = *c.MVMGen2Allocator; Thread = *c.MVMThread;`
  `pub const Flags1 = packed struct(u8) { type_object: bool, stable: bool, frame: bool, serialization_index_allocated: bool, has_object_id: bool, never_repossess: bool, _pad: u2 = 0 }` and `pub const Flags2 = packed struct(u8) { nursery_seen: bool, second_gen: bool, in_gen2_root_list: bool, gen2_live: bool, forwarder_valid: bool, ref_from_gen2: bool, debug_in_gen2_free_list: bool, _pad: u1 = 0 }`, each with a `comptime` block asserting `@as(u8, @bitCast(Flags1{ .stable = true, … all others false })) == c.MVM_CF_STABLE` for every constant of `src/6model/6model.h`'s two enums (`MVM_CF_TYPE_OBJECT` 1 … `MVM_CF_NEVER_REPOSSESS` 32; `MVM_CF_NURSERY_SEEN` 1 … `MVM_CF_DEBUG_IN_GEN2_FREE_LIST` 64);
  `pub inline fn flags1(col: Col) *Flags1` and `flags2(col: Col) *Flags2` (pointer casts of `&col.flags1`/`&col.flags2`);
  `pub const Status = enum(u2) { none = 0, interrupt = 1, unable = 2, stolen = 3 }; pub const Suspend = enum(u2) { none = 0, request = 1, suspended = 3 }; pub const GcStatus = packed struct(usize) { status: Status, suspend: Suspend, _pad: u60 = 0 }` with assertions against `c.MVMGCStatus_*`, `c.MVMSuspendState_*` (0, 4, 12) and `c.MVMSUSPENDSTATUS_MASK` (12), plus `pub inline fn gcStatus(tc: Tc) *usize` (the slot);
  `pub inline fn asObject(col: Col) Object; asStable(col: Col) STable; asFrame(col: Col) Frame; asCol(p: anytype) Col` (a `@ptrCast(@alignCast(…))` each; at `comptime c.MVM_GC_DEBUG >= 1` `asStable` and `asFrame` panic through `MVM_panic` when the matching flag is clear; `asObject` checks neither (an object is the default kind)).
- Produces, in `atomic.zig`: `pub inline fn loadStatus(slot: *usize) GcStatus; storeStatus(slot: *usize, v: GcStatus) void; casStatus(slot: *usize, expected: GcStatus, new: GcStatus) GcStatus` (previous value; `.seq_cst`, `.seq_cst`), over `@bitCast`.
- Produces, the wrapper pattern: in each port file the Zig-typed function is `pub fn name(…view types…)` and the export is `fn nameExport(…translate-c types…) callconv(.c) …` calling it; the `comptime { @export(&nameExport, …) }` block names the wrapper. First applied here: `worklist.create(tc: Tc, include_gen2: bool) Worklist`, `addSlow(worklist: Worklist, item: ColSlot) void`, `presizeFor(worklist: Worklist, items: u32) void`, `destroy(worklist: Worklist) void` (the unused `tc` parameters are on the wrappers only); `allocation.allocateNursery(tc: Tc, size: usize) *anyopaque`, `allocateStable(tc: Tc, repr: *const c.MVMREPROps, how: Object) STable`, `allocateTypeObject(tc: Tc, st: STable) Object`, `allocateObject(tc: Tc, st: STable) Object`, `allocateFrame(tc: Tc) Frame`.

- [ ] **Step 1: Failing tests**

`view_test.zig`: `"flag views round-trip every MVM_CF_ constant"` (for each constant, set the one field, `@bitCast` equals the constant; read a real collectable's flags through the view: a fresh nursery object has `second_gen == false`, `instance.VMNull` has `second_gen == true`), `"GcStatus round-trips the C constants"` (`none/none` is 0, `interrupt/request` is 5, `unable/suspended` is 14), `"asStable panics on a non-STable at debug 1"` (skipped at debug 0; use the existing panic-expectation pattern of `small_test.zig` if one exists, else assert the flag check by reading `view.zig`'s comptime branch and testing the happy path only, and say so). `atomic_test.zig`: `"casStatus returns the previous value and swaps only on match"`. Worklist and allocation tests re-targeted to the typed signatures.

- [ ] **Step 2: Run to see them fail**

`zig build unit-test 2>&1 | tail` : compile errors naming `view`.

- [ ] **Step 3: Implement `view.zig`, the atomics, and rewrite `worklist.zig` and `allocation.zig`**

Apply spec 8 a, b, c, d, e, f to the two files throughout: typed pointers, locals at first use, `for` loops, flag views (`view.flags1(col).stable`), `alignSize` unchanged, `MVM_gc_enter_from_interrupt`/`_from_allocator` still called through `c.` (orchestrate is Task 8; its direct import comes then). The `MVMROOT` spelling in the allocators becomes `const r = moar.root(tc, &st); defer r.pop(tc);`.

- [ ] **Step 4: Tests, exports, fmt**

`zig build unit-test` and `-Dgc-debug=1`: pass, per-root counts at least 49 and 52 plus the new tests; `zig fmt --check …` clean; `zig build test` 105/105; export set of a fresh `ng-n-base` identical to `ng-c-base`'s.

- [ ] **Step 5: Oracle and tripwire**

Rebuild `ng-n-oracle` and `ng-n-base`; `ngc-oracle-driver.sh` groups (a) and (b): 32 cells exit 0, byte-identical; tripwire `ab.sh --rounds=3 --runs=5 --volume=100000` `ng-n-base` against `ng-c-base`: ratios recorded against the thresholds of `ngc-baseline-crc.md`.

- [ ] **Step 6: Commit**

MoarVM `"GC native: view module, typed atomics, worklist and allocation"`; traces `"ngc: task 3 oracle and tripwire"`; pointer. Report with "## Reading notes".

---

### Task 4: gen2.zig

**Files:**
- Modify: `src/zig/gc/gen2.zig`, `src/zig/gc/test/gen2_test.zig`

**Interfaces:**
- Produces: `gen2.create(i: Instance) Gen2; allocate(al: Gen2, size: u32) *anyopaque; allocateZeroed(al: Gen2, size: u32) *anyopaque; destroy(i: Instance, al: Gen2) void; transfer(src: Tc, dest: Tc) void; compactOverflows(al: Gen2) void`; `binOf`/`sizeOfBin` unchanged; the size classes iterated as `al.size_classes[0..c.MVM_GEN2_BINS]`, pages as `sc.pages[0..sc.num_pages]`, overflows as `al.overflows[0..al.num_overflows]`.

- [ ] **Step 1: Re-target the tests** to the typed API; add `"page walk through slices visits the same addresses as the C arithmetic"` (allocate `MVM_GEN2_PAGE_ITEMS + 1` objects of one bin, walk the pages through the slice form, compare the set of addresses with the pointer-arithmetic form of the faithful file kept as a test-local helper).
- [ ] **Step 2: Run to see them fail.**
- [ ] **Step 3: Rewrite** with a, b, e, f; the free-list threading through `[*c][*c]u8` becomes a typed `*?*FreeNode` view in one accessor with the same byte layout (a `comptime` assertion that `@sizeOf(FreeNode) == @sizeOf(usize)`).
- [ ] **Step 4: Tests, fmt, `zig build test`, exports.**
- [ ] **Step 5: Oracle (a)+(b) 32 cells, tripwire.**
- [ ] **Step 6: Commit** `"GC native: gen2"`; traces; pointer.

---

### Task 5: roots.zig

**Files:**
- Modify: `src/zig/gc/roots.zig`, `src/zig/gc/test/roots_test.zig`

**Interfaces:**
- Produces: typed signatures for the sixteen exports (e.g. `addInstanceRootsToWorklist(tc: Tc, worklist: ?Worklist, snapshot: ?*c.MVMHeapSnapshotState) void`, `addFrameRootsToWorklist(tc: Tc, worklist: Worklist, frame: Frame) void`, `tempPushSlow(tc: Tc, slot: ColSlot) void`); the instance roots as `const instance_roots = [_]InstanceRoot{ .{ .get = …, .desc = "…" }, … }` in the C order of `src/gc/roots.c` `MVM_gc_root_add_instance_roots_to_worklist`, iterated with `inline for`, where `InstanceRoot` is `struct { get: fn (Instance) ColSlot, desc: [*:0]const u8 }` (comptime function pointers; the walk stays a straight sequence of `addCollectable` calls after inlining); the thread roots likewise.

- [ ] **Step 1: Tests**: extend `"instance roots are added in the C order"` into the golden test: a comptime array of the 40 description strings in order, copied from `src/gc/roots.c` at authoring; walk with a worklist and a heap-snapshot stand-in that records descriptions; compare the recorded sequence with the golden list and the count with `instance_roots.len`; keep the SpeshOverviewEvent and mark_args tests.
- [ ] **Step 2: Run to see the new assertions fail** (no `instance_roots` yet).
- [ ] **Step 3: Rewrite** with a, b, e, f, g; `addCollectable` stays one inline helper with the worklist-or-snapshot branch; the frame-register scan uses `for (work[0..num_locals], types[0..num_locals]) |*slot, kind|`.
- [ ] **Step 4: Tests, fmt, `zig build test`, exports.**
- [ ] **Step 5: Oracle (a)+(b), tripwire.**
- [ ] **Step 6: Commit** `"GC native: roots"`; traces; pointer.

---

### Task 6: collect.zig

**Files:**
- Modify: `src/zig/gc/collect.zig`, `src/zig/gc/test/collect_test.zig`, `src/zig/gc/view.zig` (adds `Kind` and `kind`), `src/zig/gc/test/view_test.zig`

**Interfaces:**
- Consumes: `roots.addPermanentsToWorklist/addInstanceRootsToWorklist/addTcRootsToWorklist/addTempsToWorklist/addGen2sToWorklist/addFrameRootsToWorklist/gen2Add` (Task 5), `gen2.allocate/compactOverflows` (Task 4), `worklist.create/destroy` and `moar.worklistAdd` (Task 3), `objectid.useAllocation/clear` (still through `c.` until Task 7; swapped to the import there).
- Produces: `collect(tc: Tc, what_to_do: WhatToDo, gen: Generations) void` where `WhatToDo = enum(u8) { all = c.MVMGCWhatToDo_All, no_instance = …, in_tray = …, finalizing = … }` and `Generations = enum(u8) { nursery = …, both = … }` asserted against the C constants; `markCollectable(tc: Tc, worklist: Worklist, col: Col) void`; `freeNurseryUncopied(executing: Tc, tc: Tc, limit: [*]u8) void`; `freeStables(tc: Tc) void`; `freeGen2Unmarked(executing: Tc, tc: Tc, global_destruction: bool) void`; `newThreadNurserySize(i: Instance) u32`; `WorkToPass` as `struct { targets: std.ArrayListUnmanaged(ThreadWork) = .empty }` grown with `ensureTotalCapacityPrecise(moar.mvm_allocator, len + 1)` (spec 8 h); the kind dispatch in `markCollectable`, `freeNurseryUncopied` and `freeGen2Unmarked` as `switch (view.kind(col))` with `pub fn kind(col: Col) Kind` in `view.zig` (`Kind = enum { type_object, stable, frame, object }`, tested in C precedence: type object, then STable, then frame).

- [ ] **Step 1: Tests**: re-target; add `"kind follows the C flag precedence"` and `"work passing grows the target list one entry at a time"` (push to three distinct target ids; capacity equals length after each).
- [ ] **Step 2: Run to see them fail.**
- [ ] **Step 3: Rewrite** with a-f and h; the three `MVM_barrier` fences and the `MVM_casptr` sites keep their comments; the debug-log calls keep their comptime gates.
- [ ] **Step 4: Tests, fmt, `zig build test`, exports.**
- [ ] **Step 5: Oracle (a)+(b), tripwire; rebuild `ng-n-stress`; nqp and rakudo `make test` under `ng-n-base` and `ng-n-stress` (lists identical); `cleanup.sh --runs=20` on `ng-n-base` and `ng-n-stress`; peak RSS of the full crc-getter within the C spread (from the tripwire's RSS column) as the h ruling's evidence, recorded.**
- [ ] **Step 6: Commit** `"GC native: collect"`; traces; pointer.

---

### Task 7: wb.zig, objectid.zig, finalize.zig, debug.zig

**Files:**
- Modify: the four files, `src/zig/gc/test/small_test.zig`, `src/zig/gc/collect.zig` (swap `c.MVM_gc_object_id_*` and `c.MVM_gc_finalize_*` to imports)

**Interfaces:**
- Produces: `wb.hit(tc: Tc, update_root: Col, referenced: Col) void`; `objectid.useAllocation(tc: Tc, item: Col) *anyopaque; clear(tc: Tc, item: Col) void; …`; `finalize.addToQueue(tc: Tc, obj: Object) void; …`; `debug.logCollection(…)` with the `fprintf` format string byte-identical (the oracle proves it).

- [ ] **Step 1: Tests re-targeted; a log-format test**: at debug 1, one collection into a temp file, the line matches `^seq=\d+ tid=\d+ full=[01] coord=[01] from=\d+ next=\d+ promoted=\d+ since_full=\d+ gen2_freed=\d+ stables_freed=\d+ finalizing=\d+$` (skip at debug 0).
- [ ] **Step 2-4: fail, rewrite (a, b, e, f), tests/fmt/test/exports.**
- [ ] **Step 5: Oracle (a)+(b), tripwire.**
- [ ] **Step 6: Commit** `"GC native: wb, objectid, finalize, debug"`; traces; pointer.

---

### Task 8: orchestrate.zig

**Files:**
- Modify: `src/zig/gc/orchestrate.zig`, `src/zig/gc/test/orchestrate_test.zig`, `src/zig/gc/allocation.zig` (swap `c.MVM_gc_enter_from_*` to the import)

**Interfaces:**
- Consumes: `view.GcStatus/Status/Suspend`, `atomic.loadStatus/storeStatus/casStatus`, `collect.collect/freeNurseryUncopied/freeGen2Unmarked/freeStables`, `roots.gen2Cleanup`, `finalize.*`, `debug.logCollection`.
- Produces: `enterFromAllocator(tc: Tc) void; enterFromInterrupt(tc: Tc) void; markThreadBlocked(tc: Tc) void; markThreadUnblocked(tc: Tc) void; isThreadBlocked(tc: Tc) bool; globalDestruction(tc: Tc) void`; every one of the 118 atomic sites reads as a status (`atomic.casStatus(view.gcStatus(tc), .{ .status = .none }, .{ .status = .interrupt })`) with its C macro-and-line comment kept; `DebugServerData` mirror unchanged with its probe.

- [ ] **Step 1: Tests re-targeted**; the site map: the implementer writes `.superpowers/…/task-8-atomics.tsv` (faithful line, native line, C macro and line) for all 118 sites before rewriting, and the review checks it.
- [ ] **Step 2-4: fail, rewrite (a, b, d, f; `signalOneThread`'s state machine as a `switch` on `loadStatus(...).status`), tests/fmt/test/exports.**
- [ ] **Step 5: Oracle (a)+(b), tripwire; rebuild `ng-n-stress`; suites under `ng-n-base`/`ng-n-stress`; `cleanup.sh --runs=20` on both (120 of 120); the full crc-getter under `ng-n-stress` five times, exit 0.**
- [ ] **Step 6: Commit** `"GC native: orchestrate"`; traces; pointer. (Dispatch on the most capable model; reviewer maps the 118 sites.)

---

### Task 9: Acceptance

**Files:**
- Modify: `tools/bench/gc/ab.sh` (`--head2=LIBDIR`; `summary.md` gains `head2` rows and `head2/base` ratios; `sh -n`; the two-sided form unchanged, checked by re-running `--help` and a `--rounds=1 --runs=1 --volume=1000` smoke), `docs/zig-build.md` ("## Garbage collector": the shapes, `view.zig`, the wrapper pattern, `-Dzig-gc`), `traces/llm/specs/2026-11-09-zig-native-gc-design.md` (Errata), this plan (Outcome, Deviations)
- Records: `ngc-oracle.md` (+ matrix, logs), `ngc-crc-ab.md` (+ raw), `ngc-spectest.txt` (+ raw), `ngc-suites.md`, `ngc-cleanup.md`, `ngc-profile-after.md` (+ raw), `ngc-reading-notes.md`

- [ ] **Step 1: `ab.sh --head2`**; commit `"Bench: three-sided ab.sh"`.
- [ ] **Step 2: Oracle matrix**: groups (a), (b), (c), 24 cells (48 logs), exit 0, byte-identical.
- [ ] **Step 3: crc-getter**: `ab.sh --base=ng-c-base/lib --head=ng-f-base/lib --head2=ng-n-base/lib --rounds=7 --runs=5 --volume=100000`, plain and `--bad-packages`; the record states f/c and n/c for wall and RSS with spreads, the aim's verdict per spec 6, no claim inside the spread.
- [ ] **Step 4: Spectest**: C control against native, six runs, Files/Tests counts and TODO-passed list equal to `../bench/z017-spectest-raw/`, zero new failures (re-run an intermittent as Campaign 5 did).
- [ ] **Step 5: Suites and cleanup**: nqp and rakudo under `ng-c-*` and `ng-n-*` (base and stress); `cleanup.sh --runs=20` on the four; lists identical, 240 of 240.
- [ ] **Step 6: Profile after**: `ng-n-syms` (and `ng-n-nlto`), `profile.sh` as Task 2 on `ng-c-syms` and `ng-n-syms`; `ngc-profile-after.md` with the before/after per-symbol comparison and the account of what remains.
- [ ] **Step 7: Docs, errata, Outcome, reading notes**: collect every task report's "## Reading notes" into `ngc-reading-notes.md` (one section per file, verbatim); the Outcome table below filled; the Deviations list copied from the ledger; spec Errata for anything the tasks changed against its text.
- [ ] **Step 8: Commit** MoarVM `"GC native: docs, acceptance"`; traces `"ngc: acceptance"`; pointer. Hand back with the Outcome table; the orchestrator runs the whole-branch review before any merge (the user's call).

## Outcome

| check | result | record |
|---|---|---|
| `-Dzig-gc=false` control equals the Campaign 5 scratch control | equal (Task 1): ng-c-base equals Campaign 5's scratch control; exports 2850 = g7-c-base's | ngc-prefixes.md |
| profile before: collector share of the gap, finding | f/c cycles +4.19 % plain (resolvable), collector share 0.213; bad +4.80 % not resolvable; finding: the `mfence` in processWorklist (+2.56e8, ~15 % of the gap) and the out-of-line translate-c temp-root push (+1.78e8); stop rule fired, user chose to continue with R5 (2026-11-10) | ngc-profile.md |
| oracle (a) C vs native, (b) faithful vs native, (c) C vs faithful: 24 cells (48 logs) | 24/24 cells (8 per group; 48 compared logs) exit 0, every raw log pair byte-identical, both tiers, 10 000 and 100 000 | ngc-oracle.md |
| unit tests, both levels; export set unchanged | from the ledger (Task 8, last Zig change): gc-test 61 + 5 skipped at -Dgc-debug=0, 66/66 at 1; zig build test 105/105; exports of ng-n-base equal ng-c-base's, 2850 names (re-checked at Task 9 with nm -D); 0 mfence | ledger |
| crc-getter f/c and n/c, wall and RSS, plain and bad | f/c 1.027 / 0.990 plain, 1.033 / 0.983 bad; n/c 1.004 / 1.002 plain, 1.010 / 1.017 bad (C spreads 0.013 / 0.026 plain, 0.010 / 0.027 bad); aim met within spread on three of four measures, not met on bad wall (1.010 on the edge of a 0.0101 spread, above the C range) | ngc-crc-ab.md |
| spectest n/c wall and RSS, zero new failures | wall 1.003, RSS 1.000 (head medians inside the base ranges): passes; Files=1365 Tests=138715 and the 29 TODO-passed files as Campaign 5; zero new failures (run 3 IO-Socket-Async.t exit 1 with no failed subtest, a flake per R12: 40/40 serial re-runs clean) | ngc-spectest.txt |
| suites and full-cleanup runs | nqp and rakudo per-file lists identical C vs native at base and stress (rakudo: the pre-existing 02-simple-args.t 17-18 on all four); cleanup 240 of 240; crc-getter under both stress prefixes 10/10 exit 0 | ngc-suites.md, ngc-cleanup.md |
| profile after: what remains | n/c cycles +1.90 % plain, +2.20 % bad on the -syms pair, unresolvable at volume 100 000 on both (shares 0.216 / 0.055 computed only); mfence stall and temp-root call gone; collector difference +3.17e8 -> +1.47e8, mostly the object allocator; -syms builds are different binaries (c -0.8 %, n +2.3 %) | ngc-profile-after.md |
| reading notes | collected verbatim from Tasks 3-8, 13 sections over the 12 files (allocation.zig and atomic.zig share one) | ngc-reading-notes.md |

## Deviations (running list)

- Spec 5 says "16 cells per group" and the plan's file tasks say "32 cells" for groups (a)+(b): a group is 8 cells (2 volumes x 2 settings x 2 tiers); groups (a)+(b) are 16 cells, all three groups 24 (Task 1, Task 3); Task 9's brief said "48 cells", which is the number of compared logs (two per cell), not of cells.
- Task 1: `cleanup.sh --stress` was undefined by the plan; implemented as 20x-allocation variants of the three programs (the interlude's "higher-allocation variants"); the -stress prefixes are run with the plain program set (Ruling R4).
- Task 1: the tripwire threshold is baseline + C spread as spec 6 says; a crossing is a stop-and-measure (one 7-round re-run) before a revert ruling, because the C spread (0.4 %) is below the port's own 3-round noise (Ruling R3). No crossing occurred in Tasks 3-8.
- Task 2: the `.text` of a `-Dstrip=false` build is not identical to its stripped sibling (Zig std.debug code is kept); ng-c-syms ran 1.5 % faster than ng-c-base, so the C side of the before-profile is labelled "taken on a different binary" per spec 7's fallback. `--bad-packages` is unresolvable at volume 100 000 under spec 7's rule.
- Task 2: the stop rule fired (collector share 0.213 < 0.25); the user chose on 2026-11-10 to continue the full ladder on clarity grounds with the fence ruling (R5).
- Task 3 (R5, user-approved): `atomic.fence()` on x86-64 emits `lock orl $0,-64(%rsp)` (clang's lowering of the same seq_cst fence) instead of `mfence`; the Atomics constraint "atomic.fence() stays as it is" was amended. The fence was ~15 % of the plain gap.
- Task 3 (R6/R1): `moar.root` became the inline `TempRoot` helper mirroring roots.h `MVM_gc_root_temp_push`/`_pop`; it already existed (intcache.zig, finalize.zig use it), so those callers gained the inlined push too.
- Task 3 (R7): `GcStatus`/`Status`/`Suspend` are defined in atomic.zig (a host test root that cannot import C) and re-exported + asserted in view.zig, not defined in view.zig as the plan said.
- Task 3/8 (R8, R9): the `GcStatus` field is `suspend_state` (not `suspend`, a Zig keyword); `Suspend` is non-exhaustive (`_`).
- Task 5: the plan's "40 description strings" was wrong: the C instance walk has 22 description sites (18 single-field roots + 4 subsystem/loop walks); golden list 22, `instance_roots.len` 18, `thread_roots.len` 10; the tables are joined from segments around the subsystem calls so the C order holds.
- Task 6: collect.c has two `MVM_barrier` sites, not three; `std.ArrayListUnmanaged` is deprecated in 0.17, `std.ArrayList` (same type) is used; (R10) `moar.mvm_allocator`'s `remap` is `MVM_realloc` so the `WorkToPass` growth is the C's operation sequence (first entry `MVM_malloc(16)` as C's `realloc(NULL,16)`, then `MVM_realloc(16k)`).
- Task 7: the plan's `wb.hit(tc, update_root, referenced)` had the C arity wrong; `hit(tc, update_root)` and `hitBy(tc, update_root, referenced)` follow wb.c. (R11) wb.h's static-inline write barriers are mirrored as `pub inline fn`s in wb.zig. The plan's `objectid.useAllocation` returning `*anyopaque` was wrong: it returns `?*anyopaque` so the export keeps the C's NULL contract (fix round 1).
- Task 8: the plan's "118 atomic sites" was Campaign 4's count over all files; orchestrate.zig has 68 (67 in orchestrate.c + GCDEBUG_LOG's load); all mapped in task-8-atomics.tsv.
- Task 8: the harness forced the implementer's hand-back twice mid-stage-2; the controller read stage2.out and resumed it; no change to the evidence.
- Tripwire wall n/c per file task: T3 1.005, T4 1.005, T5 1.001, T6 1.008 (1.016 after R10), T7 1.019 (1.024 after the fix), T8 1.003; RSS 1.002, 1.014, 0.988, 1.005/1.003, 1.006, 1.013. The acceptance A/B is the number.
- Task 9: `ngc-crc-ab-driver.sh` did not exist (Task 1 and the tripwires ran ab.sh through z017-style drivers); Task 9 wrote it three-sided, with the runs.log exit column fixed (it now records ab.sh's status, not date's). `ngc-oracle-driver.sh` gained `--help`.
- Task 9: `ngc-suites.md` and `ngc-cleanup.md` already held Task 1's control records; the acceptance results are appended to them as "Acceptance (Task 9)" sections (raw in `ngc-suites-acc-raw/`, `ngc-cleanup-acc-raw/`) instead of replacing them. All eight suites were run fresh (none cited from Task 8). Spec 9's "full crc-getter under both stress prefixes at acceptance" was not in the brief's steps; it was run (5 + 5, `ngc-acceptance-stress.sh`) and recorded in `ngc-cleanup.md`.
- Task 9: the after-profile's `.text` fallback labels both sides "a different binary" (ng-c-syms 0.8 % faster than ng-c-base, ng-n-syms 2.3 % slower than ng-n-base), and its gap is unresolvable under spec 7's rule on both settings.
- Task 9: two deferred minors fixed in files the task touched: the docs wording "Without `-Dzig-gc=true`" (now "With `-Dzig-gc=false`"), and a pointer in `ngc-task6-tripwire.md` from its pre-R10 "Spec 8 h evidence" section to the R10 re-run.
