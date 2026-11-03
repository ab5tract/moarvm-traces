# Hash Layout Bake-off Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Three candidate hash layouts (Swiss-style groups, array-ordered, fixed-key sealed) as extra tier sets of the Zig string table, selectable at creation from C and NQP, measured on the nqp ladder against the default ladder, and turned into named strategies wherever one wins a contiguous block of cells by 10 percent.

**Architecture:** Each candidate is one tier module under `src/zig/core/hash/tiers/` behind the existing tier contract and one entry in `str.zig`'s set list; the header's existing `set` byte selects it. A strategy number reaches the engine through `MVM_str_hash_build_strategy` (C), `nqp::hashstrategy` (NQP) and the `MVM_HASH_STRATEGY` environment override (whole-system gate). The fixed-key candidate adds one policy-layer entry point, `seal`, which rebuilds a staging table into the sealed layout. Measurement reuses `tools/bench/hash-bench.nqp` with two new options and a new runner and aggregator; naming happens from the scoreboard at the end.

**Tech Stack:** Zig 0.16 (`@Vector(16, u8)` for the group probe), C (ops, REPR build sites), NQP (harness, op tests, two mapping lines), Perl (aggregator, as `hash-compare.pl`), the rakudo spectest.

**Spec:** `traces/llm/specs/2026-11-03-zig-hash-layout-bakeoff-design.md` (traces 5cd0d29). Earlier campaigns' specs and plans in the same directories are context for the tier contract and the measurement protocol.

## Global Constraints

- Set 0 of the string table (`standard`: Small then Robin Hood), `tiers/small.zig`, `tiers/robinhood.zig`, the set-0 dispatch and the migration path do not change (spec decision 5, section 10). Any diff to them is a plan violation unless a task names it.
- MoarVM work on branch `zig-hash-bakeoff` from `zig-hash-engine` (14452a8d3 or later). nqp work on branch `zig-hash-strategies` created from nqp 305ff2f77 (the checkout is on a detached HEAD there); nothing is committed in the rakudo checkout.
- New ops are appended at the end of `src/core/oplist`, never inserted, so every existing opcode number is unchanged and nqp's stage0 keeps running (Task 3 verifies).
- Builds: default options (`zig build install --prefix <P>`, LTO on, `-Doptimize=ReleaseFast`); before any `zig build` without `-Dconfig-h`: `rm -f src/gen/config.h src/gen/config.c src/gen/config.o`. Long runs go to background scripts logging under the scratchpad.
- The win rule (spec decision 2): a cell wins at ratio at or below 0.90 to the baseline with disjoint round spreads; a strategy needs a contiguous block (one op over adjacent sizes, or several ops over the same adjacent sizes). Memory is a reported column, not a gate.
- Every candidate passes `zig build unit-test`, `zig build test`, `zig build test_spec` and the full rakudo spectest as the process-wide default with zero new failures before its scoreboard column counts (spec decision 6).
- A tier's block survives a verbatim copy (`MVM_str_hash_shallow_copy` is a block copy): no absolute pointers into the block itself.
- `zig fmt --check` clean on every Zig file touched; Perl scripts pass `perl -c`; shell scripts pass `sh -n`.
- Commit attribution lines as the session reminder gives them; plan and bench records are committed inside `traces/` and the pointer bumped in MoarVM.

## Rulings made while planning

- Spec section 7 still says nqp's stage0 runs the op tests; section 3 (corrected after the builder check) says the rebuilt nqp must, because stage0 cannot compile the new ops. The plan follows section 3: Task 3's `strategy-test` step takes `-Dnqp-prefix` and runs the installed `nqp-m`. The spec gets an erratum at Task 9.
- "The set index is the strategy number" (spec 5.1) is implemented as a strategy-to-set mapping in `str.zig` (Task 2) so `large_only` keeps its index and the sealed set can sit anywhere; observable behaviour is identical.
- The aggregator is Perl (`hash-bakeoff.pl`), matching `hash-compare.pl`, not the session's scratch Python.

## Review Focus

1. `nqp::hashstrategy` on a hash that was filled and then emptied by deletes (table built, count 0): must demolish and rebuild without leaking the old block. Pinned in Task 3.
2. `nqp::clone` of a strategy hash: the clone keeps the strategy, and the two tables are independent afterwards (a verbatim block copy must not share anything). Pinned in Tasks 5, 6, 7.
3. Seal, then insert, then iterate and delete: the migration out of the sealed rung keeps every entry exactly once and the table stays usable. Pinned in Task 7.
4. `MVM_HASH_STRATEGY` set to an unknown value: the first hash use throws a readable error naming the value; no crash, no silent default. Pinned in Task 3.
5. GC marking walks hashes through the iteration API, so every new tier's `first`/`next` must visit each live entry exactly once and skip tombstones and holes; a miss is a use-after-free in the collector. Pinned by the fsck and iteration-count tests in Tasks 5, 6, 7 and by each candidate's spectest run.

---

### Task 1: Census of the five internal table kinds

**Files:**
- Create: `traces/llm/bench/bakeoff-census.md`
- Modify: this plan ("## Census" section appended)

**Interfaces:** none (reading only; no code changes).

- [ ] **Step 1: Enumerate creation sites.** For each of `MVM_str_hash_build`, `MVM_uni_hash_build`, `MVM_fixkey_hash_build`, `MVM_index_hash_build`, `MVM_ptr_hash_build` list every call site (`grep -rn` over `src/`), one row per site: file:line, the owning struct, the entry type, the size hint passed.
- [ ] **Step 2: Classify each site's operation mix** by reading the code around it: which of insert, fetch, lvalue-fetch, delete, iterate, shallow-copy, demolish it performs; whether the key set is complete at one moment (seal-able), grows with the program, or is cleared and refilled; lifetime (per frame, per compilation unit, per instance). One row per site, one line of justification each.
- [ ] **Step 3: Write `bakeoff-census.md`:** the table from steps 1 and 2 grouped by table kind, then a "Candidates this suggests" paragraph: which sites look like Swiss, ordered or fixed-key material, and any operation the ladder does not measure that a site depends on. If something there changes the spec, write it as a proposed erratum and stop for the user's ruling; otherwise proceed.
- [ ] **Step 4: Commit** inside `traces` ("bake-off: census of the internal hash tables") and bump the pointer in MoarVM ("traces: bake-off census").

---

### Task 2: The strategy selector: enum, C entry points, Zig wrapper, environment override

**Files:**
- Modify: `src/core/str_hash_table.h` (enum), `src/core/str_hash_table_funcs.h` (declarations), `src/core/str_hash_table.c` (C-engine bodies), `src/zig/core/hash/str.zig`, `src/zig/core/hash/str_exports.zig`, `src/core/instance.h`, `src/moar.c` (next to the `MVM_SPESH_DISABLE` reads), `src/6model/reprs/MVMHash.c:115,191`, `src/6model/reprs/HashAttrStore.c:33,96`, `docs/zig-build.md` (Hash engine section)
- Test: `src/zig/core/hash/test/str_test.zig`

