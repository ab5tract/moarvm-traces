# Hash layout bake-off: candidate layouts on the ladder, strategies named from the wins

Date: 2026-11-03. Status: approved in conversation; builder check done, its
findings folded in (sections 3, 4.3, 5.3, 6, 8 and decision 4).
Precedes: the internal-table survey (campaign 3), Rakudo syntax (campaign 4).
Follows: the hash engine campaign (`2026-11-02-zig-hash-engine-design.md`) and the
tuning campaign (`2026-11-02-zig-hash-tuning-design.md`), both merged on `zig-hash-engine`.

## 1. Intent

The Zig string hash engine runs every MoarVM string-keyed table through one
ladder, Small (linear scan, up to 64) then Robin Hood, and that ladder is at
parity with the C engine. Hash table layouts have documented sweet spots in
size and operation mix: some are built for lookups, some for insertion, some
for iteration, some for a key set that never changes. The campaign finds out
which of those layouts beat our ladder, on which cells of the benchmark
ladder, and by how much, and turns each coherent win into a named strategy a
program can choose at creation. The strategies are the output of the
campaign, not its input: nothing is named until the scoreboard says what won.

Why this order: the earlier roadmap named three strategies (LowLatency,
ReadOptimized, ReadOnly) before any layout had been measured. The user chose
to measure first and name after, so a strategy exists only where a layout
earned it.

## 2. Decisions

1. **Bake-off before naming.** Candidate layouts are implemented as tiers,
   measured on the existing nqp ladder against the current ladder as the
   baseline, and strategies are named from the scoreboard at the end. No
   strategy is designed up front.
2. **The win rule.** A candidate wins a cell (one operation at one size) when
   its median is at least 10 percent better than the baseline's and the two
   round spreads do not overlap. A candidate earns a strategy only on a
   contiguous block of cells: one operation over a run of adjacent sizes, or
   several operations over the same run of sizes. Scattered wins earn nothing.
3. **Losers are deleted.** A candidate that earns no strategy is removed from
   the tree at the end of the campaign, with its scoreboard column kept in the
   record. The tree ships only layouts that a strategy uses.
4. **One selector, set at creation.** A strategy is chosen once, when the table
   is built, by a strategy argument on the C build call, and the same argument
   reaches NQP through one new op on an empty hash. C creation sites pass the
   default. The nqp side of the ops (two `add_core_moarop_mapping` lines) is
   committed on an nqp branch beside the MoarVM branch, the user's choice on
   2026-11-03 after the builder check; it is the first commit this project
   makes in the nqp checkout. Finer control (per site, per operation, mid-life changes) waits
   until the survey campaign shows a need.
5. **The default ladder does not move.** Set 0 of the string table stays the
   Small-then-Robin-Hood ladder with its tuned behaviour; its ladder results
   must stay within noise of the tuning campaign's record. Candidates are
   additional tier sets.
6. **Every candidate must be correct under the whole system**, not just the
   ladder: a process-wide environment override makes a candidate the default
   for every MVMHash, and the spectest must pass with it, before its
   scoreboard column counts.
7. **A one-day static census of the five internal table kinds** opens the
   campaign, so the candidates are not blind to what the internals need. The
   dynamic survey and the assignment of internal tables to strategies is the
   next campaign, not this one.
8. **No new hash functions.** MoarVM hashes a string once with rapidhash under
   a per-process seed and caches the code; every candidate consumes the cached
   64-bit code. Zig's standard library offers about ten hash functions, and
   their tradeoffs do not reach a table that reads a cached code.

## 3. Verified facts (checked 2026-11-03 on the installed tree)

- `src/zig/core/hash/tier.zig`: every table's control block starts with
  `Header { tier: u8, set: u8, entry_size: u8, stale: u8, cur_items: u32 }`.
  `set` indexes a comptime list of tier sets (`Spec.sets`, at most 256); a
  tier set is a ladder of rungs `TierEntry { tier, from }` validated by
  `tier.validate`. The `set` byte is the strategy selector this campaign
  needs; it already exists and costs nothing more to read.
