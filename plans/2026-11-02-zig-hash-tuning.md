# Zig Hash Engine Tuning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Zig hash engine's default ladder to parity with the C engine at the nqp level, make the Small-to-Robin-Hood migration no more expensive than the C engine's own resize, and add opt-in LTO to both builds, every change kept only if it measurably moves its number.

**Architecture:** Measurement first: the nqp-level harness becomes the scoreboard, the C-API microbenchmark attributes, and a profile ranks the causes. Each lever is one task that changes one named thing in `src/zig/core/hash/` (policy layer, Small tier, Robin Hood tier, C-shaped wrapper, migration), measured before and after against the C engine, kept or reverted. LTO is a build option in `build.zig` and `Configure.pl` with local symbol binding of the exports. The campaign is bounded to the profile's levers plus at most two more profile rounds.

**Tech Stack:** Zig 0.16.0 (`/usr/bin/zig`), `perf` 7.2.9, nqp stage0, Perl `Configure.pl`, the existing benchmarks under `tools/bench/` and `src/zig/core/hash/bench.zig`.

**Spec:** `traces/llm/specs/2026-11-02-zig-hash-tuning-design.md` (decisions §2, facts §3, levers §4, what does not change §5, the profile §6, protocol §7, acceptance §8). The engine it tunes: `traces/llm/specs/2026-11-02-zig-hash-engine-design.md` and its plan's "Benchmark results".

## Global Constraints

- Repo root: `/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM`, branch `zig-hash-tuning` cut from `zig-hash-engine` (`a5ea2a419`). nqp stage0 at `../src/vm/moar/stage0`. `traces/llm` is a submodule: edits to this plan are committed inside it, then the pointer is bumped in MoarVM.
- Spike branches are sources, not bases: `zig-hash-spike-boundary` (commits `d45ef388d` nqp harness, `ab1b05320` `-Dlto`/`-Dstrip` options) and `zig-hash-spike-profile` (harness changes for per-size `insert_nth` and `--ops`, unstripped builds; report `/tmp/claude-1000/hash-profile-report.md`). Cherry-pick or re-create their useful parts; never merge them.
- Nothing observable changes (spec §5, §10): C APIs, headers, tier interface (changes must keep the four single-rung tables working and be called out), tier sets, `small_threshold = 64`, migration trigger, iteration order, stale/CAS/safepoint discipline. The C engine (`-Dzig-impl=false`, plain `perl Configure.pl`) builds exactly as today; without `-Dlto`/`--zig-lto` the link is exactly today's.
- Measurement (spec §7): nqp harness `tools/bench/hash-bench.nqp` run as `zig-out/bin/moar --libpath=../src/vm/moar/stage0 ../src/vm/moar/stage0/nqp.moarvm tools/bench/hash-bench.nqp --engine=<c|zig> --sizes=4,16,32,63,64,65,128,256,1024,16384 --runs=5`, medians with min and max; the C-API bench `zig build hash-bench --prefix $PWD/zig-out -- --sizes=... --runs=5`; ratios are Zig over C; a lever is kept only if its targeted ratios move outside the spread. The machine conditions (CPU model, governor, load) are recorded once in this plan's results section and kept for every comparison.
- Finish line (spec §8, decisions 6-8): every op at every size in both tiers at or below 1.05 (or inside the spread) at the nqp level, except Robin Hood iterate in a non-LTO build at or below 1.10 and within noise of 1.0 under `-Dlto`; Small insert and iterate below 1.0 and allocation under a third at 16-64; the 65th insert at or below the C engine's 97th insert; Raku level within the engine campaign's band; spectest 0 new failures, wall and RSS within 2 percent. Shortfalls are recorded per op and size, and the campaign still ends after the bounded rounds.
- Before `zig build` without `-Dconfig-h`: `rm -f src/gen/config.h src/gen/config.c src/gen/config.o`; absolute `--prefix $PWD/zig-out`; after Perl builds `make realclean; rm -f moar libmoar.so src/gen/config.h src/gen/config.c src/gen/config.o Makefile`. Builds take minutes (timeout 600000 ms); rakudo builds and spectests run in the background with output to files.
- `zig fmt --check build.zig build/zig src/zig tools/zig`, `perl -c Configure.pl`, `sh -n` on touched scripts clean. Commit after each task with the message given plus the attribution lines the environment requires.

## Review Focus

