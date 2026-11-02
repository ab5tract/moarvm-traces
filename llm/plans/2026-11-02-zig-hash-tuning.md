# Zig Hash Engine Tuning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Zig hash engine's default ladder to parity with the C engine at the nqp level, make the Small-to-Robin-Hood migration no more expensive than the C engine's own resize, and add opt-in LTO to both builds, every change kept only if it measurably moves its number.

**Architecture:** Measurement first: the nqp-level harness becomes the scoreboard, the C-API microbenchmark attributes, and a profile ranks the causes. Each lever is one task that changes one named thing in `src/zig/core/hash/` (policy layer, Small tier, Robin Hood tier, C-shaped wrapper, migration), measured before and after against the C engine, kept or reverted. LTO is a build option in `build.zig` and `Configure.pl` with local symbol binding of the exports. The campaign is bounded to the profile's levers plus at most two more profile rounds.

**Tech Stack:** Zig 0.16.0 (`/usr/bin/zig`), `perf` 7.2.9, nqp stage0, Perl `Configure.pl`, the existing benchmarks under `tools/bench/` and `src/zig/core/hash/bench.zig`.

**Spec:** `traces/llm/specs/2026-11-02-zig-hash-tuning-design.md` (decisions §2, facts §3, levers §4, what does not change §5, the profile §6, protocol §7, acceptance §8). The engine it tunes: `traces/llm/specs/2026-11-02-zig-hash-engine-design.md` and its plan's "Benchmark results".

## Global Constraints

- Repo root: `/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM`, branch `zig-hash-tuning` cut from `zig-hash-engine` (`a5ea2a419`). nqp stage0 at `../src/vm/moar/stage0`. `traces/` is a submodule (with `llm/` a directory inside it): edits to this plan are committed inside it, then the pointer is bumped in MoarVM.
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

### Machine conditions (every comparison in this campaign runs under these)