- `src/zig/core/hash/table.zig`: dispatch is specialised for set 0 and goes
  through `resolve` for any other set. `str.zig` asserts the string table's
  `standard` set is index 0 and builds every C-API table with it
  (`StrTable.build(tc, handle, entry_size, entries, standard_set)`); a second
  set `large_only` already exists as the shape of an extra set.
- The C build call is `MVM_str_hash_build(tc, hashtable, entry_size, entries)`
  (`src/core/str_hash_table_funcs.h:83`). MVMHash builds lazily on the first
  bind (`src/6model/reprs/MVMHash.c:115`, inside `bind_key`, 0 entries; a
  fresh `nqp::hash()` has no table yet) and at deserialize (`:191`, `elems`
  entries). HashAttrStore builds in `copy_to` (`HashAttrStore.c:33`, presized)
  and lazily in bind (`:96`). MVMHash `copy_to` (`MVMHash.c:40`) uses
  `MVM_str_hash_shallow_copy`, a verbatim block copy, so a cloned MVMHash
  keeps its header and therefore its strategy; a HashAttrStore clone rebuilds
  with the default. Every new tier's block must survive a verbatim copy.
- NQP compiles `nqp::<name>` only through a registered mapper:
  `QASTOperationsMAST.compile_op` (nqp `src/vm/moar/QAST/QASTOperationsMAST.nqp:87-98`)
  looks the name up in `%core_ops` and dies with "No registered operation
  handler" otherwise. A new MoarVM op therefore needs (a) its line in
  `src/core/oplist`, (b) the tables regenerated by `tools/update_ops.raku`
  (which writes `src/core/ops.h`, `ops.c`, `oplabels.h`, `lib/MAST/Ops.nqp`
  and `tools/lib/MAST/Ops.rakumod`, all inside the MoarVM tree), and (c) one
  `add_core_moarop_mapping` line per op in the nqp checkout's
  `QASTOperationsMAST.nqp`, followed by an nqp rebuild. nqp's precompiled
  `stage0` predates the ops and cannot compile code that uses them, so the
  harness and the op tests run on the rebuilt nqp, not on stage0. (The
  builder check corrected the first draft here.)
- The benchmark harness is `tools/bench/hash-bench.nqp` (`--engine --sizes
  --runs --threshold --nth`), driven by `tools/bench/hash-bench.sh`, ladder
  sizes 4, 16, 32, 63, 64, 65, 128, 256, 1024, 16384 plus 49 and 97 for the
  resize cells; ops insert, lookup_hit, lookup_miss, delete, iterate,
  insert_nth; output `engine size op ns rss ns_min ns_max`. Interleaved rounds
  and the aggregation (`median of round medians`, spread = min-max of round
  medians) are the tuning campaign's protocol (its spec section 7).
- Zig 0.16 `std` offers two general hash table structures, `HashMap` (open
  addressing, linear probing, one metadata byte per slot, 80 percent load,
  unordered) and `ArrayHashMap` (entries in an insertion-ordered array, index
  table beside it, fast iteration, O(N) ordered removal), plus
  `StaticStringMap` (comptime, keys bucketed by length). Hash functions:
  Wyhash, XxHash3/64/32, CityHash32/64, Murmur2/3, FNV-1a, SipHash64/128,
  Adler32, CRC32.
- MoarVM randomises hash iteration order on purpose (per-process seed), so
  no program may rely on the default order.
- LTO is on by default (`-Dlto` unless Debug); the ladder record with LTO is
  `traces/llm/bench/tuning-lto-default-nqp.md`, every cell of the Zig/C
  pairing passing. That record is the baseline's reference.

## 4. The candidates

Each candidate is one new tier under `src/zig/core/hash/tiers/`, behind the
existing tier interface, and one new tier set in `str.zig` holding that tier
alone (`from = 0`), so the ladder measures the layout itself at every size,
including 16 to 64 where it competes against Small. Composing a winner with
Small below it is a naming-time choice, made from the scoreboard, not a
candidate.

### 4.1 Swiss-style metadata groups

Open addressing with a separate metadata array of one byte per slot holding
a 7-bit tag of the hash and the empty/deleted states, probed 16 slots at a
time with a vector compare (`@Vector(16, u8)` in Zig; SSE2 on x86_64, the
portable lowering elsewhere). Expected sweet spot: lookup hit and miss at
every size above Small, delete, and insert at high load. Known cost: tombstones
under delete-heavy use, and iteration that walks metadata.