**Interfaces:**
- Produces (C): `typedef enum { MVM_HASH_STRATEGY_DEFAULT = 0, MVM_HASH_STRATEGY_SWISS = 1, MVM_HASH_STRATEGY_ORDERED = 2, MVM_HASH_STRATEGY_FIXED = 3, MVM_HASH_STRATEGY_COUNT = 4 } MVMHashStrategy;` in `str_hash_table.h` (the names are bake-off names; Task 9 renames). `void MVM_str_hash_build_strategy(MVMThreadContext *tc, MVMStrHashTable *hashtable, MVMuint32 entry_size, MVMuint32 entries, MVMuint8 strategy);` and `void MVM_str_hash_seal(MVMThreadContext *tc, MVMStrHashTable *hashtable);` in `str_hash_table_funcs.h`. `MVMuint8 hash_strategy_default;` on `MVMInstance`.
- Produces (Zig, `str.zig`): `pub const strategy_count: u8 = 4;`, `pub const strategy_sets = [strategy_count]?u8{ standard_set, null, null, null };` (a null slot means "not built into this engine"; Tasks 5, 6, 7 edit the literal to fill slots 1, 2, 3), `pub fn buildStrategy(tc: *ThreadContext, ht: *c.MVMStrHashTable, entry_size: u32, entries: u32, strategy: u8) void`, `pub fn seal(tc: *ThreadContext, ht: *c.MVMStrHashTable) void` (a no-op until Task 7).
- Ruling recorded here: the spec's "the set index is the strategy number" is implemented as the `strategy_sets` mapping rather than by reordering the set list, so `large_only` keeps index 1 and the sealed set (Task 7) can live anywhere. Same observable behaviour; no set-0 change.

- [ ] **Step 1: Failing Zig tests** in `test/str_test.zig`:
  - `"buildStrategy with the default strategy is build"`: `buildStrategy(tc, &ht, 16, 0, 0)` then insert, fetch, count 1, `rung` 0, header `set` 0.
  - `"buildStrategy with a strategy that is not built in throws"`: strategies 1, 2, 3 and 4 each throw with a message containing `hash strategy` and the number (use the throw-catching helper `keyIsValid rejects a type object` already uses).
  - `"seal on a default table is a no-op"`: build, insert 3, seal, count 3, fetch all three.
- [ ] **Step 2: Run** `zig build unit-test --prefix $PWD/zig-out`. Expected: FAIL, `buildStrategy` undefined.
- [ ] **Step 3: Implement** `buildStrategy` (strategy at or above `strategy_count` or a null slot: `fail(tc, "hash strategy N is not available in this engine")` with the number formatted; else `StrTable.build(tc, handleOf(ht), entry_size, entries, strategy_sets[strategy].?)`), `seal` (no-op), `build` unchanged. Export both from `str_exports.zig` with the same `visibility` as the others. C engine: in `str_hash_table.c`, `MVM_str_hash_build_strategy` calls `MVM_str_hash_build` for strategy 0 and throws `"hash strategies need the Zig hash engine (strategy %u)"` otherwise; `MVM_str_hash_seal` is empty. Enum in the header.
- [ ] **Step 4: Run** the tests. Expected: PASS.
- [ ] **Step 5: Environment override.** `MVMInstance.hash_strategy_default` (0 by default); in `moar.c`, read `MVM_HASH_STRATEGY`; empty or unset leaves 0; else `strtol`, values outside 0..254 stored as 255 so the first build throws. MVMHash `bind_key` and `deserialize`, HashAttrStore `copy_to` and bind: replace `MVM_str_hash_build(tc, ht, size, n)` with `MVM_str_hash_build_strategy(tc, ht, size, n, tc->instance->hash_strategy_default)`. Deserialize's seal hook is Task 7's.
- [ ] **Step 6: Verify the override by hand:** `zig build install --prefix $PWD/zig-out`; `MVM_HASH_STRATEGY=1 ./zig-out/bin/moar --libpath=../src/vm/moar/stage0 ../src/vm/moar/stage0/nqp.moarvm -e 'my %h; %h<a> := 1'`. Expected: dies with `hash strategy 1 is not available in this engine`. Without the variable: runs. `MVM_HASH_STRATEGY=x`: dies with `hash strategy 255 ...`.
- [ ] **Step 7: Suites and docs.** `zig build unit-test`, `zig build test`, `zig build test_spec` pass. `docs/zig-build.md`: a paragraph "Strategies (bake-off)" naming the enum, the two C entry points and the override as a diagnostic, not an API. `zig fmt --check`.
- [ ] **Step 8: Commit** ("Hash strategies: selector, build_strategy, seal stub, MVM_HASH_STRATEGY override").

---

### Task 3: The two ops, the nqp branch, the op tests

**Files:**
- Modify: `src/core/oplist` (append), regenerated `src/core/ops.h`, `src/core/ops.c`, `src/core/oplabels.h`, `lib/MAST/Ops.nqp`, `tools/lib/MAST/Ops.rakumod` (by `tools/update_ops.raku`), `src/core/interp.c`, `build.zig` (new step), `docs/zig-build.md`
- Create: `tools/bench/t/strategy.nqp` (TAP-emitting nqp script)
- nqp checkout, branch `zig-hash-strategies`: `src/vm/moar/QAST/QASTOperationsMAST.nqp` (two entries in the core op pair list beside `'existskey', 'existskey',` at about line 3189), `docs/ops.markdown` (two entries)