- CPU: AMD Ryzen 9 5900X 12-Core Processor (`lscpu`), `nproc` 24, governor `performance` (`/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`).
- Load average during the baseline runs: 0.84-0.93 (1 min; `/proc/loadavg` at start and end of each engine's runs). Linux 6.12.108-1-MANJARO.
- Zig 0.16.0. `moar` built by `zig build --prefix $PWD/zig-out install` with the defaults: `-Doptimize=ReleaseFast`, `-Dcpu=baseline`, `-Djit=true`, `-Dmimalloc=true`, `-Dzstd=true`, `-Dstatic=false`, `-Dstrip` default (stripped); the C engine with `-Dzig-impl=false`, the Zig engine with the default `-Dzig-impl=true`. Branch `zig-hash-tuning` at the Task 1 commit (engine code identical to `zig-hash-engine` `a5ea2a419`).
- nqp stage0 `../src/vm/moar/stage0`.

### Commands

    rm -f src/gen/config.h src/gen/config.c src/gen/config.o
    zig build --prefix $PWD/zig-out install -Dzig-impl=false        # C engine; later without -Dzig-impl=false for Zig
    zig-out/bin/moar --libpath=../src/vm/moar/stage0 ../src/vm/moar/stage0/nqp.moarvm tools/bench/hash-bench.nqp \
        --engine=c --sizes=4,16,32,63,64,65,128,256,1024,16384 --runs=5 --nth=all     # and --sizes=49,97 (C only)
    zig build hash-bench --prefix $PWD/zig-out -Dzig-impl=false -- --sizes=4,16,32,63,64,65,128,256,1024,16384 --runs=5 --nth=all
    tools/bench/hash-compare.pl c.tsv zig.tsv

Raw TSVs: `traces/llm/bench/tuning-baseline-{nqp,capi}-{c,zig}.tsv` and `tuning-baseline-{nqp,capi}-c-resize.tsv` (sizes 49, 97). Columns: `engine size op median mem min max`. The comparison commands for later tasks are the same, so before and after rows are like for like. `tools/bench/hash-bench.sh --nqp` runs both harnesses for both engines and renders all of them.

Cells: `ratio (zig median / c median) [zig min-max / c min-max]` over the 5 runs. Size 4 is the first size of the ladder, so its spread includes the process's warm-up (spesh and JIT) and is wide on every op. Do not use it to judge a lever.

Harness fix found while taking the baseline: as spiked, `hash-bench.nqp` timed every phase inside the single `MAIN` frame. With the C engine, `nqp::deletekey` then timed at ~30 ns at every size whenever the ladder went up to 16384, and at ~15 ns when it stopped at 4096; an isolated delete loop takes 14.8 ns. The specialisation of one timed loop depended on what had run before it. Each timed phase is now its own sub, and the C delete is ~14 ns at every size. The spike's `sorted` also compared with a bare `>`, which nqp treats as an integer compare, so medians were taken over integer-truncated orderings; it now uses `nqp::isgt_n`. The spec §3 nqp figures came from that spike harness, and the numbers below supersede them.

### Baseline: nqp level (the scoreboard)

#### insert

| size | zig / c |
|---:|---:|
| 4 | 1.78 [29.87-75.04 / 35.30-69.14] |
| 16 | 0.49 [22.82-26.37 / 49.92-54.36] |
| 32 | 0.44 [23.96-27.29 / 51.25-55.55] |
| 63 | 0.44 [23.15-26.33 / 53.94-54.88] |
| 64 | 0.38 [21.50-22.18 / 55.91-57.76] |
| 65 | 0.91 [46.56-64.38 / 50.71-55.11] |
| 128 | 0.70 [34.87-37.78 / 52.94-57.49] |
| 256 | 0.94 [48.38-56.02 / 50.79-52.74] |
| 1024 | 1.14 [57.29-58.30 / 49.44-55.32] |
| 16384 | 1.07 [57.03-84.89 / 53.04-66.02] |

#### lookup_hit

| size | zig / c |
|---:|---:|
| 4 | 1.12 [15.67-55.18 / 13.37-54.57] |
| 16 | 1.04 [15.37-17.18 / 14.26-17.68] |
| 32 | 1.09 [16.03-16.58 / 14.63-15.02] |
| 63 | 1.19 [17.18-18.94 / 14.21-14.64] |
| 64 | 1.18 [17.11-17.93 / 14.29-24.47] |
| 65 | 1.15 [16.07-20.09 / 14.63-14.81] |
| 128 | 1.21 [17.30-17.79 / 14.34-18.15] |
| 256 | 1.25 [18.01-22.82 / 14.68-14.80] |
| 1024 | 1.24 [18.15-19.69 / 14.90-15.83] |
| 16384 | 1.21 [19.93-21.41 / 16.35-17.15] |

#### lookup_miss

| size | zig / c |
|---:|---:|
| 4 | 1.43 [14.80-55.18 / 14.36-56.04] |
| 16 | 0.94 [14.32-22.61 / 14.93-15.44] |
| 32 | 1.04 [14.59-15.40 / 14.53-14.71] |
| 63 | 1.11 [15.62-16.12 / 14.15-14.37] |
| 64 | 1.16 [15.88-17.42 / 14.16-16.18] |
| 65 | 0.98 [14.14-14.50 / 14.46-14.61] |
| 128 | 1.17 [16.45-16.64 / 14.03-14.34] |
| 256 | 1.16 [16.52-16.65 / 14.23-14.55] |
| 1024 | 1.15 [16.55-17.11 / 14.32-17.97] |
| 16384 | 1.10 [17.30-24.35 / 15.38-20.10] |

#### delete

| size | zig / c |
|---:|---:|
| 4 | 1.28 [17.78-53.47 / 13.75-19.39] |
| 16 | 1.15 [16.94-17.40 / 14.33-14.87] |
| 32 | 1.22 [17.67-24.48 / 14.43-14.95] |
| 63 | 1.30 [18.32-18.76 / 14.27-14.58] |
| 64 | 1.33 [19.09-21.01 / 14.29-20.49] |
| 65 | 1.09 [15.61-17.25 / 14.26-14.63] |
| 128 | 1.19 [17.09-17.32 / 14.30-14.69] |
| 256 | 1.22 [17.36-18.18 / 14.39-14.90] |
| 1024 | 1.22 [18.04-18.67 / 14.96-15.22] |
| 16384 | 1.26 [20.35-21.52 / 16.19-17.02] |

#### iterate

| size | zig / c |
|---:|---:|
| 4 | 0.87 [16.59-53.06 / 20.58-58.54] |
| 16 | 0.77 [12.19-13.33 / 17.17-18.20] |
| 32 | 0.70 [11.84-17.02 / 16.63-18.91] |
| 63 | 0.71 [10.86-12.72 / 15.46-17.39] |
| 64 | 0.71 [11.02-11.25 / 15.38-15.78] |
| 65 | 1.16 [17.86-18.06 / 15.25-17.10] |
| 128 | 1.09 [16.49-16.85 / 15.04-15.40] |
| 256 | 1.07 [16.21-17.20 / 14.84-15.28] |
| 1024 | 1.03 [15.69-16.29 / 14.99-15.90] |
| 16384 | 1.11 [15.43-17.64 / 14.96-15.61] |

#### insert_nth

| size | zig / c |
|---:|---:|
| 4 | 0.52 [17.06-37.97 / 21.88-49.08] |
| 16 | 0.67 [17.23-17.56 / 22.12-27.76] |
| 32 | 0.55 [17.01-17.27 / 23.62-34.13] |
| 63 | 0.33 [27.46-35.09 / 89.01-97.71] |
| 64 | 0.83 [18.15-27.34 / 26.67-33.73] |
| 65 | 53.81 [1550.02-1659.36 / 26.76-35.01] |
| 128 | 1.20 [34.48-42.70 / 27.57-35.73] |
| 256 | 1.31 [36.20-58.00 / 28.69-33.03] |
| 1024 | 1.06 [38.20-75.63 / 31.47-64.97] |
| 16384 | 1.37 [62.50-85.25 / 40.00-60.25] |

### Baseline: C API (`zig build hash-bench`)

#### insert

| size | zig / c |
|---:|---:|
| 4 | 0.78 [14.43-18.75 / 18.48-20.07] |
| 16 | 0.33 [13.82-14.12 / 39.64-43.39] |
| 32 | 0.33 [14.44-17.77 / 43.88-44.92] |
| 63 | 0.34 [15.70-18.61 / 44.75-47.81] |
| 64 | 0.35 [15.54-18.83 / 44.04-46.40] |
| 65 | 0.94 [38.22-43.16 / 43.47-44.32] |
| 128 | 0.63 [25.06-28.33 / 43.82-47.71] |
| 256 | 0.91 [38.97-40.20 / 43.13-44.05] |
| 1024 | 1.19 [45.78-48.20 / 39.77-40.83] |
| 16384 | 1.17 [50.26-64.21 / 43.98-56.15] |

#### lookup_hit

| size | zig / c |
|---:|---:|
| 4 | 1.60 [10.29-10.91 / 5.32-6.66] |
| 16 | 1.52 [10.47-10.57 / 6.80-7.18] |
| 32 | 1.32 [9.34-9.78 / 7.05-7.18] |
| 63 | 1.58 [11.20-11.48 / 6.98-8.70] |
| 64 | 1.57 [11.20-11.26 / 7.03-7.79] |
| 65 | 1.16 [7.61-10.05 / 7.20-7.50] |
| 128 | 1.35 [9.44-9.70 / 7.08-7.65] |
| 256 | 1.37 [9.74-9.92 / 7.02-7.33] |
| 1024 | 1.38 [9.89-10.98 / 7.14-7.88] |
| 16384 | 1.34 [10.78-10.93 / 8.02-8.24] |

#### lookup_miss

| size | zig / c |
|---:|---:|
| 4 | 0.91 [5.75-6.52 / 6.45-6.69] |
| 16 | 0.94 [6.63-7.07 / 7.08-7.21] |
| 32 | 0.91 [6.64-6.68 / 7.23-7.28] |
| 63 | 1.13 [8.01-8.15 / 7.08-7.25] |
| 64 | 1.10 [8.00-8.09 / 7.22-7.29] |
| 65 | 0.95 [6.76-8.56 / 7.24-7.58] |
| 128 | 1.29 [9.04-9.29 / 7.06-7.18] |
| 256 | 1.28 [9.21-9.34 / 7.05-7.32] |
| 1024 | 1.30 [9.23-9.64 / 7.06-7.41] |
| 16384 | 1.28 [10.86-14.61 / 8.22-12.17] |

#### delete

| size | zig / c |
|---:|---:|
| 4 | 1.73 [13.54-14.10 / 7.04-8.10] |
| 16 | 1.66 [13.75-13.89 / 8.30-8.72] |
| 32 | 1.65 [13.51-14.18 / 8.44-8.61] |
| 63 | 1.83 [15.53-15.88 / 8.27-64.17] |
| 64 | 1.85 [15.69-15.84 / 8.40-8.52] |
| 65 | 1.01 [8.11-8.73 / 8.47-8.75] |
| 128 | 1.25 [10.39-10.52 / 8.25-10.35] |
| 256 | 1.26 [10.38-10.56 / 8.18-8.32] |
| 1024 | 1.28 [10.72-11.23 / 8.26-8.63] |
| 16384 | 1.30 [11.88-12.14 / 9.13-9.34] |

#### iterate

| size | zig / c |
|---:|---:|
| 4 | 0.76 [7.03-7.34 / 8.65-9.69] |
| 16 | 0.73 [6.45-6.49 / 8.79-8.92] |
| 32 | 0.77 [6.42-6.45 / 8.38-8.45] |
| 63 | 0.76 [6.30-6.35 / 8.21-10.44] |
| 64 | 0.76 [6.30-6.44 / 8.07-8.40] |
| 65 | 1.60 [12.77-13.14 / 8.09-8.39] |
| 128 | 1.34 [10.67-10.92 / 7.84-8.04] |
| 256 | 1.35 [10.58-10.97 / 7.91-8.11] |
| 1024 | 1.36 [10.61-10.78 / 7.75-7.91] |
| 16384 | 1.35 [10.68-10.85 / 7.87-8.38] |

#### insert_nth

| size | zig / c |
|---:|---:|
| 4 | 0.60 [8.73-9.06 / 14.93-15.55] |
| 16 | 0.63 [9.08-9.21 / 14.28-15.07] |
| 32 | 0.60 [9.40-10.39 / 15.84-16.77] |
| 63 | 0.65 [11.11-13.55 / 18.49-24.98] |
| 64 | 0.58 [10.74-13.56 / 18.90-20.38] |
| 65 | 81.04 [1486.56-1626.97 / 18.98-19.67] |
| 128 | 1.22 [23.29-24.97 / 19.37-20.61] |
| 256 | 1.29 [25.44-28.14 / 19.88-22.11] |
| 1024 | 1.25 [25.05-32.25 / 19.89-23.80] |
| 16384 | 1.40 [25.00-40.00 / 25.00-37.75] |

### The resize yardstick (decision 4)

`insert_nth` at 49 and 97 for the C engine (its resizing inserts are the 7th, 13th, 25th, 49th and 97th) against the Zig engine's 65th (the migration). Medians of 5, min-max in brackets, ns per N-th insert.

| harness | C 49th | C 97th | C 65th (ordinary) | Zig 65th (migration) | Zig 65th / C 97th |
|---|---:|---:|---:|---:|---:|
| nqp | 1014.95 [1003.57-1057.16] | 1876.13 [1643.14-2260.91] | 29.96 [26.76-35.01] | 1612.22 [1550.02-1659.36] | 0.86 |
| C API | 853.10 [846.42-1009.39] | 1972.39 [1616.52-2000.67] | 19.17 [18.98-19.67] | 1553.47 [1486.56-1626.97] | 0.79 |

The C 97th insert costs 100-200 ordinary inserts, as the spec expected. At baseline the Zig 65th insert already costs less than the C 97th on both harnesses, so the migration finish line (spec §8) is met before Task 7 runs. Task 7 stays in the plan as an improvement, not a rescue; see the lever order below.

### Attribution (from the profile recon)

Source: the profile recon on `zig-hash-spike-profile`, whose engine is `zig-hash-engine` `a5ea2a419` (the code this campaign starts from). Report: `.superpowers/sdd/2026-11-02-zig-hash-tuning/profile-report.md`. Its raw `perf` data was in a session scratchpad and was not kept. It was taken with the same C-API bench (`--ops=`, `--op-repeat=`, `--nth=all`, now in the tree) on an unstripped ReleaseFast build (now `-Dstrip=false`). The procedure is in the report's "Commands" section. Rerun it when a later round needs fresh attribution.

#### perf stat: instruction and cycle counts per operation (differentials, both engines)

`instr/op` etc. are (op-repeat 51 minus op-repeat 1) / (50 x runs x 65536) for the lookups and
(`--ops=delete` minus `--ops=none`) / (runs x 65536) for delete; they include the bench loop and the shim
call, identical for both engines. Timer figures are the bench's ns/op in the same session.

| tier / size | op | C instr | Zig instr | ratio | C cycles | Zig cycles | ratio | C br-miss | Zig br-miss | timer C ns | timer Zig ns |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Small 64 | lookup_hit | 80.0 | 170.2 | 2.13 | 33.3 | 53.1 | 1.59 | 0.50 | 0.03 | 7.07 | 11.2-11.3 |
| Small 64 | lookup_miss | 79.5 | 159.4 | 2.00 | 34.0 | 36.9 | 1.09 | 0.53 | 0.00 | 7.16 | 7.7-7.9 |
| Small 64 | delete | 111.8 | 165.4 | 1.48 | 44.7 | 69.1 | 1.55 | 0.51 | 0.04 | 9.0-9.2 | 15.6 |
| Small 64 | insert (abs, incl. grows) | 348.2 | 238.7 | 0.69 | 172.9 | 68.8 | 0.40 | 2.64 | 0.06 | 45-49 | 14-15 |
| RH 1024 | lookup_hit | 80.2 | 105.4 | 1.31 | 33.8 | 45.4 | 1.34 | 0.53 | 0.59 | 7.39 | 9.7-9.9 |
| RH 1024 | lookup_miss | 79.7 | 102.6 | 1.29 | 34.2 | 41.6 | 1.22 | 0.54 | 0.54 | 7.37 | 9.0-9.1 |
| RH 1024 | delete | 111.5 | 144.6 | 1.30 | 38.7 | 55.3 | 1.43 | 0.52 | 0.58 | 8.9-9.4 | 11.6-12.1 |
| RH 1024 | insert (abs, incl. grows) | 329.3 | 488.1 | 1.48 | 161.3 | 187.4 | 1.16 | 2.59 | 2.39 | 41-44 | 46-49 |

Reading: the Small hit executes 11 more instructions than the Small miss but takes 16 more cycles: the
stall. The RH deficits are instruction-count deficits (25-33 extra instructions, 11-16 extra cycles). The
Small tier's vector compare has no mispredictions at all (0.03/op) against the C probe loop's 0.5/op; the
Zig Small insert is 2.5x cheaper than the C's in cycles.

#### Symbol-level profiles (perf report --no-children, Zig engine)

    hit64   (Small lookup_hit)   67.9% small.find   23.4% str.fetchNocheck   3.6% bench.main   1.8% MVM_str_hash_fetch_nocheck   1.7% MVM_string_substrings_equal_nocheck   0.8% bcmp
    miss64  (Small lookup_miss)  59.4% small.find   23.9% str.fetchNocheck   5.3% bench.main   5.2% MVM_string_substrings_equal_nocheck   1.9% export   1.4% shim   1.2% MVM_string_hash_code
    hit1024 (RH lookup_hit)      74.7% ops.fetch    12.3% str.fetchNocheck   5.7% bench.main   2.8% shim   0.9% export   0.7% plt   0.6% MVM_string_hash_code   0.5% bcmp
    miss1024 (RH lookup_miss)    71.2% ops.fetch    13.5% str.fetchNocheck   5.9% bench.main   4.4% shim   1.1% export   1.1% MVM_string_hash_code
    del64 minus ins64 (Small delete, net 5984)   76.4% small.find   25.6% str.deleteNocheck   2.5% compiler_rt.memcpy   1.2% mi_free   0.15% export
    del1024 (RH delete; delete-specific symbols, 4003 samples)   82.6% ops.delete   15.8% str.deleteNocheck   1.6% export
    C engine: hit/miss 91% bench_str_fetch_nocheck (the inlined fetch) + 5% bench.main; delete: MVM_str_hash_delete_nocheck (+ memmove)

#### Attribution tables (share of Zig engine samples; the hottest source lines named)

Line numbers are the files' own. `str.zig:55` is `Spec.hash` (`return c.MVM_string_hash_code(ctx, key)`),
`str.zig:62/64` `Spec.eql`, `str.zig:192` `fetchNocheck`, `str.zig:216/217` `deleteNocheck`;
`mem.zig:1174` is `std.mem.allEqual` = `isZeroKey`; `mem.zig:257/259` `copyBackwards`; `mem.zig:243` `copyForwards`.

##### Small tier, lookup hit (size 64; 4458 samples; 11.3 ns, 170 instr, 53 cycles; C 7.1 ns, 80 instr, 33 cycles)

| stage | share | lines |
|---|---:|---|
| `find` result through memory: store-forwarding stall + call/return of `find` | **66%** | `small.zig:139` 50.2% (the epilogue `mov (%rax),%rax; mov 0x50(%rsp),%rcx` after `mov %ebp,0x38(%rsp); movb $1,0x3c(%rsp)` at :131/:139), `small.zig:148` 16.2% (`find(...) orelse` in `fetch`: the `cmpb $0,4(%rsp); je` reading that result) |
| probe/scan loop (vector compare, mask, ctz, switch on capacity) | 15.7% | `small.zig:126` 4.0%, `:137` 4.1% (tagOf + switch), `:0` 3.6%, `:129` 2.1%, `:125` 1.8%, `:128/:127` 0.1% |
| export + `str.zig` wrapper + `table.zig` dispatch (null, stale, control-only, resolve) | 7.2% | `str_exports.zig:56` 1.8%, `str.zig:192` 1.8%, `table.zig:130` 1.8%, `table.zig:111/143/445/447` ~1.8% |
| `entriesOffset`/`entryAtIndex` recomputation (`add $0x13; and $-8; imul entry_size`) in `find` and again in `fetch` | 3.7% | `small.zig:77` 1.9% (find) + 1.75% (fetch) |
| hash: call site + `moar_c.MVM_string_hash_code` (cached hash, out of line) | 2.3% | `str.zig:55` 2.3%, `moar_c.zig:16373` 0.04% |
| `Spec.eql` (ptr compare, graphs compare, `MVM_string_substrings_equal_nocheck@plt`, memcmp as `compiler_rt.bcmp`) | 3.3% | `str.zig:62-65` 0.5%, `ops.c:535/616/539` 1.75%, `compiler_rt.zig:704/705` 1.0% |
| zero-key check (8x `cmpb`) | 0.8% | `mem.zig:1174` |
| other (insert-setup residue: memset, lvalueFetchNocheck) | 0.6% | |

##### Small tier, lookup miss (size 64; 2967 samples; 7.8 ns, 159 instr, 37 cycles; C 7.2 ns, 80 instr, 34 cycles): at parity

`find` 62.9% (vector compare `small.zig:126` 21%, `:139` 9.7% (epilogue, no stall: the `null` path is one 8-byte
`movq`), `mem.zig:1174` 6.8% + `str.zig:64` 3% + `MVM_string_substrings_equal_nocheck` 5.5% (a miss key whose tag
collides, ~1 in 4 misses at 64 entries, reaches the key compare), `:137` 6%, `:0` 5.9%, `:127/128/129/125` 9%);
`fetchNocheck` 25.2% (`small.zig:148` 5.9%, `str.zig:192` 3.6%, `str.zig:0` 3%, `table.zig:111` 2.2%, `str.zig:55`
2%, `table.zig:130/447/141/143` 5.4%); export 2.1%; `MVM_string_hash_code` 1.3%.

##### Small tier, delete (size 64; 5984 net samples; 15.6 ns, 165 instr, 69 cycles; C 9.1 ns, 112 instr, 45 cycles)

| stage | share | lines |
|---|---:|---|
| `find` result stall + call/return | **52%** | `small.zig:139` 39.3%, `small.zig:164` 12.4% (`find(...) orelse return false` in `delete`) |
| probe/scan loop | 20.6% | `small.zig:126` 8.7%, `:125` 6.2%, `:129` 2.6%, `:137` 2.5%, `:0` 1.65%, `:128` 1.1%, `:127` 0.5% |
| zero-key check (8x `cmpb`) + `Spec.eql` | 13.7% | `mem.zig:1174` 11.7%, `str.zig:62` 0.9%, `substrings_equal`/`bcmp` ~1% |
| `entriesOffset`/`entryAtIndex` recomputed (once in `find`, twice in `delete`) + `entrySize` load | 6.2% | `small.zig:77` 1.6% + 2.5%, `small.zig:169` 2.1% |
| wrapper + dispatch + two stale checks (entry and "turned stale") | 7.7% | `str.zig:216` 2.8%, `str.zig:217` 1.4%, `table.zig:111` 2.0%, `table.zig:118` 0.2%, `str_exports.zig:68` 0.15%, `table.zig:498/491` ~1% |
| hash call site | 1.4% | `str.zig:55` |
| swap-remove `@memcpy` of 16 bytes through `compiler_rt.memcpy.memcpyFast` (a call) | 2.5% | `memcpy.zig:170/186` |
| other (`mi_free`, `MVM_str_hash_first` from the bench's emptiness check) | 1.5% | |

##### Robin Hood tier, lookup hit (size 1024; 3583 samples; 9.7 ns, 105 instr, 45 cycles; C 7.4 ns, 80 instr, 34 cycles)

| stage | share | lines |
|---|---:|---|
| zero-key check + first touch of the entry line (8x `cmpb` chain; the C pays the same line latency at its `cmp %r9,%r8` = 34% of its samples) | **32.6%** | `mem.zig:1174` (annotate: `jne` after the first `cmpb $0,(%rbx)` 37.8%) |
| probe loop (advance, metadata compare) | 20.1% | `robinhood.zig:261` 12.0% (`add %r12d,%ebp` back-edge 14.7%), `:292` 7.3%, `:291` 0.8% |
| `str.fetchNocheck`: prologue/epilogue (4 push + 4 pop on a path that only tail-jumps), null test, stale byte, control-only, rung `resolve` | 13.3% | `str.zig:192` 4.9%, `table.zig:143` 4.6%, `table.zig:130` 1.4%, `table.zig:111` 1.1%, `:445/:447` 1.1% (annotate: `push %r14` 19.8%, `push %rax` 16.8%, `pop %rbx/%r12` 24.8% of the function) |
| bucket computation (`loopState`: salt xor, fibonacci multiply, two variable shifts, `bts`, `imul` for `entryAtIndex`) and the `cur_items == 0` test (= first touch of the control line) | 17.3% | `robinhood.zig:281` 7.6%, `:288` 5.3% (`cmpl $0,4(%rbx)` 6.6%), `:239` 2.4%, `:273` 0.9%, `:277` 0.5%, `:141` 0.6% |
| `ops.fetch` prologue (7 pushes) + hash call site + out-of-line `MVM_string_hash_code` | 7.0% | `table.zig:163` 2.85%, `table.zig:164` 3.4%, `moar_c.zig:16373` 0.7% |
| `Spec.hash` wrapper call site | 2.6% | `str.zig:55` |
| `Spec.eql` (ptr compare, graphs; `substrings_equal` is 0% on a hit: keys are pointer-equal) | 2.0% | `str.zig:62` 1.6%, `str.zig:64` 0.4% |
| export | 0.9% | `str_exports.zig:56` |
| other (insert-setup residue, bcmp, memset) | ~3% | |

C reference (annotate of `bench_str_fetch_nocheck`, size 1024): key compare/entry touch 34.4%, loop back-edge
`add %r13d,%ebx` 12.4%, `movzbl (%r14)`+`cmp` 7.4%, hash/shift/imul ~9%, prologue/epilogue ~8%.

##### Robin Hood tier, lookup miss (size 1024; 3303 samples; 9.0 ns): same shape without the entry touch

`ops.fetch` 78.5%: probe loop `:292` 17.1%, `:262` 14.2%, `:288` 8.5%, `:281` 9.9%, `table.zig:164` 9.8% (hash
call site), `:163` 3%, `:277` 2.5%, `mem.zig:1174` 2.5%, `:239` 2.2%, `:141` 1.7%; `fetchNocheck` 14.8%
(`table.zig:143` 5.9%, `str.zig:192` 3.9%, `table.zig:130/445/447/111` 4.8%); export 1.3%; `MVM_string_hash_code` 1.3%.

##### Robin Hood tier, delete (size 1024; 4003 delete-specific samples; 11.8 ns, 145 instr, 55 cycles; C 9.2 ns, 112 instr, 39 cycles)

| stage | share | lines |
|---|---:|---|
| zero-key check + entry first touch (C: 49% of its delete samples on `cmp %r9,%r8`) | **31.6%** | `mem.zig:1174` (annotate `jne` after first `cmpb` 38.5%) |
| backward shift compiled as a byte loop (`copyBackwards(u8, ...)`: `movzbl`/`mov %r8b` x4 per iteration) | **12.7%** | `mem.zig:259` 10.4%, `mem.zig:257` 2.4% (annotate 7b6150-7b61b6 ~14%) |
| probe loop + metadata shift loop | 12.9% | `robinhood.zig:371` 4.1%, `:261` 3.25%, `:378/:379/:377` 3.3%, `:366` 1.75%, `:368/:369` 0.9% |
| `ops.delete` prologue (7 pushes + 0x28 frame, spills around the eql call) + hash call site + `loopState` | 15.8% | `robinhood.zig:0` 6.1%, `:141` 4.8% (`imul`), `table.zig:174` 3.7%, `table.zig:173` 2.1%, `:273` 1.7%, `:281` 0.8% |
| `str.deleteNocheck`: null test, stale (entry), control-only, `resolve`, "turned stale" (exit), result test | 15.8% | `table.zig:111` 4.5%, `str.zig:216` 2.3%, `str.zig:217` 2.1%, `table.zig:143` 2.0%, `table.zig:118` 1.5%, `table.zig:498` 1.3%, `:491` 1.05%, `:141` 0.7% |
| `cur_items -= 1`, `max_items == 0` repair test | 2.7% | `robinhood.zig:392` 2.2%, `:393` 0.5% |
| `Spec.eql` | 1.5% | `str.zig:62` |
| export | 1.6% | `str_exports.zig:68` |

#### The migration (65th insert, Small to Robin Hood)

Timer: 1515-1605 ns per migration (median 1558 at `--runs=15`). `perf stat` differential (size 65 minus
size 64 `insert_nth` runs, per table, `--runs=100`): **22,107 instructions, 7,334 cycles (= 1.59 µs at
4.61 GHz), 3,334 branches, 31 branch misses, 174 cache misses, 0.008 page faults.** 64 entries are drained
from the 1104-byte Small block and reinserted into a fresh 7632-byte Robin Hood block (256 official slots,
`max_items` 192, 447 allocated); ~2.7 cache misses per entry (the key object's line for `cached_hash_code`,
the old entry's line, the new entry's and metadata lines in the cold block) at ~40 cycles each account for
essentially the whole 7,334 cycles: the migration is memory-latency bound, 113 cycles per entry.

User-space breakdown from `perf record -F 20000` at `--runs=100`, size 65 minus size 64 (3869 net samples
= 1.57 µs; kernel `[unknown]` 0.6%):

| stage | share | ~ns | detail |
|---|---:|---:|---|
| reinsert loop: `robinhood.insertInternal` x65 (the 64 moved entries + the 65th key) | **46.0%** | 720 | per entry ~11 ns: `loopState` (`:272/:273/:274/:277/:281` ~12%), probe + make-room (`:311` 3.6%, `:322` 2.4%, `:339-342` 4.3%, `mem.zig:243` copyForwards 3.3%), prologue `:305` 2%, `robinhood.zig:0` 13.1%, `:239` 0.3% |
| drain side (inlined `migrateOp.visit` in `lvalueFetchNocheck`): per-entry zero-key test, `entryAtIndex`, `@memcpy` call site, the drain loop, and the retried `lvalueFetch` of the 65th key on the new block | 16.5% | 260 | `mem.zig:1174` 5.0%, `table.zig:329` 2.2%, `small.zig:77` 1.8%, `str.zig:55` 1.8%, `robinhood.zig:359/360/353` 3.0%, `small.zig:214/217` 1.2%, `table.zig:454/456` 1.3% |
| `compiler_rt.memset`: the new block's metadata clear (448 B) = first touch of the cold block | 7.7% | 120 | `compiler_rt.zig:684/686` |
| allocation of the 7632-byte block (above mimalloc's 1 KiB small-object bins, so `_mi_malloc_generic` -> page queue -> `mi_page_free_list_extend`/arena bitmap) + `__tls_get_addr` | 7.5% | 120 | `mi_malloc` 0.6%, `_mi_malloc_generic` 1.1%, `mi_bitmap_setN` 0.85%, `mi_page_queue_find_free_ex` 0.75%, `mi_page_free_list_extend` 0.7%, `_mi_page_retire` 0.7%, `mi_bbitmap_*` 0.7%, `mi_arenas_*` 1.0%, `mi_page_extend_free` 0.3%, `__tls_get_addr` 0.6% |
| `@memcpy` of each 16-byte entry through `compiler_rt.memcpy.memcpyFast` (one call per entry) | 7.0% | 110 | `memcpy.zig:170/186/0/37` |
| `MVM_string_hash_code` x65 (cached hash: one load per key object, cold lines) | 5.7% | 90 | `moar_c.zig:16373` |
| Small `find` of the 65th key before `.full` is reported (+ `bcmp`) | 3.4% | 53 | `small.zig:126/129/125/127/124`, `mem.zig:1174` |
| `initRung`: `robinhood.init/allocate` control setup, salt draw (`rng.salt`: `lock xadd` + splitmix, inlined) | 1.5% | 24 | `table.zig:143` 1.0%, rest |
| `publish`: stale flag, `freeAtSafepoint` (MVM_malloc of a 16-byte list node + CAS on the instance list), `trycas` on the slot | 1.5% | 24 | `moar.zig:145` 0.85%, `table.zig:233` 0.3% |
| `mi_free` (the list node's `MVM_malloc`'s neighbour; from `MVM_str_hash_demolish` residue) | 1.5% | 24 | `free.c:49` |
| other (`MVM_str_hash_demolish` residue 0.2%, vdso clock 0.2%, `[unknown]` 0.6%) | ~1% | | |

So: allocation + metadata clear ~240 ns (15%), reinsert loop ~720 ns (46%, 65 entries, ~11 ns each), drain
visit + entry copies ~370 ns (24%), key hash loads ~90 ns (6%), the Small lookup that discovers fullness ~50
ns (3%), salt + control init ~25 ns, free-at-safepoint node + CAS publish ~25 ns.

##### The C engine's own resize points (`insert_nth` at every size, medians of 15 runs, ns per N-th insert)

The C table starts at 8 official slots (`max_items` 6) and doubles when `cur_items >= max_items`, so the
resizing inserts are the 7th, 13th, 25th, 49th, 97th (not the 50th/98th):

| N | C ns | C alloc after | Zig ns | Zig alloc after |
|---:|---:|---:|---:|---:|
| 6 / 7 / 8 | 20.2 / **151.6** / 15.3 | 248 / 488 | (7: 9.3, 8: 9.0, **9: 59.3**) | 152 / 288 |
| 12 / 13 / 14 | 22.6 / **266.9** / 13.3 | 488 / 960 | (16: 8.9, **17: 92.8**) | 288 / 560 |
| 24 / 25 / 26 | 21.7 / **483.6** / 14.5 | 960 / 1912 | (32: 14.6, **33: 158.5**) | 560 / 1104 |
| 48 / 49 / 50 | 25.8 / **986.3** / 15.4 | 1912 / 3816 | 11.4 / 11.4 / 11.3 | 1104 |
| 63 / 64 / 65 / 66 | - / 18.3 / 18.4 / - | 3816 | 18.4 / 11.6 / **1558.1** / 16.9 | 1104 / 7632 |
| 96 / 97 / 98 / 100 | 29.4 / **1934.9** / 16.6 / 16.7 | 3816 / 7624 | 19.8 / 20.1 / 20.1 | 7632 |

`perf stat` differentials per resize (`--runs=100`): C 96->97: 21,378 instr, 11,348 cycles, 158 cache misses,
149 branch misses (timer 1.92 µs); C 48->49: 11,299 instr, 5,263 cycles, 111 misses (0.99 µs); C 24->25:
6,262 / 3,297 (0.51 µs); C 12->13: 3,627 / 1,818 (0.29 µs). Zig 64->65: 22,107 / 7,334 / 174 (1.57 µs);
Zig 32->33 (Small grow): 1,645 / 746 (0.157 µs); 16->17: 1,313 / 561 (0.094 µs). Per reinserted entry the
two engines' doublings cost the same (~115 cycles); the C's 97th insert reinserts 96 entries in 1.93 µs, the
Zig migration 64 in 1.56 µs. Cumulative resize cost to reach 65 entries: C 1.89 µs (7+13+25+49), Zig 1.87 µs
(9+17+33 Small grows 0.31 µs + the migration); to reach 193 entries: C 3.82 µs, Zig 1.87 µs.

#### Ranked causes, with the estimated share of each tier's deficit

Deficits (cycles/op, Zig minus C, from perf stat): Small hit +20, Small delete +24, RH hit +11, RH miss +7,
RH delete +16. Shares are estimates from the sample attribution and the hit-versus-miss cycle gap.

**Small tier lookup hit (+20 cycles)**
1. ~75-80%: the `?u32` return of `small.find` through memory, stored as u32 + bool and reloaded as one 8-byte
   word (`small.zig:131/139` -> `:148`): a store-to-load forwarding stall of ~15 cycles on every hit (the miss
   path stores one 8-byte zero and is at parity). Change: make `find` return in registers, i.e. mark it
   `inline` (or return the entry pointer / `maxInt(u32)` as the not-found sentinel instead of an optional).
2. ~10-15%: the out-of-line chain and its register traffic: export -> `str.fetchNocheck` (4 saves) ->
   `MVM_string_hash_code` call -> `find` (6 saves + 0x58 frame), plus `entriesOffset` recomputed in `find`
   and again in `fetch` (`small.zig:77`, `add $0x13; and; imul`). Change: inline the chain into the export
   (Zig `inline fn` on `str.fetchNocheck`, `Table.fetch`, `dispatch`, `ops.*`, `Spec.hash`), hoist the entries
   offset (or pointer) into the Small payload next to `capacity`.
3. ~5%: `isZeroKey` as eight byte compares (`mem.zig:1174`) and `Spec.eql`'s graphs compare before the pointer
   test short-circuits. Change: read the key as one `u64` (`std.mem.readInt`/`@bitCast`) or drop the zero-key
   test from lookups (the C has none: callers fill the key before any lookup; keep it in the migration drain).
4. ~5%: null + volatile stale + control-only + rung-resolve tests in `fetchNocheck` (`table.zig:111/130/143`).
   Change: encode stale/control-only/rung in one byte and test it once.

**Small tier delete (+24 cycles)**
1. ~55-60%: the same `find` stall (`small.zig:139` 39%, `:164` 12%). Same change as above.
2. ~15%: zero-key byte chain (`mem.zig:1174` 12%) + `entriesOffset` recomputed three times and `entrySize`
   reloaded (`small.zig:77` x2, `:169`). Same changes as Small hit 2-3.
3. ~12%: wrapper + two stale checks (`table.zig:111/118`, `str.zig:216/217`) + out-of-line hash call. Inline;
   one combined status byte; drop the exit "turned stale" check from `delete` or make it a single byte test.
4. ~5%: the 16-byte swap-remove through a `compiler_rt.memcpy` call (`memcpy.zig:170`). Change: copy
   `entry_size / 8` words inline (entry sizes are multiples of 8), or special-case `entry_size == 16`.

**Robin Hood lookup hit (+11 cycles) and miss (+7)**
1. ~50%: three call levels and their prologues/epilogues: `str.fetchNocheck` saves and restores four registers
   only to tail-jump (its push/pop lines are 65% of its 13% share), `ops.fetch__anon` saves seven, and
   `MVM_string_hash_code` is a 14-byte out-of-line translate-c function (`table.zig:163/164`, `str.zig:55`,
   `moar_c.zig:16373`): ~25 of the 25 extra instructions. Change: `inline` the policy layer (`Table.fetch`,
   `dispatch`/`resolve`, `ops.fetch`) and `Spec.hash` into the export so the export is one function as the C
   inline is; write `Spec.hash` as a Zig inline reading `cached_hash_code` and calling
   `MVM_string_compute_hash_code` only on zero.
2. ~20%: `isZeroKey` as 8 `cmpb/jne` before the key compare (`mem.zig:1174`; the first compare also carries the
   entry line's latency, which the C pays at its single `cmp`). Change: one `u64` load, or no zero-key test on
   the lookup path.
3. ~15%: the dispatch tests (`table.zig:111/130/143`, 7%) and `cur_items == 0` (`robinhood.zig:288`, the C has
   the same `is_empty` test; 5%). Change: one status byte; let the sentinel handle an empty table.
4. ~10%: `loopState`'s extra arithmetic (`idealBucket` via `key_right_shift + metadata_hash_bits`, the
   `(bucket + 1) * entry_size` `imul` in `entryAtIndex`, `robinhood.zig:141/277/281`). Change: store a
   `bucket_right_shift` and an entries base pointer in the control block as the C does.

**Robin Hood delete (+16 cycles)**
1. ~40%: `std.mem.copyBackwards(u8, ...)` for the backward shift compiles to a byte loop (`mem.zig:257/259`,
   13% of delete samples; 16 iterations per shifted 16-byte entry) where the C calls `memmove`
   (`str_hash_table.c:600-620`). Change: shift with `@memmove` on the byte slice (Zig 0.16) or copy
   entry-sized `u64` words; same for `copyForwards` in `insertInternal` (`mem.zig:243`, 3% of the migration).
2. ~25%: the call chain (`ops.delete` 7 pushes + 0x28 frame + spills around the `eql` call, `table.zig:173/174`,
   `str.zig:216/217`, export) and the out-of-line hash call. Change: as RH lookup 1.
3. ~15%: zero-key byte chain (`mem.zig:1174`). As RH lookup 2.
4. ~15%: two volatile stale checks + control-only + `resolve` + result test (`table.zig:111/118/143/491/498`,
   15.8% of delete samples in `deleteNocheck`). Change: one status byte, checked once.
5. ~5%: `entryAtIndex` `imul` in `loopState` (`robinhood.zig:141`, 4.8%). As RH lookup 4.

**Migration (not a deficit against a C operation of the same kind; 1.56 µs vs the C's 1.93 µs at its own
64->128 doubling)**: 46% reinsert loop (65 x `insertInternal`, memory-latency bound), 24% drain visit + per-entry
`compiler_rt.memcpy` call + zero-key test, 15% allocation + metadata clear of the cold block, 6% key hash loads.
Changes that would trim it: copy entries inline (entry_size is a multiple of 8) instead of a `memcpy` call per
entry (~7%); skip the per-entry zero-key `allEqual` in `visit` (~5%); pick the next rung's size from
`cur_items` so a 65-entry table lands in 128 official slots (7632 -> 3816 bytes, fewer cold lines, ~10%) at the
price of resizing again at 97 as the C does; none of these changes the ~115 cycles per entry that both
engines pay for touching each key object and its old and new entry lines.

### Lever order (Tasks 3-7)

Deficits per operation from the `perf stat` table, in cycles, Zig minus C: Small hit +20, Small delete +24, RH hit +11, RH miss +7, RH delete +16. For each lever, the estimated cycles it removes = Σ(share of the cause it addresses × that deficit), taken from the ranked causes above. Nothing is struck: every lever addresses a cause the profile measured well above zero.

| order | task | causes it addresses (report rank) | share of each deficit | ~cycles of the 78 |
|---:|---|---|---|---:|
| 1 | **Task 4: Small tier fast paths** | `find`'s `?u32` return through memory (store-forwarding stall) (Small hit 1, delete 1); `entriesOffset` recomputation (hit 2, part; delete 2); `isZeroKey` byte chain on the Small path (hit 3, delete 2); the 16-byte swap through a `memcpy` call (delete 4) | Small hit ~85%, Small delete ~80% | ~36 |
| 2 | **Task 6: the C-shaped wrapper** | the three-level call chain: export → `str.fetchNocheck`/`deleteNocheck` (saves and restores registers only to tail-jump) → generic `ops.fetch`/`ops.delete` (7 saves), and the out-of-line `MVM_string_hash_code` (RH hit/miss 1, RH delete 2, Small hit 2, part; Small delete 3, part) | RH hit/miss ~50%, RH delete ~25%, Small hit ~12%, Small delete ~6% | ~17 |
| 3 | **Task 5: Robin Hood tier fast paths** | `copyBackwards(u8, ..)` compiled to a byte loop in the backward shift (RH delete 1); `isZeroKey` byte chain in the probe loop (RH hit/miss 2, RH delete 3); `loopState` arithmetic (RH hit/miss 4, RH delete 5); also `copyForwards` in `insertInternal` (3% of the migration) | RH delete ~60%, RH hit/miss ~30% | ~15 |
| 4 | **Task 3: policy-layer dispatch and checks** | null, volatile stale, control-only, `resolve`, the exit "turned stale" check (Small hit 4, Small delete 3, part; RH hit/miss 3; RH delete 4) | RH hit/miss ~15%, RH delete ~15%, Small hit ~5%, Small delete ~6% | ~7.5 |
| 5 | **Task 7: the migration** | 128-slot sizing (~10% of the migration), a bulk insert skipping the duplicate and growth checks (part of the 46% reinsert loop), inline entry copies instead of a `memcpy` call each (~7%), no per-entry zero-key test in the drain (~5%) | migration ~20-30% (estimate); not part of the per-op deficit | 0 of 78; ~0.3-0.5 µs of 1.56 µs |

Why this order:
- Task 4 removes the largest single cost in the campaign: the Small-tier stall is ~15 cycles on every hit and every delete.
- Task 6 comes before Task 5 because the call chain is the largest Robin Hood lookup cause. Removing it first also lets Task 5 read the probe loop's annotate without the prologue and epilogue noise.
- Task 3's status-byte checks are smaller, and once the chain is inlined they sit in one function, which is the shape Task 3's change needs.
- Task 7 is last because its finish line is already met (see the yardstick above).
- Task 2 (LTO) is not a lever in this order and runs where the plan puts it.

Each task's scope grows to take the cause the profile assigns it. These extensions are recorded under "## Deviations":
- Task 4 also changes `find`'s return (inline it, or return a sentinel index instead of `?u32`), and reads the zero key as one `u64` or drops the test on lookups.
- Task 6 also marks `inline` on `str.fetchNocheck`/`deleteNocheck`, `Table.fetch`/`delete`, `dispatch`/`resolve`, `ops.*` and `Spec.hash`, so each export compiles to one function as the C inline does.
- Task 5 also replaces `copyBackwards`/`copyForwards` with `@memmove`, or with word copies for 16-byte entries.

The shares are the report's estimates. Each task's own before/after measurement decides whether its lever is kept.

## Results

(One row per lever: before, after, kept or reverted, reason. The LTO measurements. The final ladder. Shortfalls, if any.)

Task 1: baseline and attribution are under "## Profile and baseline". No lever was struck. Run order: 4, 6, 5, 3, 7.

### Task 2: LTO opt-in (`-Dlto`, `--zig-lto`)

Binding: option (a), protected visibility, engaged and was kept; (b) `-Bsymbolic-functions` and (c) hidden were not needed. The exports are `fn ... callconv(.c)` plus `@export(.., .{ .visibility = v })` where `v` is `.protected` under `-Dlto` and `.default` otherwise (a `zig_options` module on the `moar_zig` root carries the flag). Without `-Dlto` the build is today's: the libmoar and moar link commands from `zig build --verbose` are identical, argument for argument, to a build of `zig-hash-engine`. The `moar_zig` command gains only the `zig_options` module. `nm -D` is identical and `tools/check-lto-binding.sh` reports the same counts. The Perl Makefiles from `--zig`, `--cc=zig --zig`, `--cc=zig` and the default configure are identical to those from the Task 1 `Configure.pl`.

`tools/check-lto-binding.sh zig-out/lib/libmoar.so` (dynamic `MVM_str_hash_` symbols / `@plt` calls to `MVM_str_hash_` / definitions of `MVM_str_hash_fetch_nocheck` / call sites of it):

| build | dyn | plt | defs | call sites |
|---|---:|---:|---:|---:|
| Zig (default) | 22 | 119 | 1 | 3 |
| Zig `-Dlto` (protected) | 22 | 0 | 1 | 0 |
| C `-Dzig-impl=false` | 6 | 27 | 0 | 0 |
| C `-Dzig-impl=false -Dlto` | 6 | 25 | 0 | 0 |
| Perl `--cc=zig --zig --zig-lto` | 22 | 0 | 1 | 0 |

The `fetch_nocheck` definition stays because it is exported; that is what keeps the shim and `hash-str-test` linking. An unstripped `-Dlto -Dstrip=false` build shows zero call or jump sites to `fetch_nocheck`, `fetch`, `delete`, `lvalue_fetch`, `next`, `current_nocheck` and `count`, the same set the spike's hidden+LTO build inlined. The calls left are 5 `build`, 2 `demolish`, 11 `first`, 3 `insert_nocheck` and 1 `shallow_copy`. Build time for `zig build install` goes from 19 s to 59 s for Zig and from 35 s to 55 s for C.

Measurements were taken under the machine conditions above. Load average was 2.0-2.9 at the start of the runs, higher than the baseline's 0.9, because the same script built each variant just before benchmarking it; 5.0 at the start of C. Runs: `--sizes=16,32,63,64,65,128,256,1024,16384 --runs=5 --nth=all`. TSVs: `traces/llm/bench/tuning-lto-{nqp,capi}-{c,c-lto,zig,zig-lto}.tsv`. Size 16 is the first size of this ladder and carries the warm-up, like size 4 did in the baseline (C+LTO lookup at 16 is 3.24), so it is not read.

nqp level, ratio of medians (cells: Zig+LTO / C | C+LTO / C | Zig / C | Zig+LTO / C+LTO):

| op | 32 | 63 | 64 | 65 | 128 | 256 | 1024 | 16384 |
|---|---|---|---|---|---|---|---|---|
| insert | 0.44 / 0.96 / 0.50 / 0.46 | 0.46 / 0.97 / 0.52 / 0.47 | 0.45 / 0.97 / 0.51 / 0.47 | 0.88 / 0.96 / 0.95 / 0.92 | 0.69 / 0.98 / 0.77 / 0.71 | 0.87 / 0.96 / 0.98 / 0.91 | 1.11 / 0.96 / 1.19 / 1.16 | 1.01 / 0.89 / 1.08 / 1.14 |
| lookup_hit | 1.00 / 0.94 / 1.06 / 1.06 | 1.09 / 0.90 / 1.16 / 1.21 | 1.08 / 0.91 / 1.15 / 1.20 | 0.92 / 0.90 / 1.00 / 1.02 | 1.08 / 0.96 / 1.15 / 1.13 | 1.09 / 0.95 / 1.18 / 1.15 | 1.08 / 0.93 / 1.11 / 1.16 | 1.12 / 0.94 / 1.16 / 1.18 |
| lookup_miss | 0.90 / 0.93 / 1.02 / 0.97 | 0.99 / 0.89 / 1.09 / 1.11 | 0.99 / 0.91 / 1.04 / 1.10 | 0.85 / 0.91 / 0.92 / 0.93 | 1.04 / 0.94 / 1.13 / 1.11 | 1.05 / 0.93 / 1.12 / 1.13 | 1.06 / 0.95 / 1.13 / 1.11 | 1.04 / 0.93 / 1.12 / 1.12 |
| delete | 1.12 / 0.93 / 1.19 / 1.21 | 1.15 / 0.87 / 1.26 / 1.32 | 1.14 / 0.89 / 1.22 / 1.28 | 0.90 / 0.88 / 0.98 / 1.02 | 1.07 / 0.94 / 1.15 / 1.13 | 1.06 / 0.97 / 1.16 / 1.09 | 1.06 / 0.94 / 1.15 / 1.12 | 1.10 / 0.96 / 1.22 / 1.14 |
| iterate | 0.61 / 1.10 / 0.71 / 0.56 | 0.62 / 0.93 / 0.65 / 0.67 | 0.61 / 0.95 / 0.71 / 0.64 | 1.11 / 0.95 / 1.17 / 1.17 | 0.97 / 0.96 / 1.04 / 1.01 | 0.97 / 0.97 / 1.03 / 1.00 | 0.97 / 0.96 / 1.02 / 1.01 | 0.98 / 0.96 / 1.05 / 1.02 |
| insert_nth | 0.66 / 1.14 / 0.81 / 0.58 | 0.75 / 0.89 / 0.75 / 0.84 | 0.72 / 0.92 / 0.96 / 0.78 | 54.4 / 0.93 / 51.3 / 58.8 | 1.09 / 0.92 / 1.23 / 1.18 | 1.10 / 0.93 / 1.28 / 1.19 | 1.00 / 0.91 / 1.17 / 1.10 | 0.85 / 1.00 / 1.21 / 0.85 |


The cells that the parity and C-side gain judgements rest on, with the spread (`ratio [compared min-max / base min-max]` in ns over the 5 runs, as in the baseline tables). Rows: Robin Hood iterate for Zig+LTO / C, Zig+LTO / C+LTO and Zig / C, then C+LTO / C for every op:

| row | 32 | 63 | 64 | 65 | 128 | 256 | 1024 | 16384 |
|---|---|---|---|---|---|---|---|---|
| zig-lto / c iterate | 0.61 [10.07-10.78 / 16.37-18.93] | 0.62 [9.76-12.00 / 16.07-16.30] | 0.61 [9.67-9.79 / 15.99-16.18] | 1.11 [17.50-18.08 / 15.79-16.02] | 0.97 [14.90-15.50 / 15.37-15.64] | 0.97 [14.72-15.55 / 15.19-15.30] | 0.97 [14.57-15.40 / 15.17-15.53] | 0.98 [14.43-14.83 / 14.76-15.03] |
| zig-lto / c-lto iterate | 0.56 [10.07-10.78 / 16.13-18.63] | 0.67 [9.76-12.00 / 15.06-15.21] | 0.64 [9.67-9.79 / 15.21-15.41] | 1.17 [17.50-18.08 / 15.11-15.24] | 1.01 [14.90-15.50 / 14.80-14.94] | 1.00 [14.72-15.55 / 14.59-14.78] | 1.01 [14.57-15.40 / 14.54-14.84] | 1.02 [14.43-14.83 / 14.33-15.31] |
| zig / c iterate | 0.71 [11.65-11.86 / 16.37-18.93] | 0.65 [10.30-11.73 / 16.07-16.30] | 0.71 [10.93-13.36 / 15.99-16.18] | 1.17 [18.42-18.65 / 15.79-16.02] | 1.04 [16.04-16.24 / 15.37-15.64] | 1.03 [15.57-15.88 / 15.19-15.30] | 1.02 [15.56-15.68 / 15.17-15.53] | 1.05 [15.34-15.81 / 14.76-15.03] |
| c-lto / c insert | 0.96 [50.31-53.60 / 52.03-55.61] | 0.97 [52.21-53.64 / 53.87-55.03] | 0.97 [52.53-53.61 / 52.44-57.73] | 0.96 [50.10-53.61 / 52.10-55.70] | 0.98 [51.57-56.48 / 53.21-54.44] | 0.96 [48.29-52.51 / 49.68-54.91] | 0.96 [48.10-53.06 / 50.72-53.19] | 0.89 [51.04-74.30 / 52.61-75.19] |
| c-lto / c lookup_hit | 0.94 [13.81-14.09 / 14.69-15.13] | 0.90 [13.58-13.91 / 15.06-15.49] | 0.91 [13.85-13.94 / 15.11-15.87] | 0.90 [13.93-14.12 / 15.16-15.80] | 0.96 [13.76-13.94 / 14.38-14.83] | 0.95 [13.76-14.62 / 14.57-15.37] | 0.93 [14.18-14.81 / 14.87-16.08] | 0.94 [15.35-15.62 / 16.37-16.65] |
| c-lto / c lookup_miss | 0.93 [13.38-13.76 / 14.46-14.84] | 0.89 [13.06-13.36 / 14.69-14.80] | 0.91 [13.45-13.65 / 14.85-15.03] | 0.91 [13.56-13.71 / 14.93-15.03] | 0.94 [13.34-13.62 / 14.24-14.44] | 0.93 [13.36-13.57 / 14.22-14.53] | 0.95 [13.44-13.91 / 14.27-15.48] | 0.93 [14.39-19.05 / 15.41-20.64] |
| c-lto / c delete | 0.93 [13.71-14.16 / 14.87-15.15] | 0.87 [13.67-14.00 / 15.63-15.81] | 0.89 [13.86-14.13 / 15.73-16.02] | 0.88 [13.88-14.23 / 15.81-16.00] | 0.94 [13.78-13.87 / 14.55-14.81] | 0.97 [13.91-14.28 / 14.40-14.82] | 0.94 [14.17-14.58 / 15.09-15.68] | 0.96 [15.78-17.00 / 16.44-16.62] |
| c-lto / c iterate | 1.10 [16.13-18.63 / 16.37-18.93] | 0.93 [15.06-15.21 / 16.07-16.30] | 0.95 [15.21-15.41 / 15.99-16.18] | 0.95 [15.11-15.24 / 15.79-16.02] | 0.96 [14.80-14.94 / 15.37-15.64] | 0.97 [14.59-14.78 / 15.19-15.30] | 0.96 [14.54-14.84 / 15.17-15.53] | 0.96 [14.33-15.31 / 14.76-15.03] |
| c-lto / c insert_nth | 1.14 [23.03-32.59 / 23.99-34.88] | 0.89 [24.83-25.66 / 26.18-35.84] | 0.92 [26.32-32.45 / 28.29-33.91] | 0.93 [25.67-31.17 / 27.65-31.64] | 0.92 [27.00-30.21 / 28.79-31.82] | 0.93 [28.92-30.29 / 31.23-36.91] | 0.91 [31.63-38.50 / 31.16-54.17] | 1.00 [37.50-90.25 / 42.50-62.75] |

- Hash gain. Robin Hood iterate, Zig+LTO against C, is 0.97-0.98 at 128-16384 (Zig without LTO: 1.02-1.05). Against the matched C+LTO it is 1.00-1.02, which is parity, as the spike found: the Zig+LTO spreads (14.43-15.55 ns) overlap the C+LTO spreads (14.33-15.31 ns) at every size from 128 up. Lookup and delete improve by the C-side gain plus about 0.03-0.08. Against C+LTO, lookup_hit is 1.13-1.18, lookup_miss 1.11-1.13 and delete 1.09-1.14 at 128 and up, so the deficit inside the engine is unchanged (Tasks 3-7). At 65 (just migrated) and in the Small tier, insert and iterate gain a further 0.04-0.10.
- C-side gain. C+LTO against C at 63-16384 is 0.87-0.98 on the five main ops: insert 0.89-0.98, lookup_hit 0.90-0.96, lookup_miss 0.89-0.95, delete 0.87-0.97, iterate 0.93-0.97. That is 2-13 percent, and the spike measured 3-8 percent. On lookup and delete the C+LTO spread lies wholly below the C spread at every size except three, where the spreads overlap: lookup_hit 256, lookup_miss 16384 and delete 16384. The insert spreads overlap at most sizes; at 16384 the 0.89 has a wide spread on both sides (51-74 / 53-75 ns). insert_nth is 0.89-1.00 at 63-16384. At 32, iterate (1.10) and insert_nth (1.14) are the exceptions. Their C+LTO spreads (16.13-18.63 and 23.03-32.59 ns) overlap the C spreads, so they are noise at the second size of the ladder, not a loss. This gain comes from LTO itself, not from the hash engine.
- C API (`zig build hash-bench`): Zig+LTO is no better than Zig. RH lookup_hit is 1.23-1.31 against 1.21-1.32; iterate is 1.30-1.39 against 1.24-1.31, a few percent worse, and C+LTO against C is 0.92-1.07. That is expected: the shim calls libmoar's exports from outside the DSO in every variant, so LTO cannot inline across that boundary.
- Zig without `-Dlto` against the Task 1 Zig baseline: every op at 32-16384 is within 0.89-1.07, except insert at 32-64 (1.15-1.27). The Zig/C ratio for insert at 32-64 is 0.50-0.52 here against 0.38-0.44 in the baseline, and the C insert is 0.95-1.01 of its baseline. This is in the run-to-run band of the Small insert (the baseline's ladder started at 4, this one at 16). Task 4 re-measures it.
- Kept. `-Dlto` stays off by default.

### Task 4: Small tier fast paths (kept)

Changes in `tiers/small.zig`, all kept, measured as one lever because the whole moved well outside the spread:

- `find` returns a plain `u32` with `absent = maxInt(u32)` instead of `?u32`. The result now comes back in `%eax` and the caller tests `cmp $0xffffffff,%eax` (unstripped `-Dstrip=false` build, `objdump` of `str.fetchNocheck`), so the store-to-load forwarding stall of the 4-byte value plus 1-byte flag reloaded as 8 bytes is gone. `find` shrank from 1530 to 1088 bytes.
- The Small payload is now `{ capacity: u32, entries_offset: u32 }` (8 bytes; `tags` start at 16 instead of 12, which leaves `entriesOffset` unchanged for every capacity 8-64). `init` and `grow` write `entries_offset`; `entryAtIndex` adds it. `findIn` loads the entry base and the entry size once, before the scan.
- `isZeroKey` is one unsigned load and compare of the key (`u64` for the 8-byte keys) instead of `std.mem.allEqual`'s byte chain. It still runs only on tag-matched candidates.
- Delete's swap: `if (es == 16)` copies `[16]u8` inline (one `movups` pair), else `@memcpy` (still `compiler_rt.memcpy` for other sizes).

A variant that kept the per-candidate `entryAtIndex` (no hoisting of the base and size in `findIn`) was also tried: C-API lookup_hit at 63/64 was 8.6 ns against 7.4-7.8 ns with the hoist, so the hoist stays.

Runs: `--sizes=16,32,63,64 --runs=5`, both harnesses, C engine before (HEAD `eec1ca260`) and after (same C code, rebuilt to bracket drift). Load average (1 min) at the start of each run: Zig before 2.08, C before 2.52, Zig after 1.23 (first run) and 1.71 (the recorded one), C after 1.71 (`traces/llm/bench/tuning-t4-load.log`). TSVs: `traces/llm/bench/tuning-t4-{capi,nqp}-{c,zig}-{before,after}.tsv`. Size 16 is the ladder's first size and carries the warm-up at the nqp level, so it is not read there. Cells: `zig / c [zig min-max / c min-max]` in ns; before against C before, after against C after.

C API:

| op | size | before | after |
|---|---:|---|---|
| lookup_hit | 16 | 1.51 [10.69-10.99 / 7.05-16.98] | 0.97 [6.53-7.75 / 6.96-7.15] |
| lookup_hit | 32 | 1.45 [10.81-11.84 / 7.26-7.73] | 0.94 [6.48-8.35 / 7.43-12.65] |
| lookup_hit | 63 | 1.57 [11.18-11.54 / 7.07-7.29] | 1.07 [7.40-7.61 / 6.88-8.44] |
| lookup_hit | 64 | 1.57 [11.27-11.56 / 7.18-7.21] | 1.10 [7.78-7.79 / 7.01-7.15] |
| lookup_miss | 16 | 0.97 [6.71-7.23 / 7.13-7.53] | 0.85 [6.19-6.39 / 7.31-7.41] |
| lookup_miss | 32 | 0.89 [6.65-6.88 / 7.29-7.64] | 0.95 [6.47-7.60 / 7.44-7.74] |
| lookup_miss | 63 | 1.14 [7.98-8.24 / 7.13-7.19] | 1.08 [7.64-7.93 / 7.06-7.18] |
| lookup_miss | 64 | 1.12 [8.03-8.14 / 7.14-7.29] | 1.07 [7.71-7.81 / 7.20-7.32] |
| delete | 16 | 1.71 [13.76-32.77 / 8.09-10.65] | 0.98 [8.32-11.16 / 8.51-8.63] |
| delete | 32 | 1.67 [14.41-15.72 / 8.67-8.99] | 1.04 [9.22-10.56 / 8.95-9.29] |
| delete | 63 | 1.84 [15.24-15.63 / 8.33-8.57] | 1.24 [10.24-11.47 / 8.18-8.42] |
| delete | 64 | 1.81 [15.27-15.55 / 8.41-8.57] | 1.28 [10.42-10.67 / 8.30-8.51] |

nqp level:

| op | size | before | after |
|---|---:|---|---|
| lookup_hit | 32 | 1.12 [16.54-16.69 / 14.76-14.88] | 0.96 [14.15-14.43 / 14.68-15.01] |
| lookup_hit | 63 | 1.23 [17.77-17.99 / 14.48-15.59] | 1.09 [15.37-15.68 / 14.30-15.35] |
| lookup_hit | 64 | 1.22 [17.61-17.91 / 14.43-14.67] | 1.10 [15.61-16.11 / 14.35-14.94] |
| lookup_miss | 32 | 0.97 [14.23-14.34 / 14.58-14.74] | 0.97 [14.08-14.20 / 14.39-14.71] |
| lookup_miss | 63 | 1.11 [15.64-15.89 / 14.20-14.33] | 1.13 [15.76-16.07 / 13.91-14.28] |
| lookup_miss | 64 | 1.09 [15.69-15.96 / 14.37-17.16] | 1.15 [15.69-16.56 / 14.10-14.49] |
| delete | 32 | 1.21 [17.78-17.97 / 14.49-14.97] | 0.94 [13.89-14.23 / 14.60-14.89] |
| delete | 63 | 1.31 [18.78-19.06 / 14.43-14.76] | 1.08 [15.38-15.71 / 14.12-14.51] |
| delete | 64 | 1.30 [18.84-19.18 / 14.47-14.58] | 1.10 [15.43-16.01 / 14.30-14.67] |

- Kept. lookup_hit and delete moved outside the spread at both levels and every size 16-64: at the C API, lookup_hit went from 1.45-1.57 to 0.94-1.10 and delete from 1.67-1.84 to 0.98-1.28; at the nqp level (32-64), lookup_hit went from 1.12-1.23 to 0.96-1.10 and delete from 1.21-1.31 to 0.94-1.10.
- lookup_miss did not regress. At the C API it improved at 63/64 (7.64-7.93 against 7.98-8.24 ns, outside the spread). At the nqp level the Zig spreads overlap before and after at 63 and 64 (the 64 ratio moves from 1.09 to 1.15: the Zig median rose from 15.77 to 16.33 ns and the C median fell from 14.42 to 14.23 ns, so the move is mostly on the Zig side, and it lies inside the overlapping Zig spreads, 15.69-15.96 before and 15.69-16.56 after). Three more nqp runs of each build gave HEAD 14.0-15.4 / 15.6-16.4 / 15.7-16.2 ns and the change 15.0-15.3 / 15.4-16.3 / 16.1-16.6 ns at 32 / 63 / 64. That is the run-to-run band of the nqp miss.
- What is left at 63/64 (lookup_hit 1.07-1.10, delete 1.24-1.28 at the C API) is the call chain, the wrapper and stale checks, and the hash call (Task 6), plus the out-of-line `find` call.

### Task 5: Robin Hood tier fast paths (kept)

Changes in `tiers/robinhood.zig`, all kept, measured as one lever because the whole moved outside the spread on lookup_hit and delete at the C API and on delete at the nqp level:

- `isZeroKey` is one unsigned load and compare of the key bytes (`KeyBits`, `u64` for the pointer keys), not `std.mem.allEqual`'s byte chain. It still runs only after a metadata match (and in `grow`/`fsck`). The compiler now reuses that load for the key compare: `mov (%rbx),%rsi; test %rsi,%rsi; je; cmp %rsi,%r14`, where before it was `cmpb $0,(%rbx); jne` (up to eight times) followed by a second load of the key.
- The make-room (`insertInternal`) and back-shift (`delete`) copies are `shiftDown`/`shiftUp`. For `entry_size == 16` they copy 16 bytes per entry inline (`movups` pairs), walking a pointer from `ls.entry`. Other sizes use `@memmove` (`compiler_rt.memmove`, as the C calls `memmove`). The test is a runtime branch only for the string table (runtime entry size). The comptime-sized single-rung tables fold it: `ptr` and `uni` (16 bytes) have inline copies only, `index` and `fixkey` (8 bytes) have a `memmove` call only. The byte loops (`copyForwards`/`copyBackwards(u8)`) are gone from every instantiation.
- `growInner`'s per-entry copy is `copyEntry`: an inline 16-byte copy when `entry_size == 16`, otherwise `@memcpy`. This is the C's `sizeof(MVMHashEntry)` fast path (`str_hash_table.c:419`).
- Loop state: not changed. Since Task 6 the probe loops keep every `LoopState` field in registers, and nothing is reloaded through the header in the loop (annotate below). The profile's reloads were in the out-of-line `ops.fetch` that Task 6 removed.
- A first form of the shift, `moveEntries(dest, src, n)` with indexed `d[i] = s[i]` copies, was discarded before it was benchmarked. LLVM strength-reduced the copy addresses into the delete probe loop: 12 instructions per probe iteration, two of them read-modify-writes of stack slots (`addq $0x1,0x38(%rsp)`). The pointer walk from `ls.entry` keeps the delete probe at 9.

Annotate (`-Dstrip=false`, `perf record -F 20000` of `hash-bench --sizes=1024 --runs=400`, `perf annotate --no-source`). Instructions per probe iteration that does not match the metadata, then the path from a metadata match to the key compare:

| loop | C | Zig before | Zig after |
|---|---|---|---|
| fetch probe (`MVM_str_hash_fetch_nocheck` / C `bench_str_fetch_nocheck`) | 7: `ja; add; add; add; movzbl; cmp; jne` | 7 (same shape, all in registers) | 7 (unchanged) |
| fetch, metadata match to key compare | 3: `mov (%r15),%r8; cmp %r9,%r8; je` | 5 when the key's low byte is non-zero (`cmpb $0,(%rbx); jne; mov (%rbx),%rsi; cmp; je`), up to 19 | 5: `mov (%rbx),%rsi; test; je; cmp; je` (one load) |
| delete probe (`MVM_str_hash_delete_nocheck`) | 9 | 8 | 9 (one more pointer induction variable, for the copy) |
| delete, metadata match to key compare | 3 | as fetch: 2-16 `cmpb`/`jne` then a reload | as fetch: one load |
| back-shift copy, per 16-byte entry | `call memmoveFast` | 16 byte moves (4x unrolled `movzbl`/`mov %r8b`) | 2 (`movups` load/store; 4x unrolled) |

Sample shares (final build): the hottest fetch line is `test %rsi,%rsi` at 19.9%, the first touch of the key's line. Before, it was the `jne` after the first `cmpb`, at 20.7%; the C's is `cmp %r9,%r8`, at 20.1%. For delete it is `test %rsi,%rsi` at 27.7%. Before, the `jne` after the first `cmpb` had 27.6%; the C's `cmp %r9,%r8` has 30.6%. These are the same line-latency cost on all three. The byte loop took ~13% of the delete function's samples before; the `movups` copies take ~3% now. (The discarded `moveEntries` form's 12-instruction loop came from a separate `-Dstrip=false` build.) The C side is the same code before and after, so it was annotated once.

Runs: `--sizes=64,65,128,256,1024,16384 --runs=5` (C API), `--sizes=16,64,65,128,256,1024,16384 --runs=5` (nqp; 16 is the warm-up row and is not read). The C engine was run before (HEAD `8e77461b1`) and after (same C code, rebuilt) to bracket drift. Load average (1 min) at the start of each run: Zig before 2.08, C before 2.68, Zig after 1.54, C after 1.41 (C API) / 1.78 (nqp) (`traces/llm/bench/tuning-t5-load.log`). TSVs: `traces/llm/bench/tuning-t5-{capi,nqp}-{c,zig}-{before,after}.tsv`. Cells: `zig / c [zig min-max / c min-max]` in ns; before against C before, after against C after.

C API:

| op | size | before | after |
|---|---:|---|---|
| lookup_hit | 64 | 1.02 [7.21-7.24 / 7.05-12.35] | 1.07 [7.68-9.36 / 7.26-11.56] |
| lookup_hit | 65 | 0.89 [6.32-6.47 / 7.06-7.24] | 0.79 [5.68-5.78 / 7.12-9.72] |
| lookup_hit | 128 | 1.19 [8.45-8.65 / 7.07-7.38] | 1.07 [7.54-7.77 / 7.12-9.35] |
| lookup_hit | 256 | 1.22 [8.53-8.89 / 7.17-7.46] | 1.07 [7.76-8.16 / 7.15-7.62] |
| lookup_hit | 1024 | 1.21 [8.61-9.22 / 7.12-7.56] | 1.08 [7.84-8.59 / 7.30-8.44] |
| lookup_hit | 16384 | 1.19 [9.56-9.85 / 7.98-8.55] | 1.07 [8.62-9.00 / 8.09-8.18] |
| lookup_miss | 64 | 1.14 [8.06-8.31 / 7.14-10.71] | 1.08 [7.37-10.08 / 7.15-7.42] |
| lookup_miss | 65 | 0.79 [5.69-5.80 / 7.18-7.32] | 0.74 [5.42-5.52 / 7.21-9.32] |
| lookup_miss | 128 | 1.14 [8.14-8.26 / 7.15-7.20] | 1.08 [7.70-7.95 / 7.20-8.88] |
| lookup_miss | 256 | 1.13 [8.21-8.52 / 7.18-7.38] | 1.10 [7.87-7.95 / 7.16-7.47] |
| lookup_miss | 1024 | 1.15 [8.23-8.46 / 7.07-7.21] | 1.12 [7.84-8.21 / 7.16-7.42] |
| lookup_miss | 16384 | 1.14 [9.43-13.30 / 8.12-12.11] | 1.11 [9.53-13.75 / 8.20-12.24] |
| delete | 64 | 1.24 [10.25-10.61 / 8.34-12.56] | 1.18 [9.73-10.41 / 8.55-10.40] |
| delete | 65 | 0.91 [7.56-7.70 / 8.32-8.43] | 0.82 [6.84-6.92 / 8.40-9.82] |
| delete | 128 | 1.16 [9.56-9.66 / 8.28-8.50] | 1.00 [8.46-8.53 / 8.35-11.46] |
| delete | 256 | 1.15 [9.50-9.68 / 8.30-8.45] | 1.01 [8.49-8.67 / 8.35-8.75] |
| delete | 1024 | 1.17 [9.69-9.97 / 8.22-8.43] | 1.00 [8.52-8.63 / 8.47-8.69] |
| delete | 16384 | 1.17 [10.56-10.75 / 9.08-9.24] | 1.00 [9.29-9.39 / 9.26-9.74] |
| insert | 64 | 0.32 [13.10-16.23 / 40.57-44.10] | 0.30 [13.35-16.54 / 43.61-49.98] |
| insert | 65 | 0.87 [37.61-40.08 / 40.49-46.08] | 0.84 [36.39-40.84 / 41.64-47.71] |
| insert | 128 | 0.63 [24.58-27.94 / 43.69-47.68] | 0.61 [24.01-27.53 / 43.99-49.28] |
| insert | 256 | 0.88 [36.27-42.17 / 40.18-43.73] | 0.79 [32.49-39.35 / 41.24-45.97] |
| insert | 1024 | 1.13 [43.29-48.82 / 39.79-42.36] | 1.01 [38.54-45.48 / 40.34-42.47] |
| insert | 16384 | 1.16 [49.83-62.19 / 39.86-56.62] | 1.01 [45.13-52.54 / 40.00-55.60] |

nqp level:

| op | size | before | after |
|---|---:|---|---|
| lookup_hit | 64 | 0.93 [14.91-15.14 / 14.64-23.76] | 0.97 [14.74-15.46 / 14.37-16.71] |
| lookup_hit | 65 | 0.92 [13.09-13.30 / 14.32-14.54] | 0.89 [12.95-13.13 / 14.60-14.86] |
| lookup_hit | 128 | 1.02 [14.61-14.94 / 14.32-14.55] | 1.01 [14.68-14.84 / 14.48-14.74] |
| lookup_hit | 256 | 1.03 [14.59-15.34 / 14.56-14.94] | 0.99 [14.62-15.66 / 14.52-15.34] |
| lookup_hit | 1024 | 1.00 [15.01-15.43 / 14.89-15.37] | 1.00 [14.85-15.89 / 14.94-15.18] |
| lookup_hit | 16384 | 1.02 [16.60-16.75 / 16.10-16.41] | 1.01 [16.27-16.95 / 16.16-16.49] |
| lookup_miss | 64 | 1.13 [16.06-16.32 / 14.24-15.46] | 1.01 [14.50-15.05 / 14.26-14.59] |
| lookup_miss | 65 | 0.85 [11.84-12.12 / 14.12-14.44] | 0.84 [12.17-12.24 / 14.20-14.56] |
| lookup_miss | 128 | 1.03 [14.41-14.56 / 14.07-14.31] | 1.01 [14.44-14.91 / 14.22-15.89] |
| lookup_miss | 256 | 1.00 [14.41-14.64 / 14.24-15.75] | 1.02 [14.54-14.71 / 14.16-14.48] |
| lookup_miss | 1024 | 1.00 [14.30-14.63 / 14.35-14.63] | 1.01 [14.22-14.70 / 14.30-14.61] |
| lookup_miss | 16384 | 1.03 [15.40-20.11 / 15.12-19.96] | 1.01 [15.28-20.22 / 15.35-20.19] |
| delete | 64 | 1.00 [14.57-15.06 / 14.09-20.50] | 1.00 [14.51-14.73 / 14.56-15.89] |
| delete | 65 | 0.95 [13.57-13.94 / 14.40-14.66] | 0.91 [13.26-13.37 / 14.60-14.77] |
| delete | 128 | 1.05 [14.96-15.23 / 14.33-15.37] | 1.01 [14.41-14.64 / 14.38-14.55] |
| delete | 256 | 1.04 [14.84-15.31 / 14.51-16.40] | 1.00 [14.41-14.58 / 14.52-14.70] |
| delete | 1024 | 1.04 [15.47-15.76 / 14.80-15.03] | 0.98 [14.58-14.83 / 14.85-14.92] |
| delete | 16384 | 1.11 [17.50-18.22 / 16.31-16.96] | 1.01 [16.46-18.43 / 16.46-16.68] |
| insert | 64 | 0.44 [22.32-25.88 / 53.28-61.10] | 0.38 [22.64-25.85 / 52.67-62.49] |
| insert | 65 | 0.88 [46.16-51.91 / 50.80-56.20] | 0.88 [46.66-49.16 / 50.75-54.70] |
| insert | 128 | 0.70 [34.15-37.57 / 50.91-57.83] | 0.67 [33.53-37.40 / 51.33-54.22] |
| insert | 256 | 0.88 [46.50-47.22 / 52.95-54.09] | 0.82 [44.31-47.63 / 51.36-55.21] |
| insert | 1024 | 1.09 [51.08-56.59 / 49.64-51.95] | 1.00 [47.34-53.41 / 49.38-53.10] |
| insert | 16384 | 1.04 [58.48-70.98 / 49.15-63.63] | 0.98 [51.35-67.08 / 49.57-62.81] |

- Kept. At the C API (Robin Hood, 128-16384), lookup_hit went from 1.19-1.22 to 1.07-1.08 and delete from 1.15-1.17 to 1.00-1.01. The Zig spreads are disjoint before and after at every size. lookup_miss went from 1.13-1.15 to 1.08-1.12, disjoint at 128-1024; at 16384 both spreads are wide (9.43-13.30 against 9.53-13.75 ns). Insert also moved at 1024/16384 (1.13/1.16 to 1.01/1.01), but its spreads overlap.
- At the nqp level, delete went from 1.04-1.11 to 0.98-1.01, disjoint at 128, 256 and 1024 (14.96-15.23 / 14.84-15.31 / 15.47-15.76 against 14.41-14.64 / 14.41-14.58 / 14.58-14.83 ns). At 16384 there is one slow run after (max 18.43; the minimum fell from 17.50 to 16.46). lookup_hit (0.99-1.01) and lookup_miss (1.01-1.02) were already at parity after Task 6 and did not move beyond the spread.
- Size 65 (the first Robin Hood row, 256 official slots) improved at the C API: lookup_hit 0.89 to 0.79, delete 0.91 to 0.82.
- Small (64) did not regress. The C-API lookup_hit at 64 reads 1.02 to 1.07 (7.21-7.24 against 7.68-9.36 ns), but the Small code is unchanged. Three more C-API runs of each build at 64 gave lookup_hit 7.38 / 7.76 / 8.07 ns before and 7.43 / 7.48 / 7.58 ns after, lookup_miss 7.38 / 7.97 / 8.01 before and 7.28 / 7.36 / 7.96 after, and delete 10.08 / 10.57 / 10.70 before and 9.82 / 9.87 / 10.61 after. The first before run was at the bottom of the band.
- What is left on Robin Hood at the C API, lookup_hit 1.07 and lookup_miss 1.08-1.12, is outside the probe loop, which now matches the C instruction for instruction. Before the loop: the `cur_items == 0` test, the dispatch/stale byte tests (Task 3), and `loopState`'s `key_right_shift + metadata_hash_bits` and `imul` (profile cause RH-4). Delete is at parity.

### Task 3: policy-layer dispatch and checks (kept)

Changes (`table.zig`; tests in `table.zig`, `str.zig`, `hash_test.zig`; no tier, Spec, export or C change):

- `dispatch` tests `header.set == 0` first and takes `dispatchSet0`: one `switch` on the `tier` byte with an `inline` prong per rung of `Spec.sets[0]`. Any other set goes through `dispatchOther` (`resolve`, as before). When `Spec.sets.len == 1` (`pub const dispatch_reads_set == false`), the set byte is not read at all. That covers the four single-rung tables, `IntSpec`, and every `dispatch` caller (grow, iteration, `fsck`, `blockOf`). The string table's `standard` set is index 0, so every C-API hash takes the switch and only `large_only` takes `resolve`. `str.zig` asserts this at comptime.
- `fetch`, `lvalue` and `delete` read the header's first four bytes (`tier`, `set`, `entry_size`, `stale`) in one 32-bit load (`statusOf`; `*volatile` under `.safepoint_cas`, so the entry stale check is still a volatile read, once per call, before any other table access). They test one mask: the stale byte (`.safepoint_cas` only), the set byte (multi-set Specs only) and the control-only bit. When the masked bits are all zero, they switch on the tier byte from that same load. Otherwise they take the separate tests in the old order: stale (`MVM_oops` with the same message), control-only (`fetch` null, `delete` false, `lvalue` materialises), then `resolve` for set != 0. The mask is built from `@offsetOf(Header, ..)` (native byte order), and there are comptime checks that the four bytes are the header's first four and that the header is 4-aligned.
- The exit "turned stale" check of `delete` (and `lvalue`/`shallowCopy`) is unchanged: one volatile byte compare, `cmpb $0x0,0x3(%r10)`, before and after. The `entries_offset` handling for Small was Task 4's and is not touched. Neither is `loopState`/`cur_items` (RH-4).

Prologue (`objdump -d` of the installed `libmoar.so`'s `MVM_str_hash_fetch_nocheck`; Robin Hood rung of set 0, cached hash; instructions from entry to the first probe-loop instruction `movzbl (%r15),%eax`):

    before (50; 26 before loopState)                   after (46; 22 before loopState)
    push x7 ; mov %rdi,(%rsp)                          push x6 ; sub $0x48,%rsp ; mov %rdi,(%rsp)
    mov (%rsi),%rbx ; test ; je        (null)          mov (%rsi),%r12 ; test ; je         (null)
    cmpb $0x0,0x3(%rbx) ; jne          (stale)         mov %rdx,%rbx
    movzbl (%rbx),%ecx ; test %cl ; js (control-only)  mov (%r12),%ecx                     (one volatile load)
    mov %rdx,%r14                                      test $0xff00ff80,%ecx ; je  fast    (stale|set|control)
    cmpb $0x0,0x1(%rbx) ; je           (set == 0)      fast: mov 0x28(%rbx),%rax ; test $0x7f,%cl ; je small
    mov 0x28(%r14),%rax ; test %cl ; je small (rung)         test %rax ; je compute ; cmpl $0x0,0x4(%r12) ; jne
    test %rax ; jne ; cmpl $0x0,0x4(%rbx) ; je         loopState (24, unchanged) ; probe loop
    loopState (24) ; probe loop

The dispatch part went from 11 instructions with 3 header-byte loads (stale, tier, set) to 7 with one word load. `MVM_str_hash_delete_nocheck`, entry to loopState: 27 before, 23 after, with the same three loads folded into one. The slow path (stale, control-only, set != 0) is laid out after the fast `je`.

A side effect of the restructure: LLVM now inlines the Small tier's `findIn` for capacities 8 and 16 into the `fetch`/`delete` exports, where before it called all four capacity instantiations. 32 and 64 are still calls, and `findIn(64)` is byte-identical before and after. The exports grew: `fetch_nocheck` from 0x299 to 0x5f7 bytes, `delete_nocheck` from 0x5e6 to 0xa17. The frame is `sub $0x48` instead of `push %rax`. This is an inlining-heuristic outcome, not something the code asks for. It accounts for the large gains at sizes 4-16 below. A later change to `small.zig` or the exports can flip it back, so Task 8 should check it.

Runs: the protocol runs (separate builds, `--sizes=64,65,128,1024,16384 --runs=5` C API, `--sizes=16,64,65,128,1024,16384 --runs=5` nqp; 16 is the warm-up row), Zig before at HEAD `92d9ff5dc`, C before, Zig after, C after. Load average (1 min) at the start: Zig before 2.13, C before 2.90 (right after a build), Zig after 0.62, C after 0.62 (C API) / 0.99 (nqp) (`traces/llm/bench/tuning-t3-load.log`). TSVs: `traces/llm/bench/tuning-t3-{capi,nqp}-{c,zig}-{before,after}.tsv`, plus `tuning-t3-capi-{zig-before,zig-after,c-after}-small.tsv` (sizes 4-32). Cells: `zig / c [zig min-max / c min-max]` in ns, before against C before, after against C after.

The protocol runs moved the Zig numbers by more than the change could explain in both directions (C-API lookup_hit at 64 was 7.21-7.40 ns in a first after build and 8.02-8.52 in the recorded one, from the same source). So each harness was also run interleaved: the same bench binary and the same `moar`, with the before and after `libmoar.so` (and the C one) swapped through `LD_LIBRARY_PATH` (RUNPATH, so it overrides) and run alternately. That was 10 rounds at the C API and 6 rounds for each of two nqp size orders. Cells: median of the per-round medians [min-max of the per-round medians] in ns. Raw rows (variant, round, then the harness columns): `traces/llm/bench/tuning-t3-interleaved-{capi,nqp,nqp-small}.tsv`. Load 0.6-0.9.

C API (protocol runs):

| op | size | before | after |
|---|---:|---|---|
| lookup_hit | 64 | 1.08 [8.01-8.31 / 7.30-7.51] | 1.13 [8.02-8.52 / 7.19-7.51] |
| lookup_hit | 65 | 0.80 [5.70-6.32 / 7.38-7.50] | 0.75 [5.36-5.55 / 7.17-7.26] |
| lookup_hit | 128 | 1.09 [7.66-7.95 / 7.09-7.32] | 1.07 [7.59-7.80 / 7.08-7.26] |
| lookup_hit | 1024 | 1.04 [7.84-8.36 / 7.62-8.41] | 1.09 [7.79-9.26 / 7.28-7.87] |
| lookup_hit | 16384 | 1.00 [8.49-8.67 / 8.52-8.80] | 1.05 [8.46-8.67 / 8.00-8.22] |
| lookup_miss | 64 | 1.11 [7.86-8.33 / 7.35-7.42] | 1.02 [7.39-8.02 / 7.20-10.33] |
| lookup_miss | 65 | 0.75 [5.41-5.70 / 7.49-7.66] | 0.73 [5.38-5.46 / 7.30-7.52] |
| lookup_miss | 128 | 1.09 [7.80-8.02 / 7.12-7.44] | 1.08 [7.79-7.94 / 7.12-7.30] |
| lookup_miss | 1024 | 1.06 [7.91-8.24 / 7.53-7.71] | 1.09 [7.85-9.66 / 7.20-7.44] |
| lookup_miss | 16384 | 0.99 [8.87-13.05 / 9.08-12.42] | 1.08 [9.10-14.06 / 8.36-12.37] |
| delete | 64 | 1.25 [10.56-10.87 / 8.63-8.79] | 1.05 [9.74-10.36 / 8.46-17.12] |
| delete | 65 | 0.82 [6.89-7.19 / 8.65-8.88] | 0.79 [6.65-6.69 / 8.42-8.56] |
| delete | 128 | 1.02 [8.42-8.58 / 8.29-8.78] | 0.99 [8.26-8.41 / 8.30-8.52] |
| delete | 1024 | 0.97 [8.53-8.71 / 8.78-9.39] | 1.03 [8.49-9.13 / 8.41-8.48] |
| delete | 16384 | 0.93 [9.10-9.34 / 9.71-10.29] | 0.99 [9.08-9.74 / 9.12-9.37] |
| insert | 64 | 0.31 [13.86-16.93 / 43.13-46.67] | 0.31 [13.80-16.55 / 44.14-45.60] |
| insert | 65 | 0.85 [37.39-39.11 / 42.41-45.74] | 0.83 [37.79-41.56 / 44.30-48.97] |
| insert | 128 | 0.61 [24.01-27.82 / 41.40-46.45] | 0.63 [24.90-28.30 / 44.08-47.94] |
| insert | 1024 | 1.02 [41.06-42.58 / 40.07-43.16] | 1.04 [41.91-43.16 / 40.24-43.33] |
| insert | 16384 | 0.97 [40.61-58.68 / 42.77-58.69] | 1.00 [41.17-58.51 / 42.19-58.29] |

nqp level (protocol runs):

| op | size | before | after |
|---|---:|---|---|
| lookup_hit | 64 | 0.99 [14.89-15.22 / 14.68-19.14] | 1.03 [15.03-15.53 / 14.46-23.90] |
| lookup_hit | 65 | 0.88 [12.77-13.49 / 14.67-15.40] | 0.87 [12.59-12.92 / 14.57-14.83] |
| lookup_hit | 128 | 1.01 [14.66-14.87 / 14.62-15.17] | 1.01 [14.44-14.55 / 14.25-14.48] |
| lookup_hit | 1024 | 1.00 [15.00-15.26 / 14.90-16.78] | 1.03 [14.87-16.60 / 14.65-14.77] |
| lookup_hit | 16384 | 1.01 [16.30-17.16 / 16.29-17.96] | 1.01 [16.27-16.67 / 16.24-16.90] |
| lookup_miss | 64 | 1.06 [14.57-15.36 / 14.13-14.37] | 1.08 [15.19-17.65 / 14.29-15.37] |
| lookup_miss | 65 | 0.83 [11.91-12.30 / 14.39-15.96] | 0.83 [11.99-12.19 / 14.27-14.52] |
| lookup_miss | 128 | 0.99 [14.36-14.48 / 14.45-14.64] | 1.03 [14.45-14.73 / 14.06-14.31] |
| lookup_miss | 1024 | 1.00 [14.45-14.72 / 14.38-14.95] | 1.03 [14.57-18.65 / 14.02-14.31] |
| lookup_miss | 16384 | 1.01 [15.45-20.20 / 15.39-20.46] | 1.02 [15.62-19.81 / 15.24-19.76] |
| delete | 64 | 0.95 [14.13-14.54 / 14.47-19.89] | 1.04 [15.09-15.88 / 14.57-22.33] |
| delete | 65 | 0.86 [13.03-13.37 / 14.75-20.33] | 0.88 [12.78-12.88 / 14.50-15.03] |
| delete | 128 | 0.88 [14.37-14.75 / 14.62-24.43] | 0.98 [13.93-14.32 / 14.29-14.42] |
| delete | 1024 | 0.99 [14.76-14.94 / 14.85-16.10] | 0.98 [13.76-14.53 / 14.73-14.97] |
| delete | 16384 | 1.01 [16.60-16.86 / 16.40-20.90] | 1.00 [16.43-16.80 / 16.33-17.10] |
| insert | 64 | 0.48 [21.98-37.38 / 52.57-64.61] | 0.44 [23.10-27.98 / 52.77-60.66] |
| insert | 65 | 0.88 [45.66-52.82 / 52.60-55.97] | 0.89 [47.10-51.94 / 53.96-54.58] |
| insert | 128 | 0.67 [33.66-36.93 / 52.59-55.91] | 0.70 [34.22-37.67 / 52.82-56.28] |
| insert | 1024 | 0.94 [47.99-53.73 / 49.28-60.07] | 1.00 [45.76-51.17 / 46.79-53.91] |
| insert | 16384 | 0.91 [53.97-66.84 / 55.80-78.76] | 1.04 [55.40-73.41 / 53.33-63.42] |

C API, interleaved (10 rounds, `--sizes=8,16,64,128,1024,16384 --runs=5`):

| op | size | Zig before | Zig after | C | after/before | before/C | after/C |
|---|---:|---|---|---|---:|---:|---:|
| delete | 8 | 8.07 [7.85-8.61] | 7.07 [6.86-7.45] | 8.64 [7.99-8.95] | 0.88 | 0.93 | 0.82 |
| delete | 16 | 8.04 [7.89-8.30] | 7.04 [6.99-7.32] | 8.26 [8.20-8.47] | 0.88 | 0.97 | 0.85 |
| delete | 64 | 10.34 [9.85-11.43] | 10.18 [9.84-10.44] | 8.36 [8.22-9.28] | 0.98 | 1.24 | 1.22 |
| delete | 128 | 8.55 [8.40-9.05] | 8.28 [8.24-8.38] | 8.29 [8.19-10.10] | 0.97 | 1.03 | 1.00 |
| delete | 1024 | 8.52 [8.38-9.90] | 8.40 [8.28-8.55] | 8.39 [8.27-8.51] | 0.99 | 1.01 | 1.00 |
| delete | 16384 | 9.27 [9.09-10.43] | 9.09 [8.95-9.70] | 9.25 [9.08-9.35] | 0.98 | 1.00 | 0.98 |
| lookup_hit | 8 | 6.17 [6.03-6.36] | 5.00 [4.89-5.45] | 6.94 [6.63-7.31] | 0.81 | 0.89 | 0.72 |
| lookup_hit | 16 | 6.43 [6.01-6.62] | 4.56 [4.45-4.87] | 6.89 [6.79-7.01] | 0.71 | 0.93 | 0.66 |
| lookup_hit | 64 | 7.74 [7.31-8.35] | 7.76 [7.42-8.10] | 7.11 [6.99-7.72] | 1.00 | 1.09 | 1.09 |
| lookup_hit | 128 | 7.80 [7.71-8.37] | 7.62 [7.54-8.12] | 7.14 [7.00-7.97] | 0.98 | 1.09 | 1.07 |
| lookup_hit | 1024 | 7.90 [7.74-8.33] | 7.71 [7.61-7.83] | 7.32 [7.16-7.45] | 0.98 | 1.08 | 1.05 |
| lookup_hit | 16384 | 8.57 [8.45-9.18] | 8.43 [8.31-8.67] | 8.11 [7.96-8.24] | 0.98 | 1.06 | 1.04 |
| lookup_miss | 8 | 6.03 [5.77-6.57] | 4.25 [4.07-4.74] | 7.57 [7.40-7.83] | 0.70 | 0.80 | 0.56 |
| lookup_miss | 16 | 6.02 [5.70-6.80] | 4.21 [4.01-4.65] | 7.12 [7.04-7.22] | 0.70 | 0.84 | 0.59 |
| lookup_miss | 64 | 7.57 [7.42-8.29] | 8.04 [7.46-8.34] | 7.17 [7.04-7.80] | 1.06 | 1.06 | 1.12 |
| lookup_miss | 128 | 7.89 [7.75-8.11] | 7.78 [7.70-7.86] | 7.20 [7.09-7.91] | 0.99 | 1.10 | 1.08 |
| lookup_miss | 1024 | 7.93 [7.79-8.26] | 7.84 [7.79-7.99] | 7.25 [7.11-7.32] | 0.99 | 1.09 | 1.08 |
| lookup_miss | 16384 | 9.37 [9.25-9.97] | 9.40 [9.23-10.57] | 8.53 [8.42-8.78] | 1.00 | 1.10 | 1.10 |

nqp level, interleaved (6 rounds, `--sizes=16,64,128,1024,16384`; 16 is the warm-up):

| op | size | Zig before | Zig after | C | after/before | before/C | after/C |
|---|---:|---|---|---|---:|---:|---:|
| delete | 64 | 14.89 [14.15-15.65] | 14.75 [14.12-15.89] | 14.58 [14.53-14.71] | 0.99 | 1.02 | 1.01 |
| delete | 128 | 14.58 [14.47-14.90] | 14.28 [14.21-14.42] | 14.57 [14.47-14.61] | 0.98 | 1.00 | 0.98 |
| delete | 1024 | 14.96 [14.83-15.18] | 14.51 [14.38-15.93] | 14.98 [14.90-15.06] | 0.97 | 1.00 | 0.97 |
| delete | 16384 | 16.66 [16.46-16.76] | 16.04 [15.90-16.13] | 16.52 [16.46-16.63] | 0.96 | 1.01 | 0.97 |
| lookup_hit | 64 | 14.59 [14.14-14.93] | 14.95 [14.46-16.18] | 14.72 [14.66-15.40] | 1.02 | 0.99 | 1.02 |
| lookup_hit | 128 | 14.88 [14.78-16.03] | 15.39 [14.63-15.82] | 14.68 [14.56-14.81] | 1.03 | 1.01 | 1.05 |
| lookup_hit | 1024 | 15.52 [14.88-16.49] | 15.16 [14.92-15.87] | 15.10 [14.97-15.30] | 0.98 | 1.03 | 1.00 |
| lookup_hit | 16384 | 16.52 [16.33-16.73] | 16.44 [16.06-16.53] | 16.40 [16.29-16.69] | 1.00 | 1.01 | 1.00 |
| lookup_miss | 64 | 14.70 [14.47-15.20] | 16.40 [15.79-17.17] | 14.36 [14.25-14.50] | 1.12 | 1.02 | 1.14 |
| lookup_miss | 128 | 14.62 [14.48-15.01] | 14.83 [14.69-15.00] | 14.39 [14.35-14.56] | 1.01 | 1.02 | 1.03 |
| lookup_miss | 1024 | 14.61 [14.53-14.90] | 14.91 [14.80-15.07] | 14.50 [14.48-14.69] | 1.02 | 1.01 | 1.03 |
| lookup_miss | 16384 | 15.68 [15.54-15.83] | 15.81 [15.72-16.04] | 15.56 [15.38-15.71] | 1.01 | 1.01 | 1.02 |

nqp level, interleaved, small sizes (6 rounds, `--sizes=128,4,8,16,32,64`; 128 is the warm-up):

| op | size | Zig before | Zig after | C | after/before | before/C | after/C |
|---|---:|---|---|---|---:|---:|---:|
| delete | 4 | 15.45 [13.55-43.91] | 13.98 [12.25-45.20] | 14.96 [13.93-50.68] | 0.91 | 1.03 | 0.93 |
| delete | 8 | 12.94 [12.76-13.25] | 11.61 [11.52-12.49] | 14.41 [14.27-14.58] | 0.90 | 0.90 | 0.81 |
| delete | 16 | 13.04 [12.69-13.73] | 11.36 [11.13-12.15] | 14.77 [14.45-15.05] | 0.87 | 0.88 | 0.77 |
| delete | 32 | 14.01 [13.13-14.14] | 13.59 [13.29-14.33] | 14.71 [14.46-14.80] | 0.97 | 0.95 | 0.92 |
| delete | 64 | 14.72 [14.28-15.13] | 14.48 [14.14-14.95] | 14.56 [14.30-15.05] | 0.98 | 1.01 | 0.99 |
| lookup_hit | 4 | 19.00 [13.49-46.72] | 18.80 [16.88-49.10] | 16.68 [13.50-55.25] | 0.99 | 1.14 | 1.13 |
| lookup_hit | 8 | 13.35 [12.75-13.47] | 12.72 [11.99-12.96] | 14.35 [14.08-14.90] | 0.95 | 0.93 | 0.89 |
| lookup_hit | 16 | 13.32 [12.69-13.92] | 12.45 [12.01-12.90] | 14.76 [14.53-15.04] | 0.93 | 0.90 | 0.84 |
| lookup_hit | 32 | 13.89 [13.36-14.58] | 14.23 [14.00-15.08] | 14.68 [14.57-14.84] | 1.02 | 0.95 | 0.97 |
| lookup_hit | 64 | 15.01 [14.70-15.32] | 15.43 [14.57-15.96] | 14.57 [14.42-14.78] | 1.03 | 1.03 | 1.06 |
| lookup_miss | 4 | 13.45 [13.25-45.40] | 11.95 [11.87-47.83] | 17.73 [14.53-56.28] | 0.89 | 0.76 | 0.67 |
| lookup_miss | 8 | 12.79 [12.73-13.59] | 11.45 [11.31-12.08] | 14.84 [14.61-15.17] | 0.90 | 0.86 | 0.77 |
| lookup_miss | 16 | 13.14 [12.78-13.49] | 11.52 [11.35-12.40] | 14.63 [14.54-15.04] | 0.88 | 0.90 | 0.79 |
| lookup_miss | 32 | 13.90 [13.36-14.73] | 14.43 [12.83-14.86] | 14.54 [14.41-14.73] | 1.04 | 0.96 | 0.99 |
| lookup_miss | 64 | 15.72 [15.27-16.31] | 15.49 [15.10-15.84] | 14.37 [14.22-14.56] | 0.99 | 1.09 | 1.08 |

Zig after against Zig before at sizes 4-32, C API protocol build (`tuning-t3-capi-zig-{before,after}-small.tsv`): lookup_hit 0.81 / 0.82 / 0.70 / 1.03, lookup_miss 0.72 / 0.65 / 0.64 / 1.05, delete 0.81 / 0.87 / 0.87 / 1.02 at 4 / 8 / 16 / 32. Against the C (`tuning-t3-capi-c-after-small.tsv`): lookup_hit 0.88 / 0.78 / 0.64 / 0.96, lookup_miss 0.62 / 0.57 / 0.57 / 0.95, delete 0.86 / 0.90 / 0.86 / 1.07.

- Kept. Delete moved outside the spread. In the protocol runs, C-API delete went from 1.25 to 1.05 at 64 (10.56-10.87 against 9.74-10.36 ns) and from 1.02 to 0.99 at 128 (8.42-8.58 against 8.26-8.41). Interleaved, Robin Hood delete is 1-4% faster on both harnesses: disjoint at C-API 128 (8.40-9.05 against 8.24-8.38) and at nqp 128 and 16384 (14.47-14.90 against 14.21-14.42; 16.46-16.76 against 15.90-16.13). It is at or below the C from 128 up (C API 0.98-1.00, nqp 0.97-0.98). Small 8 and 16 lookup and delete moved far outside the spread on both harnesses (C API 0.70-0.88 of before; nqp 0.87-0.95). That gain is the `findIn` inlining side effect above.
- Robin Hood lookup_hit is 2% faster at the C API interleaved (0.98 at 128-16384, spreads overlap) and moves either way at the nqp level (0.98-1.03, overlapping). Robin Hood lookup_miss did not move (0.99-1.02). The dispatch chain was 4 of the ~50 instructions in front of the probe, so a ~2% effect on lookups is what the instruction count predicts. What is left of the Robin Hood lookup gap (C API 1.04-1.07 hit, 1.08-1.10 miss interleaved) is not in the dispatch: the policy prologue is now one word load and one masked test against the C's stale byte and `cur_items` test. The rest is `loopState` (RH-4) and what precedes the probe in the tier.
- Small at 64 shows no lever effect beyond noise. One reading needs explaining: nqp lookup_miss at 64 was 1.12 of before in the interleaved run with sizes 16,64,128,... (every round, 14.47-15.20 against 15.79-17.17) and 0.99 in the run with sizes 128,4,...,64 (15.27-16.31 against 15.10-15.84). The C-API interleaved 64 miss was 1.06 with overlapping spreads (7 rounds of 10 slower). The 64 path is the same out-of-line `findIn(64)` (byte-identical) behind a dispatch that has two fewer instructions plus one `%r12` spill around the call. So the order-dependent nqp reading is attributed to layout (the larger export; `findIn(64)` moved from a 64-byte-aligned to a 32-byte-aligned address), not to the dispatch.
- Insert (lvalue) shares the folded entry test but keeps `dispatch` in its retry loop. At 1024 and 16384 it is 1.00-1.04 of the C, unchanged within the spread.

### Task 6: the C-shaped wrapper (kept)

Changes, measured as one lever (`str.zig`, `table.zig`; no change to `dispatch`'s or `resolve`'s semantics, to any tier, or to the exports):

- `StrSpec.hash` is an `inline fn` that reads `key.*.body.cached_hash_code` and calls `MVM_string_compute_hash_code` only when it is 0, as the C static inline `MVM_string_hash_code` (`src/strings/ops.h`) does. The translate-c copy of that inline was a 14-byte out-of-line function that no caller inlined.
- `StrSpec.eql` is `inline`, with the same order (pointer, grapheme counts, `MVM_string_substrings_equal_nocheck`); the counts come from the translated `MVM_string_graphs_nocheck` called with `@call(.always_inline, ..)`.
- `keyIsValid` is `inline` and does the C's checks in the C's order (`str_hash_table_funcs.h:366-371`): `MVM_is_null` written out (NULL or `VMNull`), the REPR ID compare through `moar.repr(obj).ID`, then `moar.isConcrete`. No call.
- `str.fetchNocheck`, `deleteNocheck`, `fetch` and `delete` are `inline fn` and call `StrTable.fetch`/`delete` with `@call(.always_inline, ..)`.
- In `table.zig`: `ops.fetch`, `ops.lvalue` and `ops.delete` are `inline fn`. They call the tier's `fetch`/`delete` and `I.hash` with `@call(.always_inline, ..)`. `Table.fetch`, `lvalue` and `delete` call `dispatch` with `@call(.always_inline, ..)`. `resolve` and `dispatch`'s `Op.f` are `inline fn`. `dispatch` itself stays a plain `fn`, and its other callers (grow, iteration, fsck, drain) keep calling it. Marking only `ops.*` inline was not enough: LLVM then outlined `dispatch` and the Robin Hood `fetch`/`delete`, which made the chain longer, so `resolve`/`Op.f` had to be inlined too.

Chain evidence (`-Dstrip=false` build, `nm -S` and `objdump -d` of `libmoar.so`, which the bench binary calls):

| | before | after |
|---|---|---|
| `MVM_str_hash_fetch_nocheck` | 8 bytes: `mov (%rsi),%rsi; jmp str.fetchNocheck` | 0x2fc bytes, one frame (7 pushes, one `ret`) |
| behind it | `str.fetchNocheck` 0x93 (5 pushes; RH: `jmp ops.fetch__anon` 0x10d, 7 pushes; Small: `call moar_c.MVM_string_hash_code`, `call small.find` 0x440) | none on a cached hash. Calls left: `MVM_string_compute_hash_code@plt` behind `mov 0x28(%r14),%rax; test %rax,%rax; jne` (cache miss only), `MVM_string_substrings_equal_nocheck@plt` (unequal pointers only), one Small `findIn` per capacity (8/16/32/64; `find`'s switch is now inline) |
| `MVM_str_hash_delete_nocheck` | 8 bytes: `jmp str.deleteNocheck` 0xe5, then `call ops.delete__anon` 0x28b | 0x607 bytes, one frame; the same calls left as fetch, plus the existing `compiler_rt.memcpy` for non-16-byte Small swaps |
| calls to `MVM_string_hash_code` | from `fetchNocheck`, `ops.fetch`, `ops.delete`, `deleteNocheck` | none from any string-table export (`moar_c.MVM_string_hash_code` is still linked for other callers) |

`MVM_str_hash_fetch`/`MVM_str_hash_delete` are now one frame too, and the key check is inline (`test %rdx,%rdx; cmp 0x708(%rax),%r14` for VMNull, the REPR ID load and compare, the type-object flag). The Robin Hood probe is inlined twice per export, once for set 0's rung 1 and once for set 1's rung 0. `Table(StrSpec).lvalue` (0xff8) now holds the Robin Hood `lvalueFetch` inline. The two lvalue exports call it.

Runs: `--sizes=16,64,128,1024,16384 --runs=5`, both harnesses. Size 16 is only a warm-up for the nqp ladder and is not read. The C engine was run before (HEAD `8c3f57e10`) and after (the same C code, rebuilt) to bracket drift. Load average (1 min) at the start of each run: Zig before 2.30, C before 2.30, Zig after 1.04, C after 1.04 (`traces/llm/bench/tuning-t6-load.log`). TSVs: `traces/llm/bench/tuning-t6-{capi,nqp}-{c,zig}-{before,after}.tsv`. Cells: `zig / c [zig min-max / c min-max]` in ns; before is against C before, after against C after.

capi:

| op | size | before | after |
|---|---:|---|---|
| lookup_hit | 64 | 1.07 [7.69-7.82 / 6.96-8.22] | 1.15 [7.63-8.57 / 7.08-7.22] |
| lookup_hit | 128 | 1.32 [9.42-9.52 / 7.12-7.22] | 1.18 [8.32-8.60 / 7.12-7.24] |
| lookup_hit | 1024 | 1.32 [9.63-10.30 / 7.25-8.23] | 1.21 [8.64-9.40 / 7.28-8.36] |
| lookup_hit | 16384 | 1.31 [10.71-11.01 / 8.12-8.27] | 1.15 [9.33-9.72 / 8.15-8.37] |
| lookup_miss | 64 | 1.16 [7.89-9.12 / 7.05-7.52] | 1.10 [7.50-13.37 / 7.16-7.32] |
| lookup_miss | 128 | 1.24 [9.03-9.20 / 7.18-7.36] | 1.16 [8.09-9.28 / 7.16-7.28] |
| lookup_miss | 1024 | 1.25 [9.04-9.26 / 7.19-7.42] | 1.14 [8.26-8.61 / 7.18-7.39] |
| lookup_miss | 16384 | 1.28 [10.49-14.29 / 8.33-12.46] | 1.13 [9.39-13.38 / 8.27-12.37] |
| delete | 64 | 1.21 [9.87-10.35 / 8.36-24.39] | 1.25 [9.65-23.38 / 8.35-8.48] |
| delete | 128 | 1.29 [10.68-10.96 / 8.34-8.52] | 1.14 [9.47-9.64 / 8.37-8.46] |
| delete | 1024 | 1.29 [10.92-11.04 / 8.44-8.60] | 1.17 [9.93-10.05 / 8.46-8.54] |
| delete | 16384 | 1.29 [11.95-12.34 / 9.22-9.39] | 1.14 [10.59-11.83 / 9.35-9.98] |

nqp level:

| op | size | before | after |
|---|---:|---|---|
| lookup_hit | 64 | 1.03 [15.25-15.44 / 14.75-15.31] | 0.99 [14.45-14.71 / 14.50-15.44] |
| lookup_hit | 128 | 1.15 [16.76-17.06 / 14.49-14.77] | 1.01 [14.62-14.74 / 14.54-14.76] |
| lookup_hit | 1024 | 1.16 [17.13-17.39 / 14.66-15.43] | 1.04 [15.47-17.35 / 14.68-15.13] |
| lookup_hit | 16384 | 1.18 [19.22-19.58 / 16.08-16.82] | 1.03 [16.77-17.16 / 16.09-16.40] |
| lookup_miss | 64 | 1.15 [16.53-16.93 / 14.40-14.94] | 1.07 [15.19-15.68 / 14.13-14.81] |
| lookup_miss | 128 | 1.13 [16.22-16.39 / 14.37-14.59] | 1.00 [14.39-14.51 / 14.29-14.53] |
| lookup_miss | 1024 | 1.14 [16.23-16.52 / 14.25-14.66] | 1.02 [14.59-16.69 / 14.16-14.56] |
| lookup_miss | 16384 | 1.11 [17.16-22.12 / 15.27-20.42] | 1.00 [15.29-19.93 / 15.25-20.03] |
| delete | 64 | 1.04 [15.18-15.40 / 14.64-14.91] | 1.00 [14.30-14.73 / 14.40-14.77] |
| delete | 128 | 1.17 [16.89-17.07 / 14.44-14.74] | 1.04 [15.11-15.49 / 14.37-14.74] |
| delete | 1024 | 1.17 [17.45-17.88 / 14.80-15.11] | 1.09 [16.12-16.38 / 14.63-15.04] |
| delete | 16384 | 1.19 [19.79-20.32 / 16.53-16.87] | 1.10 [17.61-18.00 / 16.00-16.66] |

- Kept. On Robin Hood (128-16384) at the C API, the targeted ops moved outside the Zig spread at every size. lookup_hit went from 1.31-1.32 to 1.15-1.21 and delete from 1.29 to 1.14-1.17. lookup_miss went from 1.24-1.28 to 1.13-1.16, but its Zig spreads overlap at 128 and 16384 because of one slow run each (after max 9.28 and 13.38 ns). At the nqp level, lookup_hit went from 1.15-1.18 to 1.01-1.04, lookup_miss from 1.11-1.14 to 1.00-1.02 and delete from 1.17-1.19 to 1.04-1.10. Three nqp Zig spreads overlap. At 1024, lookup_hit and lookup_miss each have one slow run after (max 17.35 and 16.69 ns), while their minimums fall from 17.13 to 15.47 and from 16.23 to 14.59 ns. At 16384, lookup_miss is wide on both engines (C 15.25-20.03 ns). Every other nqp spread is disjoint.
- Small (64): at the nqp level, lookup_hit 1.03 -> 0.99, lookup_miss 1.15 -> 1.07 and delete 1.04 -> 1.00, all outside the Zig spread. At the C API, lookup_hit 1.07 -> 1.15 and delete 1.21 -> 1.25 are in the run-to-run band: the Zig spreads overlap (7.69-7.82 against 7.63-8.57 ns; 9.87-10.35 against 9.65-23.38 ns). Three more C-API runs of the after build gave lookup_hit 7.57 / 7.91 / 8.01 ns and delete 10.21 / 10.38 / 10.48 ns at 64, against 7.79 / 10.16 before and 7.78 / 10.61 in Task 4's after. The Small path still makes one call, to `findIn`, so the profile's ~12% share for Small is not measurable at the C API.
- insert and iterate did not move beyond the band at either level (C API insert 1024/16384 1.17/1.26 -> 1.13/1.16 with wide spreads; iterate 1.33-1.34 both).
- What is left on Robin Hood is the zero-key byte chain, `loopState`, the backward shift (Task 5) and the status-byte checks (Task 3).

## Deviations

Record here, during execution, anything that differed from the plan or spec and why.

- Task 1: the profile was not re-run. The recon report (`zig-hash-spike-profile`, engine `a5ea2a419`) matches the starting code and was copied into "## Profile and baseline".
- Task 1: `hash-bench.nqp` deviates from the spike in two ways. Each timed phase is now a sub, which removed a spesh artefact that doubled the C engine's delete. `sorted` now uses a numeric compare. The spec §3 nqp ratios are superseded by the baseline tables.
- Task 1: harness output gains `ns_min`/`ns_max` columns (6, 7) in both `hash-bench.nqp` and `bench.zig`. The first five columns are unchanged, so `hash-bench.sh`'s existing renderer and the Raku harness still work.
- Task 1, lever order: 4, 6, 5, 3, 7 (not the plan's numbering). Scope extensions: Task 4 takes `find`'s return path, Task 6 the call-chain inlining, Task 5 the `@memmove` shifts. Reasons under "### Lever order".
- Task 1: the migration finish line (Zig 65th ≤ C 97th) is already met at baseline on both harnesses. Task 7 is kept as an improvement and runs last.
- Task 2: binding (a) is protected visibility only under `-Dlto`, not on every build. Unconditional protected also binds locally without LTO: PLT calls go from 119 to 0. That would contradict Step 3's check that the counts without `-Dlto` equal Step 1's and the constraint that the link without `-Dlto` is today's. `-Bsymbolic-functions` was not needed in either build (spec 4.7 had planned it for both).
- Task 2: `tools/check-lto-binding.sh` prints a fourth count, the call and jump sites to `MVM_str_hash_fetch_nocheck`. Under (a) the definition stays because it is exported, so the brief's expected "0 definitions under LTO" cannot hold. The call-site count is what shows the inlining (0 under LTO, 3 without).
- Task 2: the `fn` + `@export` form changes the default (non-LTO) `moar_zig.o` slightly. `MVM_index_hash_build` and `MVM_uni_hash_build` no longer inline their callee (0x170 to 0x61 bytes) and `MVM_str_hash_lvalue_fetch` grows by 3 bytes. The hot exports (`fetch_nocheck`, `fetch`, `delete`, `next`, `current_nocheck`, `first`) have the same sizes. Symbols, visibility and link commands are unchanged.
- Task 2: `Configure.pl` checks `$args{compiler}` (set by `--cc=zig`), not `$config{compiler}`, which Configure.pl never sets.
- Task 4: the Small payload grew from 4 to 8 bytes (`entries_offset` next to `capacity`); tags start at offset 16 instead of 12, and `entriesOffset` is unchanged for every capacity 8-64, so blocks are the same size. `find`'s return path (sentinel index instead of `?u32`) and the one-load zero-key test were in scope by the controller's ruling. The lever was measured whole, not part by part, because the whole moved outside the spread.
- Task 6: the lever reached into `table.zig` (by the controller's ruling): `ops.fetch`/`lvalue`/`delete`, `resolve` and `dispatch`'s `Op.f` are `inline fn`. The fetch, lvalue and delete paths call `dispatch` with `@call(.always_inline, ..)`. `dispatch`'s semantics and its other callers are unchanged. The brief's commit message became "hash engine: string wrapper chain inlined, cached-hash fast path". The ladder gained a warm-up size 16 in front of 64, because 64 as the first nqp size carried the warm-up (spreads of 15-49 ns in a first attempt).
- Task 5: `LoopState` was not restructured. The annotate showed the probe loops already in registers after Task 6: 7 instructions per fetch iteration, the same as the C, and nothing reloaded through the header. The lever also took `growInner`'s per-entry copy (inline 16 bytes, the C's `str_hash_table.c:419` fast path), which the brief ties to the shifts. The make-room and back-shift copies became pointer-walking `shiftDown`/`shiftUp` and not a generic `memmove(dest, src, n)` helper, because the indexed form made LLVM carry the copy addresses through the delete probe loop (spilled induction variables). One test was added: runs of 3+ entries back-shifted and made room for, at entry sizes 16 (inline path) and 24 (`@memmove`), checked with `fsck == 0`, lookups and payloads after every delete.
- Task 3: the brief's Step 1 measures lookup_hit and delete at 64 and 1024. By the controller's ruling it was widened to sizes 64, 65, 128, 1024 and 16384 (nqp with a warm-up 16) and to lookup_miss and insert. Because the protocol runs drifted between builds by more than the lever, the decision also uses interleaved runs: the same binaries, with the before, after and C `libmoar.so` swapped through `LD_LIBRARY_PATH`. The fetch and delete exports were also given one 32-bit status load (stale, set and control-only tested together), which the controller put in scope as "the same byte read". The stale read stays one volatile load per call, now 4 bytes wide. The brief's Small `entries_offset` item was Task 4's and was not redone. Beyond the brief's two tests, a two-set test Spec checks that set 1 reaches both of its rungs through `resolve`, and `hash_test.zig` asserts at comptime that the four single-rung tables have `dispatch_reads_set == false`. Not planned: LLVM now inlines Small's `findIn` for capacities 8 and 16 into the exports, which gives the gains at sizes 4-16.