### 4.2 Array-ordered entries with a side index

Entries in a dense array in insertion order; an index table (u8, u16 or u32
slots chosen by capacity, as Zig's `ArrayHashMap` does) maps hash to array
position. Iteration walks the dense array. Delete is swap-remove (the last
entry moves into the hole; order is not preserved after a delete) so that
delete stays O(1); the ordered variant is not a candidate. Expected sweet
spot: iterate at every size, insert, memory per entry. Known cost: one extra
indirection on lookup. Note for naming time: this layout exposes insertion
order until the first delete. That is a feature a program opts into through a
strategy, never the default (fact: the default order is randomised on
purpose), and the strategy's documentation must say the order is a property
of the strategy, not of hashes.

### 4.3 Fixed key set, perfect or near-perfect hashing

A layout built in one step from a complete key set: either a two-level
displacement scheme (CHD-style) giving one probe per lookup, or a
hash-ordered dense array with a tiny per-bucket offset table. The builder
picks the scheme; build must be expected linear time and the lookup must do
at most one cache line beyond the entry. Expected sweet spot: lookup hit and
miss on tables that are loaded once, and iterate. It cannot take keys one at
a time, so it needs decision 5.2's seal. Mechanism (my call after the builder
check): before seal, a strategy-3 table is an ordinary Robin Hood table in
its own one-rung staging set; `seal` is a new policy-layer entry point in
`table.zig` that builds the sealed rung from the staging table's entries and
publishes the new block under a second set whose rung 0 is the sealed layout
and rung 1 is Robin Hood. Nothing enters the sealed rung through `from` or
`startingRung`; only `seal` does, and the sealed rung reports itself full on
any insert, so the first insert after seal migrates upward through the
existing migration path, exactly as Small migrates today: correct, not fast.
Delete on a sealed table is in place, by a tombstone flag on the entry (the
lookup structure is not rebuilt; iteration skips tombstones; the count
drops). This adds an entry point beside the migration; it does not change
the migration.

### 4.4 Not candidates

- Incremental (amortised) resize is a wrapper any layout can wear, not a
  layout; the `insert_nth` cells already measure the resize spike. It is
  tried, once, on whichever layout wins the insert block, as the campaign's
  last experiment, and kept only under the same win rule applied to the
  `insert_nth` cells.
- Cuckoo and hopscotch hashing: not in this round. They can be added as
  candidates in a later round by the same recipe if the scoreboard leaves a
  block unclaimed.
- Any change to the Small or Robin Hood tiers.

## 5. The selector

### 5.1 C API

`MVM_str_hash_build` keeps its signature and builds with strategy 0. A new
`MVM_str_hash_build_strategy(tc, hashtable, entry_size, entries, strategy)`
takes the set index; the set index is the strategy number and `MVMHashStrategy`
in `src/core/str_hash_table.h` names them (`MVM_HASH_STRATEGY_DEFAULT = 0`;
during the bake-off the candidates are numbered 1, 2, 3 in the order of
section 4; at naming time the winners get names and the losers' numbers are
removed, so numbers are not stable across the campaign and nothing outside
the tree may store one). An unknown strategy is an `MVM_exception_throw_adhoc`
at build time, never a silent fallback. Under the C engine
(`-Dzig-impl=false`) every strategy other than 0 throws "hash strategies need
the Zig hash engine"; the C engine is not extended.

### 5.2 NQP ops

Two new ops in `src/core/oplist`, both `:pure`-free and non-specialisable:

- `hashstrategy(obj, int64 strategy, int64 size)`: on an MVMHash (or a
  subclass REPR built on it) with zero elements, rebuilds its table with the
  strategy and the size hint; returns the object. On a non-empty hash, or on
  a non-hash, it throws. The size hint is a capacity hint only, as `entries`
  is today, never a bound.
- `hashseal(obj)`: tells the table its key set is complete; returns the
  object. For the fixed-key candidate (4.3) this is where the layout is
  built from the entries inserted so far; for every other strategy and for
  the default it is a no-op. A second seal is a no-op. The op is the
  bulk-load entry point: bulk-load is "insert N, then seal" and the ladder
  measures that total.

