# Final whole-branch review: zig-native-gc, b59305829..85d1c503a (24 commits)

Reviewer: fable (final review), 2026-11-10. Read-only on the checkout; no builds, no timed runs, no worktree.

Scope read: every file of src/zig/gc/ (view, atomic, worklist, allocation, gen2, roots, collect, wb, objectid,
finalize, debug, orchestrate) side by side with its C source in src/gc/ (unchanged on the branch: `git diff --stat
b59305829..85d1c503a -- src/gc 'src/*.c' 'src/**/*.h'` is empty), src/zig/moar.zig and root.zig, the build diff
(build.zig, build/zig/{options,sources,zigimpl}.zig, Configure.pl, build/sources.list), all nine test files and
gc_test.zig, the bench tooling (ab.sh, cleanup.sh, profile.sh, cleanup/*.nqp, README), docs/zig-build.md, the
acceptance records (ngc-crc-ab.md, ngc-spectest.txt, ngc-oracle.md, ngc-profile-after.md, ngc-suites.md,
ngc-cleanup.md, the profile finding) and their raw files (crc summary.md x2, the six spectest .time files,
sockprobe.log, runs.log), task-8-atomics.tsv (all 68 rows against orchestrate.c), the ledger and the pointers file.
The diff was reviewed in passes by file (the 538 KB package was too large for one pass); the head files were read whole.

Inspections run (read-only): `zig fmt --check src/zig build.zig build/zig tools/zig` clean; `sh -n` on the three
tools scripts and all nine traces drivers clean; `perl -c Configure.pl` OK; `nm -D --defined-only` on
/tmp/claude-1000/ng-{c,f,n}-base/lib/libmoar.so: 2850 names each, the c and n sets byte-identical; `objdump -d`:
mfence count c 0, f 3, n 0; `lock orl $0x0,-0x40(%rsp)` count c 37, f 34, n 37 (so clang's lowering on this
toolchain is `-64(%rsp)`, as R5 says, and the native build has exactly the C's count); the ratios in ngc-crc-ab.md
and ngc-spectest.txt recomputed from the raw summary.md and .time files (all agree to the printed digits);
the traces gitlink of 85d1c503a is 0e85fb8, the submodule HEAD.

### Strengths

- Decision fidelity is engineered, not hoped for. Every `gc_status` site compares the whole word where the C does
  (`current != interrupt_requested and current != interrupt`, the `_pad` bits included) and the masked bits where the
  C masks (`isThreadBlocked`, the three `suspend_state` tests in `enterFromInterrupt`); the C `switch` defaults that
  panic are reproduced as `invalidStatus`, including the fall-through quirk of `signal_one_thread` where
  `had_suspend_request` is sticky across iterations (orchestrate.zig:219-237). All 68 sites of task-8-atomics.tsv
  checked against orchestrate.c: operation, ordering and line match.
- The two `MVM_barrier` sites of collect.c (:207, :320) are in the same positions relative to the forwarder store
  and the flag write (collect.zig:431, :546); the native library carries the C's 37 locked-or fences and no mfence.
- view.zig asserts every `MVM_CF_*` bit and every `MVMGCStatus_*`/`MVMSuspendState_*` value at comptime, and
  view_test round-trips them and the kind precedence over all 16 flag combinations. A header change fails the build
  (plan Review Focus 2) and the test suite pins it (Review Focus 3 via casStatus, 5 via the golden-order tests).
- roots.zig keeps the C's 22 description sites in order, joined from three table segments around the four
  interleaved walks; roots_test checks both the worklist walk (18 in-instance slots in order, 37 items on a fresh
  instance) and the heap-snapshot walk (22 descriptions, twice, with the weak-hash branch flipped).
- gen2_test's differential page walk (the faithful `[*c]u8` arithmetic kept as a test-local oracle against the slice
  form) and the transfer test (free-list chain of 255 + 1 in order, owners, overflows, roots) pin exactly the
  arithmetic a log cannot show.
- R10 is verified at the right level: moar.zig's test checks the ArrayList's capacity equals its length after each
  `ensureTotalCapacityPrecise(len + 1)`, and std's implementation (/usr/lib/zig/std/array_list.zig:1355-1381) does
  try `remap` first, so the growth is one MVM_realloc(16k) per entry as collect.c:468-470.
- The DebugServerData mirror (translate-c demotes the struct for its bit-fields) is checked by a C layout probe for
  size and the four touched offsets.
- The records are honest and reproducible: the aim miss on --bad-packages wall (1.010 against a 0.0101 spread, native
  median above the C range) is stated as a miss, not rounded away; both -syms profiles are labelled "a different
  binary"; the unresolvable rule is applied literally; nothing is claimed inside a spread.

### Declined to judge

- Pre-existing breakage of `zig build unit-test -Doptimize=safe` at the base commit (Task 4 observation): not
  introduced by this branch; noted under Recommendations only.
- `moar.rootN` still calls the translate-c `MVM_gc_root_temp_push` out of line (moar.zig:217-225): unchanged on this
  branch and not on the collector's path; R6 covered `root`, not `rootN`.
- The Perl build (`--zig=PATH`) has no `-Dzig-gc=false` control: spec 3 says a Perl-side switch is not required;
  Configure.pl documents the choice.
- The crc-getter aim miss on --bad-packages wall: spec 6 makes it an aim, reported not gated; it is reported.
- The C bugs the ports found (interlude branch gc-fixes-from-zig-port): a separate branch, not in this range.
- `cAssert` compiled only in Debug: matches the C, which is built with -DNDEBUG except in Debug
  (build/zig/moar.zig:24, :89).
- The fence on x86-64 Windows (no red zone; LLVM uses `(%rsp)` there): the Zig build is POSIX-only
  (build/sources.list has only platform-posix), so the `-64(%rsp)` choice is correct for every target it builds; a
  comment would be fair, see Minor.

### Issues

#### Critical (Must Fix)

None found. No decision divergence from the C, no memory-safety fault on the release path, the gate result is
carried by the raw data, and `-Dzig-gc=false` links the C collector (root.zig gates the imports; applyZig keeps the C
files; the C control's export set equals the native's and the Campaign 5 control's).

#### Important (Should Fix)

1. **src/zig/gc/finalize.zig:74 — `tc.finalize[0..tc.num_finalize]` slices a `[*c]` that is NULL for every thread that
   has never allocated a finalizable object** (`MVM_tc_create` leaves `finalize` NULL with `alloc_finalize` 0).
   `walkQueues` runs `walkThreadFinalizeQueue` over every thread on every collection, so in a safety-checked build
   (`-Doptimize=Debug` or `ReleaseSafe`) the first GC panics with "attempt to use null value" (the very behaviour the
   Task 4 implementer probed and wrote the `list()` helper to avoid; the faithful port indexed `tc.*.finalize[i]`
   under `while (i < num_finalize)` and never touched a NULL). The release build is unaffected (a null pointer with
   length 0 iterates zero times), so this is bounded to safe modes, which the ledger already records as broken at the
   base for another reason; it still adds a new fault to them and breaks the ports' own convention. Fix: the same
   guarded helper the other files use, e.g. `for (list(tc.finalize, tc.num_finalize)) |entry|` with a local
   `list` as in collect.zig:85-87 (or move `list` to view.zig and use it from all five files, see Minor 1).
   The same pattern at **src/zig/gc/debug.zig:48** (`szc.pages[0..szc.num_pages]`, NULL for every bin never set up;
   `findRegion` is a debugger helper under MVM_GC_DEBUG, the faithful port used an index loop) should take the same
   guard in the same fix.

#### Minor (Nice to Have)

1. **src/zig/gc/view.zig:7-8 — the module comment claims its accessors are "the only `@ptrCast(@alignCast(…))` sites
   of the ports outside the C ABI"**. They are not: gen2.zig has 10 (allocator results, `node()`), roots.zig 6,
   orchestrate.zig 5, finalize.zig 4, collect.zig 3, worklist.zig 3. The spec's rule (8a) is about view changes
   (collectable as object/STable/frame), which the files do route through view.zig; the allocator-result casts are a
   different category. Reword the claim to "the only view changes between a collectable and what it heads", and
   consider one shared `list(ptr, len)` in view.zig in place of the four copies (collect, gen2, roots; orchestrate's
   `workList` is the same idea) so Important 1 cannot recur.
2. **`const visibility = if (@import("zig_options").lto) .protected else .default;` and its four-line comment are
   repeated in all ten files.** One `pub const export_visibility` in view.zig (or moar.zig) would make the `.protected`
   rule one place to change.
3. **roots.zig:503 calls `c.MVM_gc_mark_collectable` and gen2.zig:353 `c.MVM_gc_root_gen2_add` through the C symbols**
   where every other cross-file call is a Zig import (spec 8b, "Zig calling Zig ... so the compiler sees the bodies
   regardless of LTO"). Under `-Dlto` the protected export binds locally, so today it costs nothing; without LTO it is
   a PLT call. Zig allows the circular import (`@import("collect.zig").markCollectable`); the ledger left this for
   triage: make them imports, or state in the module comments why not.
4. **src/zig/gc/atomic.zig:121 — the x86-64 arm encodes the SysV red zone (`-64(%rsp)`) without a target check.**
   Correct for every target the build supports (POSIX only), and a value-preserving `or $0` cannot corrupt a leaf
   function's red-zone data; but LLVM itself emits offset 0 where there is no red zone (Win64, `noredzone`). A one-line
   comment ("SysV red zone; use (%rsp) where there is none") or an `os.tag` branch would keep the next porter honest.
   On the question asked: as written this is **not a `fence seq_cst` in the LLVM IR model**; it is an `asm volatile`
   with a memory clobber (a full compiler barrier for every memory access, atomic ones included, since LLVM treats it
   as an opaque read/write of all memory) plus a locked RMW, which on x86-TSO is a full hardware barrier (SDM 8.2.3.9).
   That is exactly the instruction sequence clang emits for `atomic_thread_fence(seq_cst)` on this toolchain (37 of
   them in ng-c-base), so the collector observes memory in the same order as the C; the only thing lost is the
   optimizer's knowledge that it is a fence, which can only make the Zig more conservative, never less. R5 holds.
5. **No test pins the fence shape.** `test "fence"` (atomic_test.zig:287) only calls it. The shape is pinned by the
   records' objdump counts (and re-checked here), not by anything that runs in `zig build test`. A cheap guard: a
   shell check in tools/bench/gc (or the oracle driver) that `objdump -d libmoar.so | grep -c mfence` is 0 on x86-64
   and the `lock orl` count equals the C control's; or a comptime `@embedFile`-free assertion is not available, so a
   script is the honest option.
6. **orchestrate.zig:398, :705 — `for (workList(tc)) |*work|` re-reads a slice the C re-reads per iteration
   (`tc->gc_work[i]`, `tc->gc_work_count`).** Nothing in the loop bodies calls `addWork` on `tc` (only
   `signalAll`/`enterFromInterrupt` do, before `runGc`), so the slice is stable; the deferred minor asked for the
   comment that says so. Add it at both loops.
7. **ngc-spectest.txt — the load column shows the two head runs 2 and 6 starting at 1-minute load 1.98 and 1.93
   (15-minute 6.9 and 14.2) against 0.83/0.85 for base runs 4 and 5**; disclosed but not discussed. It disfavours the
   head side, so the 1.003 reading is conservative for the gate; one sentence saying so would close the point the
   Task 9 reviewer raised.
8. **ngc-spectest.txt / R12 — the flake probe (40/40) ran the file serially**, not under the TEST_JOBS=24 load where it
   exited 1 after 26 subtests. The classification is reasonable (no failed subtest, passed in the other five runs and
   in 27 earlier logs, a test with an upstream flake history) and follows the Campaign 5 precedent, but the evidence
   does not reproduce the failing condition. If the user wants more before merging: one more full spectest head run,
   or 20 runs of the file beside a parallel `make test`, would carry the claim on its own.
9. **tools/bench/gc/cleanup.sh:48 — no trap removes `$work` on SIGINT/SIGTERM** (deferred minor 44); failing runs'
   output is kept on purpose, so `trap 'rm -rf "$work"; exit 130' INT TERM` after mktemp is the fix.
10. **src/zig/gc/test/worklist_test.zig:833 — "the C add macro and a Zig pop agree" pops nothing** (`worklistGet` is
    private to collect.zig; the test checks `entry(wl, items - 1)`). Rename, or export `worklistGet` for the test and
    pop.
11. **src/zig/gc/test/roots_test.zig:713 — `table[6].when(tc)` is a magic index for interp_cu** (deferred minor 84);
    find the entry by `desc` or name a comptime constant.
12. **traces ngc-reading-notes.md has 13 `##` sections** ("allocation.zig and atomic.zig" is a second section for
    two files already covered) against the plan Outcome's "one section per file of src/zig/gc (12)". Say 13, or fold.
13. **ab.sh --head2 rotation over an odd round count**: with 7 rounds the base side goes first in rounds 1, 4, 7
    (3 of 7) and each head in 2 of 7. Inherent to three sides in seven rounds; a sentence in the record (or
    `--rounds=6`/`9` next time) would remove the question.

### Deferred minors ruled on (final-review-pointers.md)

- 41 (runs.log exit column records `date`'s exit): **dismiss, already fixed** by Task 9's ngc-crc-ab-driver.sh (the
  plan deviation says so; ngc-crc-ab-raw/runs.log shows ab.sh's status).
- 44 (cleanup.sh no trap on interrupt): **fix now**, one line (Minor 9).
- 45 (docs "Without -Dzig-gc=true" wording): **dismiss, already fixed** at Task 9 (docs/zig-build.md:393 reads "With
  `-Dzig-gc=false`").
- 46 (--stress is the implementer's interpretation): **dismiss**; R4 stands and the README and cleanup.sh header define
  it (20x the inner loop bounds).
- 53 (Task 2 record: shares on one sampled run, "lock or far cheaper", hot-spots alignment, profile.sh "follows the
  process tree"): **dismiss**; the after-profile states "one sampled run per side and setting" at every per-symbol
  claim; perf stat does follow children by default; the Task 2 record is history.
- 70 (worklist.zig's three @ptrCast(@alignCast) on allocator results; R5 comment): **dismiss the casts** (allocator
  results, not view changes; fix the view.zig claim instead, Minor 1); **dismiss the comment as done** (atomic.zig:
  111-114 already says the shape is what clang emits).
- 77 (gen2 transfer @memcpy without list() guard; page-walk test cases; `for (pages, 0..) |_, k|`): **dismiss** the
  guard (dest is a live thread's gen2, its overflows list exists); **defer** the two extra page-walk cases
  (alloc_pos == alloc_limit, empty last page) as a nice-to-have; **dismiss** the loop form (it is in a test).
- 84 (roots_test magic index; segment positions between table groups): **fix now** the index (Minor 11, trivial);
  **dismiss** the segment check (the oracle makes the whole order load-bearing and passes in 24/24 cells).
- 94 (tripwire record pre-R10 text; mainRun/drain inline; `catch unreachable` comment): **dismiss, done** (Task 9
  added the pointer; collect.zig:205-206 already says MVM_malloc panics rather than failing); `inline fn` on
  mainRun/drain is a codegen choice with no decision in it: **dismiss**.
- 102 (small_test 1024-byte buffer; objectid doc justification): **dismiss** both (three ~150-byte lines fit with
  room; the doc comment now states the NULL contract correctly).
- 111 (no test of the unnamed-Suspend default paths; finishGc workList comment): **defer** the test (a child-process
  panic test of `invalidStatus` on a word such as `UNABLE | 8` is the shape; moderate cost, no release behaviour
  depends on it); **fix now** the comment (Minor 6).

### Recommendations

1. Fix wave (small, one commit): Important 1 (finalize.zig:74, debug.zig:48 through a shared guarded `list`), Minor 1
   (view.zig claim), Minor 6 (two comments), Minor 9 (trap), Minor 10/11 (test names/index). None changes a decision
   or a release instruction, so the oracle need not be re-run; `zig build test` and `zig fmt --check` suffice, plus
   one `zig build unit-test` at -Dgc-debug=1 for the two guarded sites.
2. Optional before merge: Minor 8 (one more parallel-load pass over IO-Socket-Async.t on the native side) if the user
   wants R12 to stand on evidence that reproduces the failing condition.
3. Follow-up campaign items, not for this branch: the safe-mode unit-test breakage at the base (null casts at VM boot);
   a scripted fence-shape check (Minor 5); Zig imports in place of the two remaining `c.MVM_gc_*` cross-calls
   (Minor 3); the allocator's code layout that the after-profile points at (786 vs 384 bytes, `num_temproots` kept in
   memory), which is the only collector cost left in the profile and is a shape, not a decision.

### Assessment

**Ready to merge?** With fixes

**Reasoning:** The native collector makes the C collector's decisions at every site a log cannot see: the status
machine compares whole words and masked bits exactly where the C does, the forwarder publish and both fences sit in
the C's positions, the root tables keep the C's 22-site order, the gen2 free-list and page arithmetic are faithful
and differentially tested, and the export set and fence counts of the shipped library equal the C control's by my
own nm/objdump. The evidence carries "no decision change" (24/24 byte-identical cells, suites identical, 240/240
cleanup) and "no regression" to the spec's standard (spectest 1.003/1.000 inside the base range; the one aim miss is
reported as a miss). The one defect worth a fix before merging is a NULL-slice on a safety-checked build in
finalize.zig (release unaffected), together with the small comment and test polish above.
