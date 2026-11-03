# Zig hash engine, campaign 3: internal tables on their own strategies

Date: 2026-11-03. Status: shape approved in conversation, document awaiting
the user's approval; builder check done, its
eight questions folded in (decisions 6 and 7, sections 4.1, 4.2, 5.2, 5.3,
6.2, 7 and 8), each marked "(my call)" where the author settled it.
Follows: the hash layout bake-off (`2026-11-03-zig-hash-layout-bakeoff-design.md`,
merged on `zig-hash-engine` at 1478311f6 with the LOOKUP and APPEND strategies).
Precedes: Rakudo syntax for user hashes (campaign 4).

## 1. Intent

MoarVM keeps 26 internal hash tables of five kinds (str, uni, fixkey, index,
ptr; `traces/llm/bench/bakeoff-census.md`), and every one of them runs on the
same layout: Small-then-Robin-Hood for str, a bare Robin Hood rung for the
other four. The bake-off showed that layout is beaten by a Swiss-style table
on nearly every lookup, insert and iterate cell from 65 entries up, and by an
array-ordered table on insert, iterate and clone. Those layouts exist only for
the str kind, and nothing in the VM uses them yet.

The user's goal, in their words: the internal tables should be *optimized for
their specific use cases*. This campaign measures what each table actually
does in a running Rakudo, then puts each table whose numbers justify it on the
layout its use favours, porting a layout to a new key kind where the table's
kind lacks it.

Success, as the user set it: the spectest must not run slower, each table that
gets switched must win on a benchmark built to stress that table, and a 3
percent faster spectest is the target the campaign reports against. The user
chose this reading explicitly over "stop if the hash share of the spectest is
below 3 percent": the assignment proceeds whatever the share turns out to be,
and the 3 percent is a target, not a gate.

## 2. Decisions

1. **Two halves, survey then assignment.** The survey instruments the engine
   and measures the 26 sites over real workloads; it changes no production
   code path. The assignment switches sites and ports tiers, driven only by
   the survey's numbers. The plan has a stop between them where the user sees
   the survey and rules on the assignment list (as the bake-off stopped at
   Task 9 for naming).