My call (the builder may object through the check): seal instead of a
list-taking bulk-load op, because NQP has no cheap way to hand a key list to
a MoarVM op without building a hash first, and because it keeps the fixed-key
candidate inside the one-selector rule.

### 5.3 Process-wide override for the whole-system gate

`MVM_HASH_STRATEGY=<n>` in the environment, read once at instance start the
way `MVM_SPESH_DISABLE` is, makes `n` the strategy for every MVMHash build
that would otherwise use the default (MVMHash initialize and deserialize,
HashAttrStore; not the internal tables). Unknown values throw at the first
build. When the override names a sealable strategy, deserialize seals the
table right after loading it, since the key set is complete there; that is
the only place the override seals, and without it the spectest gate for
strategy 3 would never touch the sealed layout (builder check). The override
exists for decision 6 and for anyone wanting to try a strategy on a whole
program; it is not part of the strategy API and the documentation says so.

## 6. Measurement protocol

The tuning campaign's protocol (its spec section 7) applies unchanged, with
these additions.

- `hash-bench.nqp` gains `--strategy=N` (calls `nqp::hashstrategy` on each
  hash right after creation, with the size as the hint) and `--seal` (calls
  `nqp::hashseal` after the inserts; required for strategy 3, allowed for
  any), and one new op column `bulk_load`: insert N then seal, per entry,
  measured for every strategy including the baseline (where seal is a no-op)
  so the column is comparable.
- Builds: the default build (`zig build install`, LTO on) of one tree; every
  strategy is measured in the same process image, selected by `--strategy`,
  so there is one build per round and no build-to-build noise.
- Rounds: at least 7 interleaved rounds, the strategy order rotated per round,
  each round running every strategy over `--sizes=4,16,32,63,64,65,128,256,1024,16384 --runs=5 --nth=all`
  plus the resize cells `--sizes=49,97`.
- Strategy 3's `--seal` run seals each hash after its fill and before the
  lookup, iterate and delete measurements; its `insert` and `insert_nth`
  cells measure the staging Robin Hood table and are marked not applicable
  on the scoreboard, not compared. Its `bulk_load` cell is the one that
  measures its build cost.
- Memory: the `rss` column is aggregated and shown per cell as a ratio to
  the baseline. It is a column of the scoreboard, not a gate: a candidate's
  block win is recorded with its memory ratio, and the naming step (section
  8) states the cost beside each strategy. My call; the user set the time bar
  and said nothing about memory.
- The scoreboard: one table per operation, rows sizes, columns strategies,
  each cell the ratio to the baseline with the spread verdict (pass means
  "wins": ratio at or below 0.90 and spreads disjoint). Record under
  `traces/llm/bench/bakeoff-*`, summary in the plan.
- The baseline check: the baseline column's absolute numbers are compared
  with `tuning-lto-default-nqp.md`'s zig-lto numbers; every cell within the
  spread or within 5 percent, else the campaign stops to find what moved.

## 7. Correctness gates

- Each new tier gets the same unit tests the existing tiers have in
  `src/zig/core/hash/test/` and `hash_test.zig` (insert, fetch, delete,
  iterate, grow, migrate, stale detection, randomised differential test
  against a reference map), run by `zig build unit-test`.
- `zig build test` and `zig build test_spec` pass.
- Each candidate passes the full rakudo spectest as the process-wide default
  (`MVM_HASH_STRATEGY=<n> make spectest`) with zero new failures against the
  same roast commit run with the default; one run per candidate, not timed.
  The fixed-key candidate under this gate means every hash seals never and
  migrates on growth, which is the correctness path section 4.3 requires to
  work.