1. The Small tier's cached entry base must be recomputed when `grow` doubles the capacity, or every entry read after the first growth lands in the wrong place: Task 4 test `entry base survives grow`.
2. The migration's bulk-insert path must produce a table that `fsck` accepts and in which every key is found, including when the source rung holds a freshly created entry whose key the caller has not filled yet (the C's lvalue contract): Task 7 test `bulk migration keeps every key and tolerates one unfilled entry`.
3. A hash presized above the threshold (`build(.., 200)`) or one that grew into Robin Hood and shrank must not be affected by the 128-slot migration sizing: Task 7 test `presized and shrunk hashes are not resized by the migration change`.
4. Under `-Dlto`, an exported symbol must still be reachable from outside libmoar (the benchmark shim and `hash-str-test` link it) while calls inside libmoar bind locally: Task 2 checks `nm -D` lists the exports and `objdump` shows no `@plt` calls to them.
5. `--zig-lto` with a non-zig compiler must refuse at configure time with a message naming `--cc=zig`: Task 2 check `perl Configure.pl --zig=/usr/bin/zig --zig-lto` (gcc) exits non-zero with that text.

---

### Task 1: Scoreboard, baseline and attribution

**Files:**
- Create: `tools/bench/hash-bench.nqp` (from spike commit `d45ef388d`), `tools/bench/hash-compare.pl` (renders ratio tables with spread from two TSVs)
- Modify: `tools/bench/hash-bench.sh` (runs the nqp harness alongside the others; `--nqp-only`, `--sizes`, `--runs`), `src/zig/core/hash/bench.zig` (per-size `insert_nth` for every size on the ladder, `--ops=` filter), `build/zig/options.zig` and `build/zig/zigimpl.zig` (`-Dstrip=<bool>`, default strip unless Debug, as spike `ab1b05320`), this plan ("## Profile and baseline", "## Results")
- Test: `tools/bench/hash-compare.pl` self-test on a fixture; `bench.zig`'s `ladder` test extended for `insert_nth` sizes

**Interfaces:**
- Produces: `hash-bench.nqp` TSV `engine size op ns_per_op rss_bytes` with ops `insert, lookup_hit, lookup_miss, iterate, delete, insert_nth` (`insert_nth` at every size when `--nth=all`, default at T and T+1); `hash-compare.pl c.tsv zig.tsv [...]` prints a markdown table per op with `ratio (zig_median / c_median) [zig min-max / c min-max]`; `bench.zig --ops=insert,lookup_hit,...` and `--nth=all`; `-Dstrip=false` keeps symbols for `perf annotate`.