**Interfaces:**
- Consumes: Task 2's `MVM_str_hash_build_strategy`, `MVM_str_hash_seal`, `MVMHashStrategy`.
- Produces: ops `hashstrategy  w(obj) r(obj) r(int64) r(int64)` and `hashseal  w(obj) r(obj)`, both without `:pure` or `:specializable`; `nqp::hashstrategy(%h, $strategy, $size)` returns `%h`; `nqp::hashseal(%h)` returns `%h`. Build option `-Dnqp-prefix=<P>` and step `strategy-test` in `build.zig` (runs `<P>/bin/nqp-m tools/bench/t/strategy.nqp` with the installed moar's `libmoar.so` on `LD_LIBRARY_PATH=<P>/lib`); `zig build test` depends on it when the option is given.

- [ ] **Step 1: Failing nqp test** `tools/bench/t/strategy.nqp` (prints TAP with `say("ok N - ...")`, exits non-zero on any failure), cases:
  - strategy 0 on a fresh hash: bind 3 keys, `nqp::existskey` each, `nqp::elems` 3, delete one, elems 2, iterate counts 2.
  - strategy 0 with size hint 1000: same round trip.
  - `hashstrategy` on a non-empty hash: dies, message contains `non-empty`.
  - `hashstrategy` after fill-then-delete-all (built, count 0): succeeds, round trip works (Review Focus 1).
  - `hashstrategy` on a non-hash (an int, a list): dies.
  - unknown strategy 9: dies with `hash strategy 9`.
  - `hashseal` on a default hash: returns the hash, contents unchanged; twice is fine.
  - strategies 1, 2, 3: die with `not available` (Tasks 5-7 flip these cases to round trips).
- [ ] **Step 2: Run it** on the current prefix: `/tmp/claude-1000/tune-zig-prefix/bin/nqp-m tools/bench/t/strategy.nqp`. Expected: dies at compile time, `No registered operation handler for 'hashstrategy'`.
- [ ] **Step 3: Ops.** Append the two lines to `src/core/oplist`; run `/tmp/claude-1000/tune-zig-prefix/bin/raku tools/update_ops.raku` from the MoarVM root; confirm with `git diff --stat` that only the five generated files changed and that `src/core/ops.h`'s existing opcode numbers are unchanged (`git diff src/core/ops.h | grep '^-#define MVM_OP_' | wc -l` is 0). `interp.c`: `OP(hashstrategy)`: operand 1 must be concrete with `REPR(obj)->ID == MVM_REPR_ID_MVMHash`, else throw `"hashstrategy needs a concrete hash"`; if the table is built and `MVM_str_hash_count` is nonzero throw `"hashstrategy on a non-empty hash"`; if built and empty, `MVM_str_hash_demolish` first; then `MVM_str_hash_build_strategy(tc, ht, sizeof(MVMHashEntry), (MVMuint32)size, (MVMuint8)strategy)` with negative or over-255 strategy mapped to 255; write the object to the result register. `OP(hashseal)`: same REPR check, `MVM_str_hash_seal`, return the object.
- [ ] **Step 4: nqp branch.** In the nqp checkout: `git switch -c zig-hash-strategies 305ff2f77`; add `'hashstrategy', 'hashstrategy',` and `'hashseal', 'hashseal',` to the pair list; document both in `docs/ops.markdown` next to `existskey` (signature, what they do, that misuse dies). Commit there with the attribution lines ("Map hashstrategy and hashseal to the MoarVM ops").
- [ ] **Step 5: Rebuild the stack onto the Zig prefix:** `rm -f src/gen/config.*; zig build install --prefix /tmp/claude-1000/tune-zig-prefix`; then in nqp `make && make install` (configured for that prefix; `Makefile` says so); then in rakudo `make install` (its installed compiler must see the rebuilt nqp lib). Background script, logs in the scratchpad.
- [ ] **Step 6: Run the test** with the rebuilt nqp. Expected: all cases pass except the three "not available" ones pass as deaths. Also `zig build test` (stage0 smoke) still passes: opcode numbering is intact.
- [ ] **Step 7: Build step.** `-Dnqp-prefix` option in `build/zig/options.zig`; `strategy-test` step in `build.zig` as described; `zig build strategy-test -Dnqp-prefix=/tmp/claude-1000/tune-zig-prefix --prefix $PWD/zig-out` passes. Docs: the two ops under the strategies paragraph.
- [ ] **Step 8: Commit** MoarVM ("hashstrategy and hashseal ops; strategy-test step").

---

### Task 4: Harness: `--strategy`, `--seal`, `bulk_load`, the bake-off runner and aggregator, the baseline check

**Files:**
- Modify: `tools/bench/hash-bench.nqp`, `tools/bench/hash-bench.sh` (document that the nqp harness now takes `--strategy=` and `--seal`)
- Create: `tools/bench/hash-bakeoff.sh`, `tools/bench/hash-bakeoff.pl`, `tools/bench/t/hash-bakeoff.t`
- Record: `traces/llm/bench/bakeoff-baseline-check.md`

**Interfaces:**
- Consumes: Task 3's ops; Task 2's override is not used here (selection is per hash through the op so one process image serves every strategy).
- Produces: `hash-bench.nqp --strategy=N` (after each `nqp::hash()` in every timed phase: `nqp::hashstrategy(%h, N, $n)`; default 0, which still calls the op so the baseline pays the same call), `--seal` (after each fill loop and before the lookup, iterate and delete phases: `nqp::hashseal(%h)`; with `--seal` the `insert` and `insert_nth` rows are not emitted, with a comment in the source saying why: they would time the staging table), four new op rows, all per entry and emitted for every strategy: `bulk_load` (insert N then seal; seal is a no-op without a sealable strategy so the column is comparable), `overwrite` (bind each of the N present keys again with a new value, on the filled hash), `clone` (`nqp::clone` of the filled hash, the clone kept alive until the timing ends), and `iterate_delete` (one `for` over the filled hash deleting the current key with `nqp::deletekey` inside the loop, the MVMIter delete-at-current path; the hash is empty afterwards and is refilled before the next phase, as `delete` already does). These three were added by the user on 2026-11-03 from the census (Task 1, erratum E2). The `engine` column carries `zig-s<N>` so TSVs per strategy differ.
  `hash-bakeoff.sh --prefix=<P> --strategies=0,1,2,3 --rounds=7 --out=<dir> [--sizes= --runs= --nth=]`: per round, rotates the strategy order (round r starts at strategy index r mod k), runs the nqp harness once per strategy with `<P>/bin/nqp-m` (strategy 3 with `--seal`), appends rows `round strategy size op ns rss ns_min ns_max` to `<dir>/raw.tsv`, logs load average per run.
  `hash-bakeoff.pl <raw.tsv> [--base=0] [--win=0.90]`: ops in the fixed order insert, lookup_hit, lookup_miss, delete, iterate, insert_nth, bulk_load, overwrite, clone, iterate_delete; per (strategy, size, op): median of round medians, min and max of round medians, median rss; ratio to the base strategy's cell; verdict `win` when ratio at or below `--win` and spreads disjoint, `n/a` when the cell is missing, else `-`; then block detection: for each strategy and op, maximal runs of adjacent ladder sizes (the fixed order 16, 32, 63, 64, 65, 128, 256, 1024, 16384; size 4 is warm-up and never judged; 49 and 97 are resize cells reported but not blocked) that are all `win`; and multi-op blocks: size runs on which two or more ops all win. Output: markdown, one table per op (rows sizes, columns strategies, cell `ratio [spread]` plus memory ratio), then a "Blocks" list per strategy. Fixture test `t/hash-bakeoff.t`: a 2-strategy, 3-size, 2-op raw file in, the expected ratios, verdicts and one detected block out (written as `hash-compare.t` is).
- Ruling: Perl, not Python, for the aggregator, matching `hash-compare.pl`.

- [ ] **Step 1: Fixture test** `tools/bench/t/hash-bakeoff.t` (as above), run `prove tools/bench/t/hash-bakeoff.t`. Expected: FAIL, script missing.
- [ ] **Step 2: Write `hash-bakeoff.pl`**; run the fixture. Expected: PASS.
- [ ] **Step 3: Harness options** in `hash-bench.nqp`; verify by hand on the rebuilt prefix: `--strategy=0 --sizes=16,64 --runs=2` emits the usual rows plus `bulk_load`, `overwrite`, `clone` and `iterate_delete`; `--strategy=0 --seal --sizes=16 --runs=2` emits no `insert`/`insert_nth` rows; `--strategy=1` dies with `not available` (until Task 5).
- [ ] **Step 4: Write `hash-bakeoff.sh`**; `sh -n`; dry run `--strategies=0 --rounds=2 --sizes=16,64,128 --runs=2` producing `raw.tsv` and a scoreboard with a single column of ratios 1.00 and no blocks.
- [ ] **Step 5: Baseline check** (spec section 6): `hash-bakeoff.sh --strategies=0 --rounds=5` with the ladder sizes; compare the strategy-0 absolute medians with `traces/llm/bench/tuning-lto-default-il-nqp-zig-lto.tsv` cell by cell: each within the recorded spread or within 5 percent. Record `bakeoff-baseline-check.md`. If a cell is out, stop and find what moved (the op call per hash is the first suspect; if it is the cause, the baseline for the campaign is strategy 0 with the call, and the record says so with the measured cost).
- [ ] **Step 6: Commit** MoarVM ("hash bench: --strategy, --seal, bulk_load; bake-off runner and aggregator"); traces ("bake-off: baseline check").

---

### Task 5: Candidate 1, Swiss-style metadata groups (`MVM_HASH_STRATEGY_SWISS`)

**Files:**
- Create: `src/zig/core/hash/tiers/swiss.zig`
- Modify: `src/zig/core/hash/str.zig` (`swiss_only` set; `strategy_sets[1]`), `src/zig/core/hash/test_spec.zig` (a `swiss_test_set`), `build.zig` (add `tiers/swiss.zig` to the pure-Zig unit test roots), `src/zig/core/hash/test/str_test.zig`, `tools/bench/t/strategy.nqp` (strategy 1 cases become round trips), `docs/zig-build.md`
- Record: `traces/llm/bench/bakeoff-spectest-s1.txt`

**Interfaces:**
- Consumes: the tier contract as `tiers/robinhood.zig` implements it: `Tier(cfg) type` with `max_capacity`, `Impl(Spec)` providing `LvalueResult`, `init(allocator, header_init, cap) !*Header`, `capacity`, `isFull`, `hash`, `fetch`, `lvalueFetch`, `insertKnownAbsent`, `delete`, `grow` (`!?*Header`, null means migrate), `first`/`next`/`entryAt`/`start`/`drain` (iteration), `allocatedSize`, `blockStart`, `fsck`.
- Produces: `swiss.Tier(.{})` with `max_capacity = maxInt(u32)`; layout: capacity a power of two, metadata array of one byte per slot after the header (`0x80` empty, `0xFE` deleted, `0x00..0x7F` the top 7 bits of the hash), entries array after it, probe by 16-slot groups with `@Vector(16, u8)` compares, group start from the low bits of the hash, load limit 7/8; `grow` doubles in place to a new block when the load limit is hit, or rehashes at the same capacity when tombstones alone pushed it over (the rehash threshold is the builder's); iteration descending over slots with metadata below `0x80` (the MVMIter protocol in `str_test` line 206 requires descending order). No pointers into the block.

- [ ] **Step 1: Failing pure-Zig tests** in `tiers/swiss.zig` using `test_spec.IntSpec` with `swiss_test_set` (one rung, `from = 0`):
  - `"insert, fetch, delete across group boundaries"`: 100 keys, every fetch hits, delete the even ones, fetch of deleted misses, count 50.
  - `"grow keeps every entry"`: insert 10_000 keys through `table.zig`'s `Table(IntSpec)` (so grow is driven by the policy layer), fetch all, iteration visits 10_000 distinct keys.
  - `"tombstones do not accumulate forever"`: insert 64, then 100_000 rounds of insert-a-fresh-key-delete-an-old-key keeping the count at 64; `allocatedSize` never exceeds four times its value after the first 64 inserts.
  - `"random ops match std.AutoHashMap"`: seed 0x5eed, 20_000 random insert/fetch/delete on keys below 4_096, compared against `std.AutoHashMap(u64, void)` after every op.
  - `"fsck finds no fault"` after the random test.
- [ ] **Step 2: Run** `zig build unit-test`. Expected: FAIL (module missing).
- [ ] **Step 3: Implement `tiers/swiss.zig`**; run until PASS.
- [ ] **Step 4: C-API tests** in `test/str_test.zig`: `"strategy 1 round trip through the C-shaped API"` (buildStrategy 1, 300 real MVMString keys, fetch, delete, iterate), `"strategy 1 shallow copy is independent"` (copy, insert into one, the other unchanged: Review Focus 2), `"strategy 1 header set byte is the swiss set"`. Wire `strategy_sets[1]`. Run until PASS. `zig fmt --check`.
- [ ] **Step 5: nqp test** flip strategy 1 to round trips plus `nqp::clone` keeps contents and independence; `zig build strategy-test -Dnqp-prefix=...` passes after `zig build install --prefix /tmp/claude-1000/tune-zig-prefix`.
- [ ] **Step 6: Whole-system gate:** in the rakudo checkout, `MVM_HASH_STRATEGY=1 make spectest` (`TEST_JOBS=24`, background, scratchpad log; the roast commit noted). Expected: zero failures beyond the default run's (compare with `traces/llm/bench/post-lto-spectest.txt`'s failure list, which is empty for the Zig engine). Record `bakeoff-spectest-s1.txt` (summary lines and any failing files).
- [ ] **Step 7: Quick ladder sanity:** `hash-bakeoff.sh --strategies=0,1 --rounds=2 --sizes=16,64,1024` runs and produces ratios; no judgement yet.
- [ ] **Step 8: Commit** MoarVM ("Swiss-style tier as strategy 1"); traces ("bake-off: strategy 1 spectest").

---

### Task 6: Candidate 2, array-ordered entries with a side index (`MVM_HASH_STRATEGY_ORDERED`)

**Files:**
- Create: `src/zig/core/hash/tiers/ordered.zig`
- Modify: `str.zig` (`ordered_only` set; `strategy_sets[2]`), `test_spec.zig`, `build.zig`, `test/str_test.zig`, `tools/bench/t/strategy.nqp`, `docs/zig-build.md`
- Record: `traces/llm/bench/bakeoff-spectest-s2.txt`

**Interfaces:**
- Consumes: the tier contract (Task 5's list).
- Produces: `ordered.Tier(.{})`, `max_capacity = maxInt(u32)`; layout: header, then an index table of `cap_index` slots (open addressing, linear probing, slot width `u8` while the entry capacity is below 255, `u16` below 65_535, else `u32`, the width recorded in the block so a verbatim copy reads it back; a slot holds the entry's position plus one, 0 empty), then the dense entries array in insertion order with `cur_items` live entries. `delete` is swap-remove: the last entry moves into the hole and its index slot is updated; index tombstones are avoided by backward-shift deletion in the index. Iteration descends over the dense array (`first` = count - 1), which makes "delete current while holding next" safe with swap-remove. `grow` doubles both arrays into a new block. No pointers into the block.

- [ ] **Step 1: Failing pure-Zig tests** in `tiers/ordered.zig` (same spec style as Task 5): `"iteration is insertion order until the first delete"` (insert 50, iteration visits them in reverse insertion order), `"swap-remove keeps every other entry reachable"` (insert 1000, delete every third key, fetch all remaining, count correct), `"delete current while iterating visits every live entry exactly once"` (the MVMIter protocol: hold next, delete current, continue; 500 entries, delete all; visited set equals the key set), `"index width changes at the thresholds"` (insert 300 then 70_000 through the policy layer; fetch all after each threshold), `"random ops match std.AutoHashMap"`, `"fsck finds no fault"`.
- [ ] **Step 2: Run** `zig build unit-test`. Expected: FAIL.
- [ ] **Step 3: Implement**; PASS.
- [ ] **Step 4: C-API tests** (`"strategy 2 round trip"`, `"strategy 2 shallow copy is independent"`, `"strategy 2 iteration with deletes matches MVMIter's protocol"`); wire `strategy_sets[2]`.
- [ ] **Step 5: nqp test** flip strategy 2; `strategy-test` passes.
- [ ] **Step 6: Whole-system gate** `MVM_HASH_STRATEGY=2 make spectest`; record `bakeoff-spectest-s2.txt`. Note in the record whether any roast test exposed order dependence (none is expected; the default order is randomised and roast must not depend on it, but a test that happens to pass only with insertion order is worth a line).
- [ ] **Step 7: Commit** MoarVM ("Array-ordered tier as strategy 2"); traces.

---

### Task 7: Candidate 3, fixed key set with seal (`MVM_HASH_STRATEGY_FIXED`)

**Files:**
- Create: `src/zig/core/hash/tiers/fixed.zig`
- Modify: `src/zig/core/hash/table.zig` (new `seal`; nothing else), `src/zig/core/hash/tier.zig` (contract comment: optional `initFrom`), `str.zig` (`fixed_staging` and `fixed_sealed` sets; `strategy_sets[3]`; `seal` implemented), `src/6model/reprs/MVMHash.c:191` (seal after deserialize under the override), `test_spec.zig`, `build.zig`, `test/str_test.zig`, `tools/bench/t/strategy.nqp`, `docs/zig-build.md`
- Record: `traces/llm/bench/bakeoff-spectest-s3.txt`

**Interfaces:**
- Consumes: the tier contract; `table.zig`'s `migrate`/`publish` (unchanged); Task 2's `seal` stub.
- Produces:
  - Tier contract addition (optional): `initFrom(allocator: std.mem.Allocator, header_init: Header, ctx: Ctx, entries: []const [*]u8) !*Header`, builds a block holding copies of the given entries (each `entry_size` bytes, key at the start, hash via `Spec.hash(ctx, key)`).
  - `table.zig`: `pub fn seal(ctx: Ctx, h: Handle, comptime to_set: u8) void`: no-op if `h` is unbuilt; otherwise collects the live entries' pointers into a temporary slice (iteration API), calls `Spec.sets[to_set][0].tier.initFrom(...)` with a header of `set = to_set, tier = 0`, publishes the new block through the existing `publish` (stale mark, safepoint free, CAS) and returns. Control-only tables become a sealed block of zero entries. The migration code is not touched.
  - `fixed.Tier(.{})`: `max_capacity = maxInt(u32)`; `isFull` always true, `lvalueFetch` of an absent key returns `.full`, `grow` returns null (so the first insert migrates to rung 1); `delete` marks a tombstone bit for the entry (count drops, lookup misses, iteration skips), never rebuilds; layout: builder's choice under spec 4.3 (default suggestion: 2^k buckets with k such that buckets are at least the entry count, entries stored in hash-bucket order in a dense array, a `u32` offset table of 2^k + 1, lookup compares the stored 64-bit hash then the key; build is a counting sort, expected linear). No pointers into the block.
  - `str.zig`: `fixed_staging = [_]TierEntry{ .{ .tier = robinhood.Tier(.{}), .from = 0 } }` (strategy 3 builds here), `fixed_sealed = [_]TierEntry{ .{ .tier = fixed.Tier(.{}), .from = 0 }, .{ .tier = robinhood.Tier(.{}), .from = 1 } }`; `const fixed_staging_set: u8` and `const fixed_sealed_set: u8` are their indices in `StrSpec.sets`; `seal(tc, ht)`: if the header's set is `fixed_staging_set`, `StrTable.seal(tc, handle, fixed_sealed_set)`; any other set is a no-op (so sealing twice is a no-op: the second time the set is `fixed_sealed`).
  - `MVMHash.c` deserialize: after the fill loop, `if (tc->instance->hash_strategy_default == MVM_HASH_STRATEGY_FIXED) MVM_str_hash_seal(tc, hashtable);`.
- Ruling: `fixed_sealed`'s rung 1 `from = 1` satisfies `tier.validate` (strictly increasing from 0) and is never used by `startingRung` because nothing builds `fixed_sealed` directly; the migration from rung 0 to rung 1 is the existing path, driven by `grow` returning null.

- [ ] **Step 1: Failing pure-Zig tests** in `tiers/fixed.zig` and `table.zig` (seal), via `test_spec.IntSpec` with the two sets added to `test_spec.zig`:
  - `"seal builds a sealed table that finds every key"`: build staging, insert 1000, `Table.seal`, header set is the sealed set, fetch all 1000, miss on 1000 absent keys, count 1000.
  - `"seal of an unbuilt or empty table"`: unbuilt stays unbuilt; control-only becomes sealed with count 0; fetch misses.
  - `"insert after seal migrates to Robin Hood and keeps every entry"`: seal 500, insert 1 more, header tier is rung 1, fetch all 501 (Review Focus 3).
  - `"delete after seal is a tombstone"`: seal 100, delete 10, count 90, fetch of the 10 misses, iteration visits 90, `allocatedSize` unchanged.
  - `"delete then insert after seal"`: seal 100, delete 10, insert 5 new: migrated, count 95, all reachable.
  - `"random ops after seal match std.AutoHashMap"` (sealed with 2_000, then 10_000 random fetch/delete; the first insert ends the sealed phase and the test continues on the migrated table).
  - `"fsck finds no fault"` on a sealed table and after migration.
- [ ] **Step 2: Run** `zig build unit-test`. Expected: FAIL.
- [ ] **Step 3: Implement** `initFrom` in the contract comment, `fixed.zig`, `Table.seal`; PASS.
- [ ] **Step 4: C-API tests**: `"strategy 3 seal through the C-shaped API"` (buildStrategy 3 with 300 real keys, seal, fetch, iterate, one insert, fetch all 301), `"strategy 3 shallow copy of a sealed table is independent"`, `"seal publishes with the stale mark"` (as `migration marks the old block stale and publishes by CAS` does). Wire `strategy_sets[3]` and `str.seal`.
- [ ] **Step 5: nqp test** flip strategy 3: round trip with seal, insert after seal works, `hashseal` twice, clone of a sealed hash. `strategy-test` passes.
- [ ] **Step 6: Whole-system gate** `MVM_HASH_STRATEGY=3 make spectest`: every deserialized hash is sealed (the setting's hashes included), every lazily built hash is a staging Robin Hood table. Record `bakeoff-spectest-s3.txt`, and in it the count of sealed tables that migrated, if cheap to obtain (a counter under `MVM_HASH_STRATEGY` only is acceptable; otherwise say it was not measured).
- [ ] **Step 7: Commit** MoarVM ("Fixed-key sealed tier as strategy 3; Table.seal"); traces.

---

### Task 8: The bake-off

**Files:**
- Record: `traces/llm/bench/bakeoff-raw.tsv`, `bakeoff-scoreboard.md`, `bakeoff-load.log`; this plan ("## Scoreboard" section)

**Interfaces:** consumes Task 4's runner and aggregator, Tasks 5-7's strategies.

- [ ] **Step 1: One build, one prefix.** `zig build install --prefix /tmp/claude-1000/tune-zig-prefix` of the branch head; `strategy-test` green; load average under 2 before starting.
- [ ] **Step 2: Rounds.** `hash-bakeoff.sh --prefix=/tmp/claude-1000/tune-zig-prefix --strategies=0,1,2,3 --rounds=7 --sizes=4,16,32,63,64,65,128,256,1024,16384 --runs=5 --nth=all --out=<scratch>` then the resize cells `--sizes=49,97` the same way into a second directory. Background; expected about 4 strategies × 7 rounds × 15 s per round.
- [ ] **Step 3: Aggregate.** `hash-bakeoff.pl raw.tsv > bakeoff-scoreboard.md` (ladder) and append the resize cells and the `bulk_load` table. Baseline check again: strategy 0's cells against `bakeoff-baseline-check.md`.
- [ ] **Step 4: Read the scoreboard** and write the plan's "## Scoreboard" section: per strategy, its blocks (op, size run, ratio range, memory ratio range), cells that nearly won (0.90 to 0.95) as a note, and the `bulk_load` column. No naming yet.
- [ ] **Step 5: Commit** traces ("bake-off: scoreboard") and the pointer.

---

### Task 9: Naming the strategies, deleting the losers, composed sets, documentation

**Files:**
- Modify: `src/core/str_hash_table.h` (enum renamed), `str.zig` (sets, `strategy_sets`), `src/core/interp.c` (nothing unless a name appears in a message), `tools/bench/t/strategy.nqp`, `docs/zig-build.md`, nqp `docs/ops.markdown` (strategy numbers and names)
- Create: `docs/hash-strategies.md`
- Delete: the losing tiers' files, sets, tests, enum entries, harness mentions
- Record: `traces/llm/bench/bakeoff-composed-*.md` if any composed set is measured; `bakeoff-spectest-<name>.txt` per shipped strategy

**Interfaces:** consumes the "## Scoreboard" section; produces the final `MVMHashStrategy` enum (`MVM_HASH_STRATEGY_DEFAULT = 0` then the named strategies in scoreboard order, `MVM_HASH_STRATEGY_COUNT`).

- [ ] **Step 1: STOP for the user.** From the scoreboard, list each strategy with blocks and propose two names per strategy that say what the program wants (not the layout). Also propose, per winner, whether a composed set (Small below it; Robin Hood above it for the fixed candidate is already the case) is worth measuring, with the cells that suggest it. Wait for the user's names and composition choices. This is the one planned stop.
- [ ] **Step 2: Composed sets, if chosen:** add the set, measure it with `hash-bakeoff.sh` against strategy 0 under the same rounds, run its spectest as the override; it ships only if it wins its block under the rule; record `bakeoff-composed-<name>.md`.
- [ ] **Step 3: Rename** the enum entries and the `strategy_sets` slots to the chosen names; renumber so strategies are contiguous from 1; update the nqp test and `docs/ops.markdown` (nqp branch commit).
- [ ] **Step 4: Delete the losers:** tier file, set, `test_spec` set, `build.zig` root entry, C-API tests, nqp test cases, docs mention. `zig build unit-test`, `test`, `test_spec`, `strategy-test` green.
- [ ] **Step 5: Documentation.** `docs/hash-strategies.md`: the selector (C entry points, the two ops, the override as a diagnostic), one section per strategy: the blocks it won with ratios and memory ratios, what it gives up (ordered: order exposure until the first delete, and that order is a property of the strategy not of hashes; fixed: migration on write after seal, tombstone deletes), how to select it. `docs/zig-build.md`: the strategies paragraph points there. The spec gets an erratum listing the final names.
- [ ] **Step 6: Commit** MoarVM ("Hash strategies named: <names>; losers removed; docs"), nqp branch, traces.

---

### Task 10: Incremental resize on the insert winner (bounded experiment)

**Files:**
- Create or modify: the winning tier's file (or `tiers/robinhood.zig` if no candidate won the insert block, which is the one case this plan allows a Robin Hood diff), `str.zig` if a wrapper set is needed
- Record: `traces/llm/bench/bakeoff-incremental.md`; this plan ("## Incremental resize" section)

**Interfaces:** consumes the named strategies; produces nothing unless kept.

- [ ] **Step 1: Design in one page** in the plan section: how the grow is split (the classic two-table scheme: new block allocated at the trigger, a fixed number of old entries moved per subsequent insert, lookups probing both until the move completes), what `insert_nth` should show (the spike at 65 and at the Robin Hood doublings spread over the following inserts).
- [ ] **Step 2: Implement behind a comptime flag** on the tier (`incremental: bool`), unit tests: every entry reachable during a partially moved state; random ops match the reference map across several grows; fsck.
- [ ] **Step 3: Measure** with `hash-bakeoff.sh` the flagged set against the unflagged one, 7 rounds, `--nth=all` plus the resize cells; the `insert_nth` cells decide under the win rule; the other cells must not lose (no cell at or above 1.05 with disjoint spreads).
- [ ] **Step 4: Keep or revert** by the rule; record either way; if kept, its spectest run as the override and a `docs/hash-strategies.md` paragraph.
- [ ] **Step 5: Commit** (or revert and commit the record only).

---

### Task 11: Whole-system acceptance

**Files:**
- Record: `traces/llm/bench/bakeoff-final-nqp.md` and TSVs, `bakeoff-final-spectest.txt`; this plan ("## Acceptance" section); `docs/zig-build.md` scoreboard paragraph (the default ladder figures if they moved)

- [ ] **Step 1: Default ladder against the C engine** with the tuning campaign's Task 8 recipe (two installs of the branch head, `-Dzig-impl=false` and default, interleaved rounds, `hash-compare.pl`): every cell passes as `tuning-lto-default-nqp.md` did (53/53 or within spread). A regression here means the selector or a shared file moved the baseline; find it before accepting.
- [ ] **Step 2: Spectest with the default** (no override) on the final build: zero failures, wall and RSS within 2 percent of `post-lto-spectest.txt`'s Zig medians.
- [ ] **Step 3: Acceptance table** in the plan against spec section 12, one row per criterion with the evidence file.
- [ ] **Step 4: Trees clean**, nqp branch committed, final commit and traces pointer; then the final whole-branch review as the executing skill prescribes.

---

## Measurement conventions (for every task that measures)

Build under test installed into `/tmp/claude-1000/tune-zig-prefix` with `zig build install --prefix` (after the `rm -f src/gen/config.*`), the rebuilt nqp and rakudo of Task 3 on top. Ladder runs through `tools/bench/hash-bakeoff.sh`; rounds interleaved with the strategy order rotated; load average noted per run in `bakeoff-load.log`; spreads are the min and max of round medians; nothing is judged from a single run. Spectests from the rakudo checkout, `TEST_JOBS=24`, the roast commit recorded, timed with the session's `timev.py` stand-in only when wall and RSS are part of the criterion (Task 11).

## Census

Record: `traces/llm/bench/bakeoff-census.md` (Task 1, static read, no code changes).

- 26 creation sites: 21 `MVM_*_hash_build` calls (str 8, uni 2, fixkey 8, index 2, ptr 1) plus 5 implicit ones (zero-filled tables and shallow copies): str 9, uni 4, fixkey 8, index 3, ptr 2.
- No spesh, JIT, NFG or serialization-internal tables; those subsystems only call registry lookups or deserialize MVMHash.
- Fixed-key material: the unicode name tables (u1-u4, bulk-loaded from static arrays, then fetch only, the largest at about 65k keys), every static frame's `lexical_names` index table (i2/i3, presized bulk load then miss-heavy fetch), the syscall and container registries, debug locals, and MVMHash up to the end of `deserialize`.
- Swiss material: the general MVMHash (s5), `sc_weakhash`, `object_ids` (insert and fetch-and-delete churn), the heap snapshot's `seen` table (millions of insert-if-absent probes).
- Array-ordered material: MVMHash under GC marking, serialization and `MVMIter`; `sc_weakhash` and the native callback cache (iterated every GC); HashAttrStore's clone-by-reinsert.
- Not on the ladder: overwrite (lvalue-fetch of a present key), clone (shallow copy), delete at the current iterator position, fetch-and-delete (ptr only).
- Proposed errata for the user: E1, the array tier must iterate last-to-first so swap-remove under `MVMIter` delete-at-current does not skip entries; E2, `overwrite` (and optionally `clone`, `iterate_delete`) ladder cells; E3, the best fixed-key sites are uni and index tables, outside the str-only candidates, so the next campaign needs ports; E4, spec 5.3 names an MVMHash `initialize` that does not exist (the build is lazy in `bind_key`).

## Scoreboard

Measured 2026-11-03 on d3d8dbf90, one prefix, 7 rounds with the strategy order rotated, `--runs=5 --nth=all --hint=0`, strategy 3 with `--seal` (its insert and insert_nth cells are n/a); load 0.69-1.18. Ratios are the strategy's median of round medians over strategy 0's in the same rounds (below 1 is faster); a win is at or below 0.90 with disjoint round spreads; a block is two or more adjacent winning ladder sizes (16 32 63 64 65 128 256 1024 16384). Records: `traces/llm/bench/bakeoff-scoreboard.md` (header, every table, the aggregator's Blocks list, the resize cells, the baseline check), `bakeoff-raw.tsv`, `bakeoff-raw-resize.tsv`, `bakeoff-load.log`.

The memory ratio is the ru_maxrss delta over a size's runs: below 65 it is a few pages or none, so its small-size values (strategy 3's 35.98 at 32 and 0.00 at 64-65) are page noise; from 128 up it reads as layout size.

**Baseline check.** Strategy 0 agrees with its reference (`bakeoff-baseline-s0.tsv`) in 83 of 110 judged cells. All 27 that differ are slower. Seven of them are size 49, which is now the first size its process measures and carries warm-up. Nine ladder cells are out by more than 10 percent: `clone` at 16-128 and 16384 (1.11-2.27) and `insert_nth` at 128-256 (1.12-1.14). This is a same-direction move, either from the build (three more tiers in the dispatch) or from the machine. A slower strategy 0 there makes the other strategies' `clone` and `insert_nth` ratios look better by the same factor. Left to the controller.

### Blocks (the aggregator's list, with ratio range and memory ratio range over the block's cells)

**Strategy 1**
- insert 128-16384: 0.77-0.84, mem 0.70-1.00
- lookup_hit 128-256: 0.87-0.89, mem 0.70-0.73
- lookup_miss 63-16384: 0.80-0.90, mem 0.70-2.07 (63-64 sit on the line at 0.89-0.90 with mem 1.81-2.07)
- delete 65-256: 0.88-0.90, mem 0.70-0.73
- iterate 65-16384: 0.68-0.69, mem 0.70-1.00
- insert_nth 65-128: 0.03-0.81, mem 0.70-0.71 (0.03 is the 64-to-65 growth step strategy 0 pays, about 1080 ns)
- bulk_load 128-16384: 0.81-0.87, mem 0.70-1.00
- overwrite 65-16384: 0.79-0.89, mem 0.70-1.00
- clone 65-16384: 0.58-0.75, mem 0.70-1.00
- iterate_delete 65-16384: 0.78-0.83, mem 0.70-1.00
- multi-op lookup_miss+delete+iterate+insert_nth+overwrite+clone+iterate_delete 65-128: 0.03-0.89, mem 0.70-0.71
- multi-op lookup_miss+delete+iterate+overwrite+clone+iterate_delete 65-256: 0.58-0.90, mem 0.70-0.73
- multi-op lookup_miss+iterate+overwrite+clone+iterate_delete 65-16384: 0.58-0.89, mem 0.70-1.00
- multi-op insert+lookup_hit+lookup_miss+delete+iterate+bulk_load+overwrite+clone+iterate_delete 128-256: 0.58-0.90, mem 0.70-0.73 (every op it runs except insert_nth)
- multi-op insert+lookup_miss+iterate+bulk_load+overwrite+clone+iterate_delete 128-16384: 0.58-0.89, mem 0.70-1.00

**Strategy 2**
- insert 128-16384: 0.60-0.66, mem 0.35-0.55
- iterate 65-16384: 0.62-0.70, mem 0.35-0.74
- bulk_load 128-16384: 0.69-0.72, mem 0.35-0.55
- clone 65-16384: 0.33-0.53, mem 0.35-0.74
- multi-op iterate+clone 65-16384: 0.33-0.70, mem 0.35-0.74
- multi-op insert+iterate+bulk_load+clone 128-16384: 0.33-0.72, mem 0.35-0.55

**Strategy 3** (sealed)
- iterate 65-16384: 0.66-0.68, mem 1.11-1.65 from 128 up (0.00 at 65 is noise)
- clone 65-16384: 0.52-0.69, same memory
- multi-op iterate+clone 65-16384: 0.52-0.69, same memory

Lone wins (one ladder size, so not a block): strategy 1 insert_nth 1024 (0.76); strategy 2 lookup_hit 65 (0.85), lookup_miss 65 (0.83), overwrite 65 (0.84), insert_nth 65 (0.65); strategy 3 overwrite 65 (0.85).

**Near-wins (note).** 0.90-0.95 without a win: strategy 1 delete 32, 63, 64, 1024 (0.93-0.95), iterate 63 (0.94), lookup_hit 1024 (0.92), overwrite 63-64 (0.91); strategy 2 clone 16 and 63 (0.93-0.94), insert_nth 16384 (0.92), lookup_hit 128 (0.95), overwrite 128 (0.92); strategy 3 lookup_hit 65 (0.95). At or below 0.90 but with overlapping spreads: strategy 1 lookup_hit 65 (0.88), insert_nth 256 and 16384 (0.80); strategy 2 insert_nth 128, 256, 1024 (0.71-0.89), iterate 63 (0.87), clone 64 (0.90); strategy 3 clone 64 (0.90). The insert_nth cells time a single insert, so their round spreads are wide for every strategy.

**bulk_load (insert then `nqp::hashseal`, interpreted for every strategy).** Strategy 1 is slower to 65 (1.40-1.55 at 16-64, 1.00 at 65) and wins from 128 (0.81-0.87). Strategy 2 is slower to 65 (1.15-1.24 at 16-64, 1.03 at 65) and wins from 128 (0.69-0.72, mem 0.35-0.55). Strategy 3 pays for the build and then the seal: 2.78-3.22 at 16-64, 1.83 at 65, 1.43-1.52 from 128 to 16384. That is about 87-98 ns per entry at every ladder size, against strategy 0's 28-68.

**Resize cells (49, 97; reported, never blocked).** At 97 strategy 0 grows past its Small tier inside the timed region and the others do not. Wins at 97: strategy 1 insert 0.58, insert_nth 0.02, bulk_load 0.68, iterate 0.63, overwrite 0.83, clone 0.32, iterate_delete 0.77. Strategy 2 insert 0.62, insert_nth 0.01, bulk_load 0.68, iterate 0.57, clone 0.38. Strategy 3 iterate 0.65, clone 0.37. Behind at 97: strategy 2 delete 1.56; strategy 3 delete 1.45, lookup_miss 1.25, bulk_load 1.48. At 49 the only win is strategy 3 lookup_hit (0.31), and that comes from strategy 0's bimodal warm-up rounds (49 is the first size in its process), not from a layout. Elsewhere at 49 strategies 1 and 2 are behind on insert (1.31-1.36) and bulk_load (1.23-1.25), and strategy 3 is behind on bulk_load (3.15).

### Per strategy, in plain words

**Strategy 1 (Swiss-style groups).** It is ahead on almost everything from 65 entries up. Iterate runs at about 0.68 and clone at 0.58-0.75. Lookup misses, overwrites, delete-while-iterating, insert and bulk load all run 10-20 percent faster from 128, with lookup hits 11-13 percent faster at 128-256. From 128 up it uses 70-86 percent of strategy 0's memory, and level (1.00) at 16384. It is behind below 65. There it pays 1.6-1.8x on insert, 1.4-1.55x on bulk_load, 1.2-1.4x on clone and 1.04-1.15x on lookup hits, with 1.8-3x the memory, because it has no small tier and strategy 0's Small tier is compact. At 16384 lookup_hit and delete are level with strategy 0 (0.98).

**Strategy 2 (array-ordered with a side index).** It is the fastest builder and the smallest table. From 128 up, insert runs at 0.60-0.66 and bulk_load at 0.69-0.72 on 35-55 percent of strategy 0's memory. Iterate runs at 0.62-0.70 and clone at 0.33-0.53 from 65. It is behind on delete at every size: 1.38-1.95 up to 128, then 1.76 at 256, 2.04 at 1024 and 2.19 at 16384. Lookups fall behind as the table grows: lookup_hit 1.08 at 1024 and 1.27 at 16384, lookup_miss 1.13-1.45 from 256. Delete-while-iterating is 1.08-1.34 except at 65-128 (level). Below 65, insert costs 1.2-1.36 and bulk_load 1.15-1.24, on the same memory as strategy 0 or more.

**Strategy 3 (fixed keys, sealed; Robin Hood staging until the seal).** Once sealed it iterates at 0.66-0.68 and clones at 0.52-0.69 from 65 up. Overwrite at 65 is a lone win, and from 128 up overwrite (1.00-1.03, then 1.16 at 16384) and delete-while-iterating (1.01-1.02) are about level with strategy 0; below 65 delete-while-iterating costs 1.27-1.68. It is behind on every lookup at every size except 65: lookup_hit 1.17-1.49, lookup_miss 1.15-1.54. It is behind on delete at 1.26-1.94. Building it (bulk_load, insert plus seal) costs 1.4-3.2x. From 128 up it takes 1.1-1.65x strategy 0's memory.

## Incremental resize

(appended by Task 10)

## Acceptance

(appended by Task 11)