2. **All five kinds are in scope, porting included** (the user's ruling on the
   census's E3). A site gets the layout its numbers favour even where that
   means instantiating the Swiss or array tier for a new `Spec` (key type).
   The tiers are already generic over `Spec` (section 3), so a "port" is a
   new tier set in the kind's file plus whatever the kind's hash and key
   conventions need.
3. **The sealed fixed-key layout stays deleted.** It was deleted by the user
   in the bake-off; Swiss beat it on every lookup cell with less memory. The
   load-once-read-forever sites (u1-u4, i2, i3, f7, f8, s2, s6's load phase)
   are LOOKUP material, and nothing in this campaign revisits a seal.
4. **Internal assignments are compile-time, in the source.** A site's
   strategy is a property of the VM code, so it is written at the C creation
   site or in the kind's Zig tier-set table. No runtime op, no environment
   override, nothing serialized. The `MVM_HASH_STRATEGY` override keeps its
   present meaning (MVMHash and HashAttrStore only) and never reaches an
   internal table.
5. **The C engine is untouched and keeps working.** A C-engine build
   (`-Dzig-impl=false`, or the Perl build without `--zig`) must compile and
   pass the same tests after the campaign. So an internal site never hands
   the C engine a non-default strategy: the per-site choice is behind a
   macro or a Zig-side table that resolves to the default in C-engine
   builds (section 5.2).
6. **Only hot sites are switched.** A site is *hot* when the survey shows it
   taking at least 5 percent of all hash-engine cycles in any one of the
   three workloads (section 4.3), or when it is the dominant table of a
   dedicated benchmark the user asked for (the unicode tables). Cold sites
   (the startup registries f1-f8, the debug locals s2, the callback caches
   s7/s8, the REPR table i1, the heap-snapshot set p2) are recorded and left
   on the default; a layout change nobody can measure is a risk without a
   return. The 5 percent is my call; the user may move it at the stop. The
   share is per workload, unweighted: a site hot in startup alone is hot,
   even though W3 runs a thousand times longer (my call; weighting by
   duration would hide everything but the spectest's own tables).
7. **Every switch is proven by a benchmark that stresses that site**, at the
   nqp level (what the user feels) and the C API level (attribution), on the
   bake-off's rule: at least 10 percent better, with disjoint spreads, on the
   cells that match the site's surveyed size range and operation mix. A
   switch that fails its benchmark is reverted and recorded, as the bake-off
   recorded its losers. When the two levels disagree, **the nqp-level cell
   decides** and the C-API cell explains (my call, from the user's words: the
   benchmark they asked for is the one they would run). A table that wins at
   the C API but not in the nqp cell is reverted, and the record says where
   the win was lost (encoding, fallback parsing, call overhead), because
   that is a lead for a later campaign, not a reason to ship a layout nobody
   can feel.
8. **Whole-system gates as before**, interleaved and recorded: spectest zero
   new failures, wall not slower than base (within the run spread), peak RSS
   not worse, with the ratio reported against the 3 percent target. The
   default user-hash ladder (`tools/bench/hash-bench.nqp`) must be unchanged
   within spread, because the instrumentation hooks live in the shared
   policy layer and must compile to nothing when off.
9. **No new hash functions** (the bake-off's decision 8 stands). Where a
   kind's cached code is narrower than the Swiss tier needs (uni's 32-bit
   `hash_val`, section 3), the kind's `Spec.hash` *widens* the cached code
   to 64 bits with a fixed mixing step; it does not rehash the key.

## 3. Verified facts (checked 2026-11-03 on `zig-hash-engine` 1478311f6)

The engine (`src/zig/core/hash/`):

- `tier.zig`: every table's control block starts with
  `Header { tier: u8, set: u8, entry_size: u8, stale: u8, cur_items: u32 }`
  (8 bytes). `set` indexes the kind's comptime `Spec.sets`; a set is a ladder
  of `TierEntry { tier, from }`. There is **no spare byte** in the header for
  a site id.
- `tier.zig` also carries a **reserved log hook**: `log_hook_enabled = false`,
  `logHookEnabled(set)` and `logHook(set, rung, op, entry)`, a comptime no-op
  "in this campaign" (the engine spec's decision 5, double-write). The policy
  layer already skips, at comptime, any work done only for the hook. It is
  the natural seam for the survey's instrumentation, but it fires on insert
  and delete only; the survey needs fetch, iterate and build/demolish too.
- Tiers are generic: `small.zig`, `robinhood.zig`, `swiss.zig`, `ordered.zig`
  each export `Tier(...)` instantiated with a `Spec` (`Key`, `Ctx`,
  `entry_size` or `runtime_entry_size`, `hash(ctx, key) u64`, `eql`,
  `allocator`, `publish`, `sets`).
- `str.zig`: `sets = { standard, large_only, swiss_only, ordered_only }`,
  `standard_set = 0`, `lookup_set = 2`, `append_set = 3`;
  `strategy_sets = { standard_set, lookup_set, append_set }`;
  `MVM_str_hash_build_strategy` picks the set. Dispatch on set 0 is the inline
  switch, other sets `never_inline` (bake-off 0113fddae).
- `uni.zig`: `Table(UniSpec)` over `MVMUniHashEntry { const char *key; u32
  hash_val; i32 value }`; `Key` is the first two fields; `hash` returns the
  cached **32-bit** `hash_val` (FNV-1a times the 32-bit Fibonacci constant,
  `hashCode`); `eql` is `hash_val` equality then `strcmp`. One rung, Robin
  Hood without salt, `publish = .plain`, `Ctx = void`.
- `index.zig`: keys are `u32` meaning `1 + index` into a caller-supplied
  `MVMString **list` carried in `Ctx`; `hash` is `MVM_string_hash_code` of the
  string (64-bit); one rung, Robin Hood without salt. Entries are 8 bytes.
- `fixkey.zig`: `Key` is `MVMString **` (the indirection pointer); `hash` is
  the string's 64-bit code; `Ctx` is the `tc`; its own `Control` holds the
  caller's u16 entry size. One rung.
- `ptr.zig`: `Key` is `const void *`; `hash` is the pointer times the 64-bit
  Fibonacci constant; one rung; unbuilt is NULL.
- `swiss.zig`: tag is `salted >> 57` (the top 7 bits of `hash ^ salt`), home
  group is the low bits of `hash ^ salt`. **With uni's 32-bit code the top 32
  bits of every hash are zero, so every key would carry the salt's tag and
  the group scan would match every slot.** Decision 9 follows from this.
  Iteration is descending; a delete of the current entry leaves the held
  next position valid.
- `ordered.zig`: dense entry array plus side index; iterates descending (E1).
- `bench.zig` + `bench_shim.c`: the C-API microbenchmark of the **str** kind
  only (`zig build hash-bench`), through one out-of-line C wrapper per
  function so both engines pay the same call. TSV
  `engine size op ns_per_op alloc_bytes ns_min ns_max`.
- `build.zig`: options include `zig-impl`, `lto`, `cpu`/`--march`,
  `nqp-prefix`, `nqp-stage0`; steps `test`, `unit-test`, `strategy-test`,
  `hash-bench`, `thirdparty`, `config-h`. There is no instrumentation option.
- `HASH_DEBUG_ITER` (C engine only; `str_hash_table.h:485` errors under
  `MVM_ZIG_IMPL`) is the only existing hash diagnostic. There are no hash
  statistics in either engine.

The C sites (from the census, re-read where it matters here):

- The unicode tables are reached from nqp by `nqp::getcpbyname` (u3,
  `MVM_unicode_lookup_by_name`, `interp.c:1533`), `nqp::unipropcode` (u1,
  `MVM_unicode_name_to_property_code`, `:1558`), `nqp::unipvalcode` (u4,
  `MVM_unicode_cname_to_property_value_code`) and `nqp::strfromname` (u2 after
  a u3 miss, `MVM_unicode_string_from_name`, `:5049`). All four ops exist in
  the installed nqp; the benchmark needs no new op.
- u3 is the largest internal table (about 65,000 names plus aliases) and its
  miss path is real: a miss falls through to `CJK UNIFIED IDEOGRAPH-` and
  Hangul-syllable prefix parsing. u4 is 115 small tables (5,164 values in
  total, many tables holding only the 16 yes/no names).
- The lexical-name tables (i2) are built presized in `bytecode.c:667-682`
  only for frames with more than 5 lexicals, and looked up by
  `MVM_get_lexical_by_name` (`MVMStaticFrame.c:374`), which `frame.c` calls
  while walking outer frames (`:1318`, `:1370`, `:1674`, `:1689`, `:1735`),
  so a lookup is a run of misses ending in one hit.
- GC-managed owners move: the `MVMHashBody` of an MVMHash or HashAttrStore
  (s3-s6, s9) lives inside a nursery object, so the *handle address* of
  those tables changes across collections. Attribution keyed by handle
  address would break; attribution must live in the table block.
- The spectest protocol of record: `make spectest` in the rakudo checkout,
  TEST_JOBS=24, timed by the `wait4` stand-in for GNU time, three runs per
  side interleaved, the first run discarded if not clean
  (`traces/llm/bench/bakeoff-final-spectest.txt`). Current medians (Zig,
  LTO default): wall about 296-301 s, peak RSS about 704-710 MB; Zig is
  0.975 of the C wall.
- Machine: `perf` 7.2.9 is installed, `perf_event_paranoid` is 2 (user-space
  sampling of own processes works without root).

## 4. The survey

### 4.1 What is measured

Per table kind and per creation site, over each workload of 4.3:

- **Operation counts**: build (explicit or implicit first insert), insert of
  a new key, lvalue-fetch that found the key (overwrite path), fetch hit,
  fetch miss, delete (including fetch-and-delete and delete-at-iterator),
  iteration (count of `first`/`foreach` starts and of entries visited),
  shallow copy, grow (rung migration or in-place resize), demolish.
- **Cycles** per operation class, from the TSC (`rdtsc`), accumulated per
  site; and the process's total cycles from instance start to teardown, so
  each site's share of process time and of hash time can be reported. A
  "hash-engine cycle" is one spent between the exported function's entry
  and its return (my call): that includes `Spec.hash` and `Spec.eql`
  callbacks (for index and fixkey the string code is cached on the string,
  so this is cheap; for str the code is cached too), the allocator and the
  rehash in grow and migration, and the Small rung's linear scan. It
  excludes work the C caller does before calling, such as computing uni's
  `hash_val` or encoding a string, which the C-API companion benchmarks
  measure separately where it matters.
- **Probe lengths** for fetch hit and miss, as a sum and a max per site (so
  the report can say how far the Robin Hood walks today).
- **Size history**: entries at demolish (or at teardown for tables that
  live to the end), the maximum `cur_items` reached, and the rung/set the
  table ended on. Reported as histograms over the bake-off's ladder
  boundaries (4, 16, 32, 64, 65, 128, 256, 1024, 16384, more).
- **Lifetime class**, derived: built-and-never-deleted, churning, grew past
  the Small rung, never looked up.

### 4.2 How (the instrumentation build)

- A build option `-Dhash-stats` (default false) that sets a comptime bool the
  engine reads. With it false the hooks compile to nothing: the default
  ladder before and after the campaign must agree within spread (decision 8).
  The option is zig-build only; `Configure.pl` does not learn it, because it
  is a diagnostic and the survey runs from a zig-built prefix.
- The hooks live in the policy layer (`table.zig`), one per operation class,
  so every kind and every tier is covered without per-tier code. The
  reserved `logHook` in `tier.zig` is either generalised to carry these
  events or left alone with the new hooks beside it; the builder decides,
  keeping the comptime no-op property either way.
- **Site attribution** lives in the table block, not in a side map keyed by
  handle (section 3, moving owners). Under `-Dhash-stats` the control block
  carries a site id (the builder chooses where: a stats-only extension of
  `Header`, or a stats-only word every tier reserves after its control; the
  C never reads engine-side control fields under `MVM_ZIG_IMPL`, so the
  layout is the engine's to change in a stats build). The id is assigned at
  build time from the **caller's return address** (`@returnAddress()` in the
  exported build or first-insert function), interned into a global site
  table that records the address; a post-run script resolves addresses to
  `file:line` with `addr2line` against the same `libmoar.so`, and the
  report names sites by the census's labels (s1..s9, u1..u4, f1..f8, i1..i3,
  p1..p2). Implicit builds (zero-filled tables whose first lvalue-fetch
  allocates: u3, u4, p1, p2, s5, s7) attribute to that first caller, which
  is still the owning site's code. Shallow copies (s9, i3) inherit the
  source's site id and are counted as copies. Two facts settle where the id
  may live: the *handle* (the owner's field) moves with a nursery owner,
  but the *block* (the engine's allocation the handle points at) is stable
  from build or grow until the next grow or demolish; so a side map keyed
  by block address and re-keyed on grow would also work. The in-block id is
  preferred (my call) because it costs one word and no lookup. The stats
  build's control block is therefore larger than the default build's, which
  can shift cache-line alignment and so probe-length and cycle figures a
  little; the survey accepts that, because the hot list rests on *shares*
  and *counts*, not absolute cycle figures, and memory is measured on the
  default build (sections 6.3 and 7), never on the stats build.
- Counters are **per thread** where the kind can be touched from several
  threads (str tables of MVMHash, the SC weak hash under its mutex, the
  callback cache per tc) and merged at teardown, so the stats build adds no
  contention and no atomics to the hot path.
- **Output**: at instance teardown (`MVM_vm_destroy_instance`, also reached
  by `exit`), when `MVM_HASH_STATS` names a *directory*, the process writes
  one TSV file of its own there, named by program name and process id, one
  record per (site, op class) (my call: one shared file would need atomic
  appends of records longer than `PIPE_BUF` across 24 concurrent writers).
  A spectest run of 1,365 files leaves 1,365-plus files, which a tool
  (`tools/bench/hash-stats.pl` or `.raku`, the builder's choice, tested
  like the existing `hash-compare.pl`) aggregates into the report of 4.4.
  A process killed before teardown (a spectest timeout) leaves no file;
  the report counts the files against the processes the workload ran and
  states the loss. The instrumentation never writes when the variable is
  unset.

### 4.3 Workloads

Each run on the stats build of the Zig engine, LTO default, installed into
the survey prefix (nqp and rakudo built against it as the bake-off did):

- **W1 startup**: `raku -e ''` 50 times; also `nqp -e ''` 50 times.
- **W2 the core setting compile**: rakudo's `make` from clean, the CORE.c
  setting compile being the dominant process; recorded as one workload with
  its processes distinguished by program name.
- **W3 the spectest**: `make spectest` as in the protocol of record, once,
  stats on. Its wall time is *not* a measurement (the stats build is slower);
  only its counters are.

A fourth, **W4 the unicode benchmark of section 6** on the stats build,
checks that the benchmark actually drives u1-u4 (and only them) before it is
used to judge anything.

### 4.4 Output

`traces/llm/bench/internals-survey.md`: one section per site in census
order, each with the counts, cycles, share of hash cycles and of process
cycles per workload, the probe-length figures, the size histogram and the
lifetime class; then a **hot list** (decision 6) with, for each hot site,
the layout the bake-off's scoreboard suggests for its size range and op mix
and the benchmark that will judge it; then the **hash share** of each
workload's cycles, with the instrumentation's own overhead estimated (the
counted cycles include the counting; the report says so and bounds it by
timing the hooks on the C-API ladder). Raw TSVs beside it as
`internals-survey-<workload>.tsv`.

The survey also answers the census's open questions: whether the
lexical-name tables are mostly below 65 (where nothing beat the default) or
not; how often MVMHash tables grow past Small; whether the SC weak hash's
per-GC iteration is visible at all.

### 4.5 The stop

The plan stops after the survey report. The user sees the hot list and the
proposed assignment per hot site, may add or strike sites (the cold threshold
of decision 6 is theirs to move), and rules on any site where two layouts are
plausible. Nothing in section 5 starts before that ruling.

## 5. The assignment

### 5.1 Ports

A layout is ported to a kind by adding a tier set to that kind's `Spec.sets`
(`uni.zig`, `index.zig`, `fixkey.zig`, `ptr.zig`) and selecting it at build.
Expected from the census, confirmed or struck by the survey:

- **Swiss for uni** (u1-u4): `UniSpec.hash` widens `hash_val` to 64 bits
  (decision 9; a multiply by an odd 64-bit constant and a fold, so both the
  tag bits and the group bits vary; a unit test checks tag distribution
  over the real property-name set). Entries stay `MVMUniHashEntry`; the C
  API is unchanged; `publish = .plain` stays, since the C frees with
  `MVM_free`. The 115 property-value tables (u4) are mostly tiny, where
  Swiss did not win; the survey decides whether u4 is on the hot list at
  all, and if it is, whether a two-rung set (Small then Swiss) is measured
  for it, since uni tables are never deleted from and the composed set's
  bake-off losses were on delete and overwrite.
- **Swiss for index** (i2, i3) if the survey shows enough lexical-name
  tables above the Small rung's reach and enough misses; the index kind
  has no Small rung today (bare Robin Hood from the first entry), so the
  comparison is Swiss vs Robin Hood at the surveyed sizes, likely 6-64,
  which the bake-off did not cover for Swiss (it measured Swiss from 4 and
  found no win below 65 against Small, not against Robin Hood). The
  benchmark of 6.2 answers it.
- **Swiss for ptr** (p1) if the object-id table is hot; the census expects
  it is not except under heap profiling.
- **str sites** use what exists: `MVM_str_hash_build_strategy` with a
  compile-time strategy (5.2). Candidates from the census: s1 (SC weak hash,
  churns, iterated every GC), s6 (deserialized MVMHash, bulk-loaded then
  looked up; LOOKUP material if hot), s3/s4 (HashAttrStore). The general
  MVMHash (s5) is a user hash by another name; the campaign may switch its
  default only if the survey makes the case and the spectest gates agree,
  and the spec expects it to stay on the default ladder.
- **fixkey** (f1-f8): expected cold; no port unless the survey says
  otherwise.

A port is one commit per kind with unit tests in `hash_test.zig` via
`test_spec.zig` (the existing per-kind spec tests run on every set), plus
the kind's fsck over the new tier.

### 5.2 Selecting at compile time

- For str sites: a header `src/core/hash_internal_strategies.h` (name the
  builder's) defines one macro per site, e.g.
  `MVM_HASH_STRATEGY_SC_WEAKHASH`, as the chosen `MVMHashStrategy` under
  `MVM_ZIG_IMPL` and `MVM_HASH_STRATEGY_DEFAULT` otherwise; the site calls
  `MVM_str_hash_build_strategy(tc, ht, entry_size, entries, MACRO)`. With
  the C engine the macro is 0 and the call is `MVM_str_hash_build`'s
  behaviour, so decision 5 holds without a second code path.
- For the other kinds: the kind's default set in its Zig file changes
  (`uni.zig`'s `sets[0]` becomes the Swiss set, say), which changes every
  site of that kind at once. Where the survey splits a kind (the obvious
  case: u3's 65,000 names against u4's 115 tiny tables), the kind gains a
  `*_build_set`-style entry point taking the set, used by those sites under
  the same macro convention. The builder may add it as soon as the survey
  shows the split, without waiting for the stop (my call): it is internal C
  API, the stop rules on *which* layout each site gets, not on whether the
  kind can carry two.
- The assignment table (site, layout, reason, benchmark that proved it) is
  written into `docs/hash-strategies.md`, which today says the other four
  kinds "always use their own layout"; that sentence changes.

### 5.3 Order

Ports and switches proceed from the hottest site down, one site (or one
kind) per task: benchmark before, switch, benchmark after, decision kept or
reverted recorded in the plan. The spectest gates run once, at the end, on
the final assignment, plus once mid-way if a switch touches the general
MVMHash path (s5/s6) or the lexical-name tables, since those reach every
program. A mid-way gate that fails reverts *that switch* and the campaign
continues with the next site; it is not a stop for the campaign (my call).

## 6. Benchmarks

### 6.1 The unicode benchmark (the user's)

`tools/bench/uni-bench.nqp`, run as the ladder is (`moar --libpath=...
nqp.moarvm tools/bench/uni-bench.nqp`, `--engine/--runs/--ops`), on the
installed nqp with the shipped tables, since the uni tables have fixed
content and the ladder's size axis does not apply. Cells are operation and
key-set mix, each reported as ns per lookup, median of at least 5 runs with
the spread:

- `cpbyname_hit`: `nqp::getcpbyname` over a sample of several thousand
  real names drawn from the full name list (so every probe is a hit), in a
  shuffled order fixed by seed.
- `cpbyname_miss_prefix`: names that miss the table and fall through to
  prefix parsing (`CJK UNIFIED IDEOGRAPH-4E00`, Hangul syllables), so the
  cell measures the miss plus the fallback the VM pays today.
- `cpbyname_miss`: names that miss outright (the hit sample with a suffix),
  so the cell is the table's miss alone.
- `propcode_hit`, `propcode_alias`, `propcode_miss`: `nqp::unipropcode` over
  canonical names, aliases, and misses (u1).
- `pvalcode_hit`, `pvalcode_miss`: `nqp::unipvalcode` over real
  (property, value) pairs and misses (u4), sampled across many properties
  so the small tables are exercised, not one big one.
- `strfromname_seq`: `nqp::strfromname` over named sequences (u2 after a u3
  miss).

A C-API companion, `zig build uni-bench` (a `bench.zig` sibling over the
real uni tables of a bare instance after `MVM_unicode_init`, through a shim
as `bench_shim.c` does), measures `MVM_uni_hash_fetch` hit and miss per
table for attribution: the nqp cells include string encoding and the
fallback parsing, and the C-API cells say what part the table is.

### 6.2 Other site benchmarks

Written only for sites on the hot list, as the smallest nqp program that
drives the site's dominant operation at its surveyed size range, with a
C-API companion where the ladder's `bench.zig` does not already cover the
op. The census suggests, if hot: a lexical-by-name lookup benchmark for i2
(nested frames of 6-64 lexicals, `nqp::getlexdyn`-style lookups from the
innermost, misses dominating); an SC-handle benchmark for s1 is unlikely to
be needed (its lookups are per module load). The plan names them after the
survey. A C-API companion for a kind other than str is required only when
that kind has a hot site; whether it is written by generalising `bench.zig`
over `Spec` or as a one-off per kind is the builder's choice, budgeted as
one task per hot kind (my call).

### 6.3 Ladder guard

`tools/bench/hash-bench.nqp` and `zig build hash-bench` on the default
strategy, before and after the campaign, must agree within spread: the
instrumentation hooks and any policy-layer change cost nothing when off.

## 7. Measurement protocol

The tuning campaign's protocol (its spec section 7) and the bake-off's
additions (its section 6) apply: medians of at least 5 runs with min and max
beside them, interleaved A/B for every comparison, machine conditions
recorded once, every decision with its before/after row in the plan. In
addition:

- A win on a per-site benchmark means at least 10 percent better with
  disjoint spreads on the cells that correspond to the site's surveyed op
  mix; cells outside the site's real mix are reported but do not count.
- The spectest comparison is base (`zig-hash-engine` at the branch point,
  default build) against HEAD (the final assignment, default build), three
  runs each interleaved, stats off, as in `bakeoff-final-spectest.txt`;
  the report gives wall and peak RSS ratios and states whether the 3
  percent target was met.
- The survey's share figures are *stats-build* numbers and say so; the
  instrumentation's overhead is bounded by timing the hooks on the C-API
  ladder (stats build vs default build, same ops), and the report scales
  the share by that bound.

## 8. Correctness gates

1. `zig build unit-test` green: the existing per-kind spec tests run over
   every new set; new tests for the uni hash widening (tag distribution),
   for descending iteration with delete on each new (kind, tier) pair that
   is ever iterated, and for fsck on each.
2. `zig build test` on both engines (`-Dzig-impl=true` and `false`), stats
   on and off, so decision 5 is checked by the build and not by reading.
3. The spectest with the final assignment: zero new failures against the
   bake-off's final record (Files=1365, Tests=138715 at roast fb1d87214).
   The roast checkout stays pinned at that commit for the whole campaign
   (my call); a failure is "new" only if it appears on HEAD and not in the
   interleaved base run, so a test flaky on both sides is not new, and the
   known environmental failure (stale `.precomp`) is handled as the
   bake-off record describes.
4. The spectest once on the stats build (W3) must pass too: the counters
   must not change behaviour.
5. The instrumentation's zero-cost-when-off property: 6.3.
6. `tools/bench/t/*.t` pass; `strategy.nqp` passes (the user-hash API is
   unchanged).

## 9. What does not change

- The C engine and the inline C headers (decision 5).
- The default str ladder (set 0), its tiers, migration and dispatch; the
  LOOKUP and APPEND strategies and their numbers; the `hashstrategy` op and
  the `MVM_HASH_STRATEGY` override and what they apply to.
- Hash functions (decision 9: widening a cached code is not a new hash).
- Serialization: nothing about a strategy is serialized.
- The nqp checkout: no new ops are expected. If a site benchmark needs an
  op that does not exist, that is a plan amendment for the user's ruling,
  committed on the existing `zig-hash-strategies` nqp branch.
- Rakudo: no changes under `rakudo/` beyond rebuilding against the prefix.

## 10. Out of scope

Rakudo syntax for user hashes (campaign 4); a seal or fixed-key layout;
per-site strategies that change during a table's life; a heuristic that
picks a user hash's strategy from its runtime behaviour (the survey data
may inform one later); the ladder's open leads from the bake-off
(`overwrite` 1.15-1.20 and `clone` 1.13-1.21 vs C, the non-set-0 dispatch
cost at 16-64, insert_nth 128/256); the spesh timing race in the Raku-level
bench; the REPR campaigns.

## 11. Acceptance criteria

1. `-Dhash-stats` exists, is off by default, and the ladder guard (6.3)
   passes.
2. `traces/llm/bench/internals-survey.md` and its TSVs cover all 26 sites
   over W1-W3, with the hot list, the per-workload hash share and the
   overhead bound; W4 confirms the unicode benchmark drives u1-u4.
3. The user's ruling at the stop is recorded in the plan.
4. `tools/bench/uni-bench.nqp` and `zig build uni-bench` exist with the
   cells of 6.1, a TAP test beside the existing ones, and a recorded C vs
   Zig-default vs Zig-assigned comparison.
5. Every hot site has a kept-or-reverted decision with its before/after
   rows; every kept switch cleared decision 7's rule.
6. The ports have unit tests and fsck coverage (section 8, item 1); both
   engines pass `zig build test` (item 2).
7. The final spectest: zero new failures, wall not slower, RSS not worse,
   ratio reported against the 3 percent target (decision 8).
8. `docs/hash-strategies.md` carries the assignment table and the corrected
   sentence about the other kinds; `docs/zig-build.md` documents
   `-Dhash-stats` and `MVM_HASH_STATS`.
9. All of it on MoarVM branch `zig-hash-internals` (from `zig-hash-engine`
   1478311f6), the records in `traces/llm/bench/`, the spec and plan in
   `traces/llm/`, merged fast-forward into `zig-hash-engine` when the user
   says so.

## 12. Left to the builder

Where the stats-only site id lives in the control block; whether to
generalise `logHook` or add hooks beside it; the TSV columns and the
aggregation tool's language; the exact widening constant for uni (and
whether index or ptr need one: they do not, their codes are 64-bit); the
group size and tag width if 16 and 7 bits misbehave on a new kind; whether
u4 gets a two-rung set; the sampling of names in the unicode benchmark and
its seed; the shape of any 6.2 benchmark; file and function names not fixed
above; and the task order inside each half, subject to 5.3.

## Process

Subagent-driven, as the bake-off: plan at
`traces/llm/plans/2026-11-03-zig-hash-internal-tables.md`, ledger under
`.superpowers/sdd/`, implementers and reviewers on `sonnet` (the user's
standing instruction since bake-off Task 10; fix-loop escalation one tier
up), work on the MoarVM worktree branch `zig-hash-internals`, traces commits
in the submodule with the pointer bumped in MoarVM.