- [ ] **Step 1: Promote the harness and the bench changes** (cherry-pick `d45ef388d`; port the profile branch's `bench.zig` changes by reading `git diff zig-hash-engine..zig-hash-spike-profile -- src/zig/core/hash/bench.zig`; add `-Dstrip`), then write `hash-compare.pl` with a fixture test (`tools/bench/t/hash-compare.t`: two 3-line TSVs, expected ratio and spread strings) and run it: `prove tools/bench/t/hash-compare.t` → pass.
- [ ] **Step 2: Baseline both engines** on the nqp harness (`--runs=5`) and the C-API bench, with `insert_nth` at every size and additionally the C engine at `--sizes=49,97` for the resize yardstick; render with `hash-compare.pl`; record the tables and the machine conditions under "## Profile and baseline". Expected: numbers consistent with spec §3 within noise; the C 97th insert well above its ordinary insert.
- [ ] **Step 3: Attribution.** If `/tmp/claude-1000/hash-profile-report.md` exists and matches the current engine (same commit range), copy its attribution tables and ranked causes into "## Profile and baseline"; otherwise produce them now exactly as spec §6 describes (`perf record -g` on `hash-bench --sizes=64` and `--sizes=1024` with `--ops=lookup_hit` and `--ops=delete`, `-Dstrip=false`, `perf report --no-children`, `perf annotate` on the hot engine functions, `perf stat -e instructions,cycles,branches,branch-misses` per engine at the same sizes, the migration breakdown at `--sizes=65 --ops=insert_nth`), and record them.
- [ ] **Step 4: Order the levers.** From the attribution, write under "## Profile and baseline" the order in which Tasks 3 to 7 will run and which (if any) are struck, each with the share of the deficit it addresses. Tasks struck here are skipped with a note in "## Results".
- [ ] **Step 5: Verify and commit**: `zig build unit-test --prefix $PWD/zig-out` passes (bench `ladder` test included), `sh -n tools/bench/hash-bench.sh`, `perl -c tools/bench/hash-compare.pl`, `zig fmt --check`; commit inside `traces/llm` ("tuning plan: profile and baseline") and in MoarVM ("hash bench: nqp harness, per-size insert_nth, compare script, -Dstrip").

---

### Task 2: LTO opt-in with local symbol binding

**Files:**
- Modify: `build/zig/options.zig` (`lto: bool` from `-Dlto`, default false), `build/zig/zigimpl.zig` (`object.lto = .full` when set), `build/zig/moar.zig` (`lib.lto = .full` when set), `src/zig/core/hash/*_exports.zig` (export visibility), `Configure.pl` (`--zig-lto`), `build/Makefile.in` (flags), `docs/zig-build.md` (options table and a paragraph under "Hash engine")
- Test: `zig build test`, `unit-test`, `hash-bench` under `-Dlto`; the Perl stage0 smoke under `--zig-lto`; symbol and call-site checks

**Interfaces:**
- Produces: `-Dlto` and `--zig-lto`; exports bound locally. Binding, in order of preference per spec §4.7: (a) `@export(&f, .{ .name = ..., .visibility = .protected })` in every `*_exports.zig` (protected symbols stay in the dynamic table and bind locally; works in both builds with no linker flag); if the 0.16 toolchain does not honour protected for the inlining, (b) `-Wl,-Bsymbolic-functions` on libmoar's link in both builds; (c) hidden visibility under LTO only, with the benchmark shim and `hash-str-test` linking the object directly.

- [ ] **Step 1: Write the checks first** as a script `tools/check-lto-binding.sh` (sh): given `zig-out/lib/libmoar.so`, prints the count of `MVM_str_hash_` symbols in `nm -D` (expect > 0), the count of `@plt` calls to `MVM_str_hash_` in `objdump -d` (expect 0 with binding on), and the number of surviving definitions of `MVM_str_hash_fetch_nocheck` (expect 0 under LTO once inlined). Run it on today's build: Expected: symbols > 0, plt calls > 0 (the RED).
- [ ] **Step 2: Implement** the options, the binding (try (a) first), and `--zig-lto` (requires `--zig` and `compiler eq 'zig'`, else `hardfail("--zig-lto needs --cc=zig (gcc cannot consume the LTO object)")`; adds `-flto` to `ccflags` and `ldflags` and `-Dlto=true` to `zig_build_flags`; `-Wl,-Bsymbolic-functions` only if (b) was needed).
- [ ] **Step 3: Verify**: `zig build --prefix $PWD/zig-out install -Dlto` then `tools/check-lto-binding.sh` → symbols > 0, plt calls 0, fetch_nocheck definitions 0; `zig build test -Dlto`, `zig build unit-test -Dlto`, `zig build hash-bench -Dlto -- --sizes=64,1024 --runs=3` all pass; without `-Dlto` the script's counts equal Step 1's and `nm -D`/link flags are unchanged (`zig build --verbose` link line diffed against a build from `zig-hash-engine`); Perl: `perl Configure.pl --cc=zig --zig=/usr/bin/zig --zig-lto --prefix /tmp/claude-1000/tune-prefix && make -j$(nproc)` builds and the stage0 snippet prints 1/301/299; `perl Configure.pl --zig=/usr/bin/zig --zig-lto` (gcc) exits non-zero with the message.
- [ ] **Step 4: Measure** the nqp harness and the C-API bench under `-Dlto` against the plain C engine, and against a C build with `-Dlto -Dzig-impl=false` (the C-side gain reported separately); record under "## Results" (iterate expected within noise of 1.0; C-side gain 3-8 percent).
- [ ] **Step 5: Docs and commit**: options table rows for `-Dlto` and `--zig-lto`, one paragraph on binding and the link-time cost; commit "zig build / Configure: opt-in LTO with locally bound hash exports".

---

### Task 3: Policy-layer dispatch and checks

**Files:**
- Modify: `src/zig/core/hash/table.zig` (`resolve`, `dispatch`, `rungOf`, the control-only test, the entry-offset handling for Small), `tiers/small.zig` (payload field for the cached entry base if Task 3 owns it; otherwise Task 4)
- Test: `table.zig` tests (all existing must pass), plus `single-set tables dispatch without a set comparison` as a comptime check that `Spec.sets.len == 1` takes the specialised path

- [ ] **Step 1: Measure before** (nqp and C-API, lookup_hit and delete at 64 and 1024; `--runs=5`); record the rows.
- [ ] **Step 2: Implement**: `dispatch` first tests `header.set == 0` and takes a comptime path for `Spec.sets[0]` (a single `switch` on `header.tier & ~control_only_bit` over that set's rungs, the control-only bit tested on the same byte before the switch); other set indices keep going through `resolve`. The string table's `standard` set is index 0, so every ordinary hash takes the fast path and `large_only` the general one. State this in the file comment, and add a comptime test `set 0 is the standard string set` in `str.zig` asserting `sets[0] == &standard`.
- [ ] **Step 3: Measure after**; keep if lookup_hit or delete moved outside the spread, else revert; record the row and the decision. Run `zig build unit-test` and `zig build test`.
- [ ] **Step 4: Commit** "hash engine: policy-layer dispatch specialised for set 0" (or "reverted: ..." note in the plan only).

---

### Task 4: Small tier fast paths

**Files:**
- Modify: `src/zig/core/hash/tiers/small.zig` (`tagOf`, `findIn`, `isZeroKey`, `entriesOffset`/`entryAtIndex`, `delete`'s swap)
- Test: `tiers/small.zig` tests via `zig test src/zig/core/hash/test_spec.zig`

- [ ] **Step 1: Write the failing test** `entry base survives grow`: with `IntSpec`, insert 8 keys (capacity 8), `grow` to 16, insert 8 more; every one of the 16 keys is found and `fsck == 0`; then read the new payload field `entries_offset` and assert it equals the value `entriesOffset(16)` computed from the capacity. RED: the field does not exist.
- [ ] **Step 2: Implement**: cache the entry base in the Small payload (`entries_offset: u32`, written by `init` and by `grow` for the new block) and make `entryAtIndex` add it instead of recomputing `entriesOffset(cap)`; keep the zero-key guard but only on candidates whose tag matched (the spec's "unfilled" tag idea is struck: an unfilled entry carries its real tag, because the tier never learns when the caller fills the key, so a reserved tag would make the entry unfindable); delete's swap: `if (header.entry_size == 16) copy [16]u8 else generic copy`.
- [ ] **Step 3: Measure before/after** (lookup_hit, delete at 16, 32, 63, 64; lookup_miss must not regress); keep/revert per the rule; record.
- [ ] **Step 4: Verify** `zig test src/zig/core/hash/test_spec.zig` and `zig build unit-test`, `zig build test`; commit "hash engine: Small tier entry base cached, 16-byte swap".

---

### Task 5: Robin Hood tier fast paths

**Files:**
- Modify: `src/zig/core/hash/tiers/robinhood.zig` (`loopState`, the probe loop in `fetch`/`insertInternal`/`delete`, the 16-byte paths)
- Test: existing Robin Hood tests; `perf annotate` comparison recorded in the plan

- [ ] **Step 1: Measure before** (lookup_hit, lookup_miss, delete at 128, 1024, 16384) and capture `perf annotate` of the Zig `fetch` and the C `MVM_str_hash_fetch_nocheck` loop (instruction counts per probe iteration) into "## Results".
- [ ] **Step 2: Implement** what the annotate shows: keep `LoopState` fields in locals (no reload through the header inside the loop), a comptime 16-byte entry path for the make-room and back-shift copies (the C's `sizeof(MVMHashEntry)` fast path at `str_hash_table.c:419`), and the zero-key check only after a metadata match (as the C does, where a NULL key cannot occur except in the lvalue window).
- [ ] **Step 3: Measure after**; keep/revert; record. `zig test src/zig/core/hash/test_spec.zig`, `unit-test`, `zig build test` pass.
- [ ] **Step 4: Commit** "hash engine: Robin Hood probe loop in registers, 16-byte copy paths".

---

### Task 6: The C-shaped wrapper

**Files:**
- Modify: `src/zig/core/hash/str.zig` (`keyIsValid`, `StrSpec.hash`, `StrSpec.eql`, the readers' stale check), `src/zig/moar.zig` only if a shim is missing

- [ ] **Step 1: Measure before** (lookup_hit at 64 and 1024, C-API and nqp).
- [ ] **Step 2: Implement**: `keyIsValid` as the two inline checks of `str_hash_table_funcs.h:343-348` with no out-of-line call (`moar.isConcrete` and the REPR ID compare through `moar.repr(obj).ID`); confirm `c.MVM_string_hash_code` compiles to a load and a branch on the cached value (inspect the annotate; if it calls out, implement the cached-hash fast path in Zig and call `MVM_string_compute_hash_code` only on a miss); `eql` unchanged in order (pointer, graphs, substrings) with the graphs read inlined.
- [ ] **Step 3: Measure after**; keep/revert; record; tests pass; commit "hash engine: string wrapper key validation and hash fast path inlined".

---

### Task 7: The migration

**Files:**
- Modify: `src/zig/core/hash/table.zig` (`migrate`, `migrateOp`), `tiers/robinhood.zig` (a bulk-insert entry point `insertBulk(header, ctx, entries: visitor)` or `insertKnownAbsent(header, ctx, key, h, entry_bytes)`), `tier.zig` only if the interface needs the new operation declared (optional for tiers; the policy layer uses it when present via `@hasDecl`)
- Test: `table.zig` tests

- [ ] **Step 1: Write the failing tests**: `migration target is sized for the threshold plus one` (after the 65th insert, `robinhood.officialSize == 128` and `cur_items == 65`); `bulk migration keeps every key and tolerates one unfilled entry` (insert 64 keys, take an `lvalueFetch` of a 65th key but do not fill it, then insert a 66th key through `insert`; after migration `fsck == 0`, all 65 filled keys found, the unfilled entry either carried over as unfilled or the test documents the tier's rule); `presized and shrunk hashes are not resized by the migration change` (`build(.., 200)` → rung 1 with 256 official; a hash grown to 300 then deleted to 10 keeps its block). Run: RED on the missing size assertion.
- [ ] **Step 2: Implement**: size the next rung with `init(.., next.from + 1)` instead of `2 * cur_items` (so 65 → 128 official); add `insertKnownAbsent` to Robin Hood (the probe loop without the duplicate `eql`, without the growth checks, with the entry bytes copied once) and use it from `migrateOp` when `@hasDecl(N, "insertKnownAbsent")`; keep the `drain` path otherwise. Leave the salt draw and the safepoint node unless Task 1's attribution put them above 10 percent of the migration.
- [ ] **Step 3: Measure** `insert_nth` at 65 (nqp and C-API) against the C's 97th insert; record; the expected outcome is at or below it. Keep/revert per the rule.
- [ ] **Step 4: Verify** all tests, `zig build test`; commit "hash engine: migration sized for the threshold and bulk-inserted".

---

### Task 8: Further profile rounds (bounded)

**Files:** as the attribution directs; this plan's "## Results"

- [ ] **Step 1: Re-measure the full ladder** (nqp, C-API) and compare with the finish line per op and size; if everything passes, skip to Task 9.
- [ ] **Step 2: Profile again** (Task 1 Step 3's procedure) on the operations still above the line; add at most two new lever tasks here (numbered 8a, 8b) in the same measure-implement-measure-keep/revert shape, each with its own commit, and run them. At most two rounds in total; after that, record the shortfall per op and size under "## Results" and proceed.

---

### Task 9: Whole-system check, docs, acceptance

**Files:**
- Modify: `docs/zig-build.md` ("Hash engine": the tuned ratios, the LTO options, a sentence per lever kept), this plan ("## Results" final tables, "## Deviations")

- [ ] **Step 1: Two stacks and the spectest** as the engine campaign's Task 14 did (prefixes `/tmp/claude-1000/tune-c-prefix` and `/tmp/claude-1000/tune-zig-prefix`, nqp and rakudo built against each, three timed spectest runs per engine with peak RSS, the Raku-level benchmark with both rakus via `hash-bench.sh --raku-c --raku-zig`); record the tables; no new failures; wall and RSS within 2 percent.
- [ ] **Step 2: The acceptance list** (spec §8, every item) run end to end and recorded with outcomes, including the LTO item and the gcc refusal.
- [ ] **Step 3: Docs**: update the "Hash engine" section's numbers to the tuned ones (both tiers, migration, LTO), keep the honest note for anything still above the line.
- [ ] **Step 4: Commit** inside `traces/llm` ("tuning plan: results, acceptance, deviations") and in MoarVM ("Docs and results: Zig hash engine tuning").

---

## Profile and baseline

(Task 1 fills this in: machine conditions, the baseline tables for both engines, the C 49th/97th insert costs, the attribution tables, the ranked causes, the lever order and any struck levers.)

## Results

(One row per lever: before, after, kept or reverted, reason. The LTO measurements. The final ladder. Shortfalls, if any.)

## Deviations

Record here, during execution, anything that differed from the plan or spec and why.