- The two ops are tested from this tree, not from nqp's `t/` (we do not
  commit there): nqp scripts under `tools/bench/t/`, run by a new step of
  `zig build test` the way its nqp stage0 smoke test already runs nqp code
  (the nqp checkout's `stage0` is the runner), covering: strategy on empty hash then insert/fetch/delete/
  iterate round trip for every strategy; strategy on a non-empty hash throws;
  unknown strategy throws; seal then fetch; insert after seal migrates and
  stays correct; `MVM_HASH_STRATEGY` override with a valid and an invalid
  value.

## 8. Naming the strategies

At the end of the measurement, from the scoreboard, in a section of the plan:

1. For each candidate, list its winning blocks (operation or operations,
   size run, ratio range, memory ratio range).
2. Each candidate with at least one block becomes a strategy. Its name says
   what the program is promising or wanting, not how the layout works
   (`ReadMostly`, `IterateHeavy`, `FixedKeys`, or whatever the blocks say);
   the user picks the names from the proposed list.
3. The documentation (`docs/zig-build.md` for the build side, a new
   `docs/hash-strategies.md` for the API) carries, per strategy, the blocks it
   won, the memory cost, what it gives up (order exposure, migration on write
   after seal), and the ops to select it.
4. Candidates with no block are deleted: tier file, tier set, enum entry,
   tests, harness mention. Their scoreboard column stays in the record.
5. A strategy ships as a tier set, and the set that ships is the set that
   was measured: if naming composes a winner with Small below it, or with a
   Robin Hood rung above it, that composed set gets its own interleaved
   rounds under the win rule and its own spectest run as the process-wide
   default before it is named. A set nobody measured does not ship.
6. The incremental-resize experiment (4.4) runs after naming, on the insert
   block's winner (or on the baseline if nobody won insert), and is kept only
   if the `insert_nth` cells meet the win rule.

## 9. The census (opening task)

Before any candidate is written, a static read of the five table kinds (str,
uni, fixkey, index, ptr): every creation site, the operations each site
performs (insert, fetch, delete, iterate, grow, seal-able or not), and what
the code says about lifetime and size (fixed at creation, grows with the
program, cleared and refilled). Output: `traces/llm/bench/bakeoff-census.md`,
one row per creation site. The census does not change code. It is a day's
reading and its result may add a candidate or an op column to this spec
through an erratum; the user rules on any such addition.

## 10. What does not change

- The C engine (`-Dzig-impl=false`) and the inline C headers.
- The default ladder: set 0, its rungs, the dispatch for set 0, the Small
  and Robin Hood tiers, the migration, `MVM_str_hash_build`'s behaviour.
- The other four table kinds (uni, fixkey, index, ptr): no strategy on them
  this campaign.
- Serialization: a strategy is not serialized. A deserialized hash is built
  with the default strategy; a program re-selects after load if it wants to.
  (The survey campaign may revisit this for FixedKeys-type tables in
  precompiled modules.)
- Rakudo: no syntax, no changes under `rakudo/`. The nqp checkout changes
  by exactly two `add_core_moarop_mapping` lines (section 3), committed on an
  nqp branch (decision 4), and a rebuild.

## 11. Out of scope

Hash functions; the four non-string tables; Rakudo syntax; the dynamic
survey and assigning internal tables to strategies; cuckoo and hopscotch
layouts; per-site or mid-life strategy changes; serializing a strategy;
concurrent hashes.

## 12. Acceptance criteria

1. Census recorded (section 9).
2. Three candidates implemented as tiers with unit tests, all suites green,
   each passing the spectest as the process-wide default with zero new
   failures.
3. The two ops and the C build-with-strategy entry point work from NQP, with
   the tests of section 7; unknown and misuse cases throw.
4. The scoreboard produced under section 6, at least 7 interleaved rounds,
   with the baseline check passing.
5. Strategies named under section 8 with the user's names, losers deleted,
   documentation written, incremental-resize experiment run and ruled.
6. The default ladder re-measured once against the C engine after everything
   is in (the tuning campaign's Task 8 recipe): every cell still passes.

## 13. Left to the builder

The perfect-hash scheme (4.3); the group size and tag width of the Swiss tier
if 16 and 7 bits prove wrong for 64-bit cached codes; the index-table width
thresholds of the array-ordered tier; the tombstone policy and when the Swiss
tier rehashes in place; how the fixed-key tier stores entries before seal (a
staging Robin Hood rung in the same set is the obvious answer); the names
proposed in section 8; the order the three candidates are built in (the
census may suggest one); and every file and function name not fixed above.
