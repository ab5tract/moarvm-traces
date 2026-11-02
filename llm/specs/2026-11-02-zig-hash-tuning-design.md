# Zig hash engine tuning: the default ladder at parity, the migration tamed, LTO opt-in

**Date:** 2026-11-02
**Status:** approved (builder-checked; the two open questions were settled as decisions 7 and 8)
**Builds on:** the Zig hash engine (`traces/llm/specs/2026-11-02-zig-hash-engine-design.md`, branch `zig-hash-engine`, head `a5ea2a419`), its recorded results (`traces/llm/plans/2026-11-02-zig-hash-engine.md`, "Benchmark results"), the boundary spikes (branch `zig-hash-spike-boundary`, report `/tmp/claude-1000/hash-spike-boundary-report.md`, summarised in §3), and the profile recon (branch `zig-hash-spike-profile`, report `/tmp/claude-1000/hash-profile-report.md`; its attribution is recorded by the plan's first task, §6).
**Campaign:** 1 of 3 (then: strategies in the VM; the Rakudo `Hash[:strategy, :size]` syntax; then REPRs).

## 1. Intent

The hash engine campaign left the Zig engine correct and at whole-system
parity, but slower than the C engine per operation at the table level:
Robin Hood lookup 1.3x, delete 1.3-1.8x and iterate 1.3x; Small-tier lookup
hit 1.4-1.9x and delete about 1.9x; the Small-to-Robin-Hood migration about
80x the C engine's ordinary insert (1.5 µs). The boundary spikes showed that
inlining every export removes only the iterate deficit: the rest is inside
the engine's own code. This campaign finishes the engine: the default ladder
reaches parity with the C engine where the user measures it, the migration
costs no more than the resize it replaces, and link-time optimisation is
available as an opt-in that buys the remaining iterate gap plus a
build-wide gain. Nothing new is added to the API; the C engine stays
selectable; the later strategy campaign builds on a fast default.

## 2. Decisions

Taken in the brainstorm (2026-11-02); the plan does not re-litigate them.

1. **Scope is the default ladder only**: the string table's `[Small(64),
   RobinHood]` set and the shared policy layer. The four single-rung tables
   inherit whatever the shared code gains; nothing is done for them alone.
   No new tiers, no strategies, no C-API or behaviour change (§10).
2. **The scoreboard is the nqp level**: `tools/bench/hash-bench.nqp` (the
   harness written on the spike branch, promoted into the tree by this
   campaign) run on the stage0 nqp against a zig-built `moar`, which goes
   through `MVMHash`'s REPR with less layering above the table than Raku.
   The C-API microbenchmark attributes; the Raku-level benchmark and the
   rakudo spectest are the whole-system check at the end.
3. **Profile first, then one named cause per change.** Every change is tied
   to a cause the profile attributed, is measured on the scoreboard and the
   C-API bench against the C engine, and is kept only if it moves its
   number outside the measured noise. Changes that do not move a number are
   reverted, not kept "because they should help".
4. **The migration is judged against the C engine's own resize.** The C
   table built with `entries = 0` starts at 8 official slots (6 items) and
   `lvalue_fetch` grows when `cur_items >= max_items`, so the inserts that
   resize are the 7th, 13th, 25th, 49th and 97th; the yardstick is the 49th
   and 97th inserts (the 97th is the 128-to-256 resize), measured as the
   N-th insert into a table of N-1, median over at least 5 runs so that
   salt-dependent probe-limit growth averages out. The harnesses learn to
   emit `insert_nth` at any size on the ladder, not only at the threshold.
5. **LTO is opt-in**: `-Dlto` in the zig build and `--zig-lto` in the Perl
   build, the latter only with `--cc=zig` (gcc cannot consume the bitcode
   object; Configure hardfails on the combination). Default builds are
   unchanged. Local binding of the exports comes with it: prefer
   `-Bsymbolic-functions` on libmoar (keeps the symbols exported, so every
   acceptance check and the external benchmark shim keep working); fall
   back to hidden visibility only if symbolic binding does not let LTO
   inline, and then re-link the benchmark and tests against the object.
6. **The finish line** (§8): every operation in both tiers within 5 percent
   of the C engine or better at the nqp level, the Small tier's insert,
   iterate and memory wins kept, the migrating insert no more expensive than
   the C engine's 97th insert, spectest and Raku level at parity.
7. **Iterate is exempt from the 5 percent line in non-LTO builds**: the C
   API's two calls per element are its shape and only LTO removes them, so
   Robin Hood iterate must be at or below 1.10 in a default build and within
   noise of 1.0 under `-Dlto`, judged against the plain C engine.
8. **The campaign is bounded**: the levers the profile supports, plus at
   most two further profile-and-lever rounds. If the finish line is still
   missed, the campaign ends with the shortfall recorded per operation in
   the plan, and campaign 2 (strategies) proceeds regardless.

## 3. Verified facts

From the hash engine campaign and the spikes on this machine (Zig 0.16.0,
x86_64, ReleaseFast; "ratio" is Zig time over C time):

- **C API** (both engines through the same C shim): Small (16-64) insert
  0.29-0.35, lookup hit 1.43-1.94, lookup miss 0.93-1.10, delete 1.7-2.0
  after the single-probe fix, iterate 0.69-0.74, allocation under a third of
  C's. Robin Hood (128 and up) lookup hit 1.27-1.34, miss 1.14-1.33, delete
  1.42-1.79, iterate 1.29-1.33, insert 0.64-1.17, allocation equal. The 65th
  insert: 1516 ns against the C's 19 ns ordinary insert.
- **nqp level** (spike harness, medians of 9, 3-5 percent noise): Small
  lookup hit 0.90-1.14, delete 1.19-1.33, iterate 0.74-0.84; Robin Hood
  lookup hit 1.17-1.21, delete 1.20-1.24, iterate 1.04-1.09; the migrating
  insert about 50x.
- **Raku level**: every ratio within 0.80-1.23 except the 64th insert 0.76,
  insert at 65536 1.61, the 1M-entry iterate 0.66 and the migrating insert
  4.29. Spectest: 0 failures on both engines, wall time and peak RSS within
  1 percent.
- **Boundary spikes**: hidden visibility alone (`@export(..., .visibility =
  .hidden)`, 0 PLT calls) changed nothing measurable. LTO alone (`lto =
  .full` on libmoar and on the `moar_zig` object; 0.16's `Compile.lto:
  ?std.zig.LtoMode`) engaged but did not inline the exports: default
  visibility keeps them preemptible. Both together inlined every hot export
  (`fetch_nocheck`, `fetch`, `delete`, `lvalue_fetch`, `next`,
  `current_nocheck`, `count` have no surviving call sites). Against a C
  build with the same LTO: Robin Hood lookup hit 1.14-1.18, delete
  1.15-1.24, iterate 1.01-1.02; so inlining explains iterate and nothing
  else. LTO on the C side alone makes the zig build 3-8 percent faster
  overall; link time 20 s to 60 s; libmoar 7 percent larger; stage0 and a
  100k-key smoke pass under every variant.
- **Where the per-call cost can be** (named by the reviews, to be
  confirmed or refuted by the profile, §6): the C-shaped wrapper (key
  validation, `handleOf`, the readers' stale check); the policy layer's
  `resolve`/`dispatch` over `Spec.sets` and rungs with runtime set and rung
  bytes, the control-only bit test and the stale check on every call;
  recomputing the entry-area offset from `capacity` on every Small lookup;
  `Spec.eql` reaching `MVM_string_graphs_nocheck` and
  `MVM_string_substrings_equal_nocheck` as calls where the C inlines the
  first; the zero-key check before every comparison; the Small swap-remove
  copying `entry_size` bytes with a runtime length; iteration paying two
  calls per element (`next_nocheck`, `current_nocheck`) that the C inlines.
- **Where the migration cost is** (to be broken down by the profile): the
  next rung sized for `2 * cur_items` becomes 256 official slots (7.6 KB
  allocated, metadata cleared) where 128 would hold the threshold plus one
  with 96 free before the first Robin Hood resize; 64 entries reinserted
  through the full insert path (duplicate check, growth checks, the probe
  loop); an atomic salt draw; a `freeAtSafepoint` list-node allocation;
  the `cur_items * 2` sizing itself.

## 4. The tuning levers

Each lever below is a hypothesis with its test. The plan orders them by the
profile's attribution (largest first) and drops any the profile does not
support. A lever "lands" only if its scoreboard and C-API numbers move
outside the noise band the measurement protocol establishes (§7).

### 4.1 Policy-layer dispatch and checks (`table.zig`)

- Specialise dispatch for the common case: the string table has one set in
  normal use; resolve the set once per call (a comptime-unrolled
  `inline for` is already used; the cost to attack is the runtime
  comparisons and the generic `args` tuple plumbing). Expected shape: a
  direct `switch` on `header.tier` per Table instance with the set fixed at
  comptime where `Spec.sets.len == 1`, and the control-only test folded
  into the same switch (the control-only bit lives in `header.tier`).
- Stale checks: one volatile load per call stays (the C does the same); the
  exit check in mutators is kept; nothing else is added. If the profile
  shows the stale load itself, it is not removed; it is the C's contract.
- Entry-area offset: store the Small tier's entry base (or the offset) in
  its payload at `init`/`grow` instead of recomputing it from `capacity`.
- `logHook`: already comptime-skipped for delete; confirm `lvalueFetch` has
  no residual cost from it.

### 4.2 Small tier (`tiers/small.zig`)

- Keep the vector tag compare; attack what surrounds it: the candidate
  loop's zero-key check (reserve a tag value for "unfilled" so an unfilled
  slot can never be a candidate, which removes the check from the hot
  path), the entry base computation, and the per-candidate `Spec.eql`.
- Delete: the swap copy is `entry_size` bytes at runtime; specialise for the
  16-byte entry (`@sizeOf(MVMHashEntry)`, every string-table caller) with a
  comptime branch, falling back to the generic copy.
- Lookup miss is already at parity; do not regress it.

### 4.3 Robin Hood tier (`tiers/robinhood.zig`)

- The port is faithful; the cost to attack is what the C compiler gets for
  free and the port does not: the C has a fast path for
  `sizeof(MVMHashEntry)` (`str_hash_table.c:419`); the loop state should
  live in registers; the probe loop's zero-key check and the metadata
  byte handling should compile to what the C's does (compare the annotated
  assembly of both; the profile reports the instruction-count ratio).
- Delete: the back-shift copies with runtime lengths; specialise for 16
  bytes as in Small.

### 4.4 The C-shaped wrapper (`str.zig`, `str_exports.zig`)

- Key validation: the C's `MVM_str_hash_key_is_valid` is two inline checks;
  make the Zig version the same two checks with no call (`isConcrete` is a
  shim already; the REPR ID check must not call out).
- `hash`: `MVM_string_hash_code` is translated with its body; confirm the
  cached-hash fast path is a load and a branch, not a call.
- `eql`: pointer equality first (as now), then the grapheme count through
  the translated inline `MVM_string_graphs_nocheck` (a load), then the
  substrings call only on a genuine candidate. If the profile shows the
  substrings call dominating lookup hits, the cause is candidate quality
  (tag or probe), not `eql`.

### 4.5 Iteration

- Two calls per element are inherent to the C API (`next_nocheck` and
  `current_nocheck` are separate functions); nothing in the engine removes
  that. The LTO lever (§4.7) is the only one that reaches parity here, as
  the spike showed (1.01-1.02 with inlining).

### 4.6 The migration

- Size the next rung for the threshold plus one at the load factor (128
  official slots for 65 entries; the C's own table at 65 entries is 128
  official), not `2 * cur_items`.
- A bulk-insert path for migration: the entries are known distinct and the
  target is known to have room, so the reinsert loop skips the duplicate
  check and the growth checks and inserts by bucket directly; the entry
  bytes are copied once.
- Measure the salt draw and the `freeAtSafepoint` node separately; they are
  expected to be small and are not attacked unless the profile says
  otherwise.
- The yardstick (decision 4): the C engine's 49th and 97th inserts, the
  ones that resize.
- Sizing the target at 128 slots changes the bucket order of hashes with
  65 to 96 entries compared with today's Zig engine. That is not an
  observable change in the §10 sense: Robin Hood bucket order is already
  salt-random and unspecified, and the new order is closer to the C
  engine's (which has a 128-slot table at those sizes). Recorded here as
  the ruling.

### 4.7 LTO, opt-in

- Zig build: `-Dlto` (default false) sets `lto = .full` on libmoar and the
  `moar_zig` object and adds `-Bsymbolic-functions` to libmoar's link so the
  exports bind locally; `zig build test`, `unit-test` and `hash-bench` work
  unchanged with it (symbols stay exported).
- Perl build: `--zig-lto` requires `--zig` and `--compiler=zig`
  (`--cc=zig`); adds `-flto` to the C compile and link flags,
  `-Wl,-Bsymbolic-functions` to libmoar's link (the same local binding as
  the zig build, without which LTO buys only the C-side gain) and
  `-Dlto=true` to `ZIG_BUILD_FLAGS` so the object is bitcode; hardfails with
  any other compiler with a message naming the reason. `make clean`
  unchanged. The hidden-visibility fallback, if needed, must work in both
  builds.
- If `-Bsymbolic-functions` does not let LTO inline the exports (the spike
  only tested hidden visibility), the fallback is hidden visibility under
  `-Dlto` only, and the benchmark shim and the libmoar-linked tests link the
  `moar_zig` object directly in that mode; the acceptance `nm -D` checks
  are then run without `-Dlto`.
- Reported separately: the hash gain (iterate to parity, anything else) and
  the C-side gain (3-8 percent on the whole build), so neither is
  overclaimed.
- `docs/zig-build.md` documents both options, the link-time cost and that
  gcc builds cannot use it.

## 5. What does not change

- The C APIs, the `[zig]` mechanism, the header switch, the tier interface
  (any change to it must keep the four single-rung tables working and be
  called out in the plan), the tier sets, `small_threshold`, the migration
  trigger, iteration order (reverse insertion in Small; Robin Hood's bucket
  order), the stale/CAS/free-at-safepoint discipline, the recorded
  observable changes of the engine spec.
- A build without the Zig groups compiles exactly today's C files; a build
  without `-Dlto`/`--zig-lto` links exactly as today.

## 6. The profile is the first task

Before any lever, the plan's first task records, in the plan, the profile
attribution: for lookup hit and delete in each tier, the share of samples
in the wrapper, the policy layer, the hash and bucket computation, the
probe or scan loop, `Spec.eql` and the rest; `perf stat` instruction counts
per operation for both engines; the migration broken into allocation and
clear, reinsert loop, salt draw and safepoint node; and the C engine's 49th
and 97th insert costs. The profile recon on branch `zig-hash-spike-profile`
produces this (`perf` 7.2.9 is available with `perf_event_paranoid = 2`,
which allows sampling one's own processes; the recon builds the engine
unstripped in ReleaseFast so `perf annotate` can attribute lines). If its
report is missing or stale when the plan runs, task 1 performs the same
profiling itself with those tools. The recon's harness changes (per-size
`insert_nth`, an `--ops=` filter, the unstripped-object build setting as an
option) are adopted into the tree by the same task. The levers in §4 are
then ordered by the attribution, and any lever the attribution does not
support is struck from the plan with a note.

## 7. Measurement protocol

- Scoreboard: `tools/bench/hash-bench.nqp` (promoted from the spike branch,
  same ladder and operations as the Raku harness, `--engine/--sizes/--runs`),
  run as `zig-out/bin/moar --libpath=../src/vm/moar/stage0
  ../src/vm/moar/stage0/nqp.moarvm tools/bench/hash-bench.nqp` against the C
  engine (`-Dzig-impl=false`) and the Zig engine, ladder
  `4,16,32,63,64,65,128,256,1024,16384`, medians of at least 5 runs, with
  the spread (min and max of the runs) reported next to each median so the
  noise band is visible. `tools/bench/hash-bench.sh` learns to run the nqp
  harness alongside the others and to render all three.
- Attribution: the C-API microbenchmark at the same sizes.
- Each lever: one commit, one before/after row in the plan's results table
  (nqp-level and C-API ratios for the operations it targets, with the
  spread), and the decision kept/reverted with the reason.
- Whole system at the end: the Raku-level benchmark on two stacks and three
  timed spectest runs per engine, as the engine campaign did (its Task 14
  commands), compared with the engine campaign's recorded numbers.
- Machine conditions are recorded once (CPU model, governor, load) and the
  same for every run of a comparison.

## 8. Acceptance criteria

1. nqp level, medians against the C engine with the spread reported: every
   operation at every ladder size in both tiers at or below 1.05, or the
   difference inside the measured noise band, except Robin Hood iterate in
   a non-LTO build, which must be at or below 1.10 (decision 7); Small-tier
   insert, iterate and allocation remain better than C (insert and iterate
   below 1.0 at 16-64; allocation under a third).
2. The migrating insert at 65 costs no more than the C engine's 97th insert
   (its resize into 256 official slots), at the nqp level and at the C API.
   If the campaign ends short of criterion 1 or 2 (decision 8), the plan
   records the shortfall per operation and size.
3. Raku-level: every ratio within the engine campaign's recorded band or
   better; no new outlier above 1.25 except the already-recorded 65536
   insert, which must not get worse.
4. rakudo spectest: 0 new failures against the C baseline; wall time and
   peak RSS within 2 percent of the C engine (three runs each, medians).
5. `-Dlto` and `--zig-lto` (with `--cc=zig`) build and pass `zig build
   test`, `unit-test` and the Perl stage0 smoke; with `-Dlto` the nqp-level
   iterate ratio is within noise of 1.0 and the C-side build-wide gain is
   reported; without them nothing changes (link flags and symbols as today).
   `--zig-lto` with gcc hardfails.
6. Every existing test passes; `zig fmt --check`, `perl -c Configure.pl`,
   `sh -n` on the touched scripts clean; the C path unchanged.
7. The plan's results table holds one row per lever, kept or reverted, with
   its numbers.

## 9. Out of scope

- New tiers, strategies, the `(strategy, size)` hint, double-write (campaign 2).
- Any Rakudo-side change (campaign 3).
- Tuning the four single-rung tables individually; the C API's shape
  (iteration's two calls per element stay).
- LTO for gcc builds; making LTO the default.
- The call boundary itself in non-LTO builds (the spikes showed it is not
  where the deficit is).

## 10. Observable changes

None intended. If a lever would change an observable behaviour (iteration
order, the salt's effect on order, error texts), it is not taken without a
recorded ruling.

## 11. Left to the builder

- The exact specialisations in §4.1-§4.4 and their fallbacks for entry
  sizes other than 16 and for the four single-rung tables.
- Whether the Small tier's "unfilled" tag value is a reserved byte or a
  separate occupancy word, as long as lookup miss does not regress.
- The bulk-insert path's shape in the Robin Hood tier.
- The order of levers once the profile has ranked the causes, and which
  levers to strike.
- How `hash-bench.sh` renders three harnesses.

## 12. Errata after implementation

- §3, nqp level: the ratios quoted there (Small lookup hit 0.90-1.14, delete
  1.19-1.33, iterate 0.74-0.84; Robin Hood lookup hit 1.17-1.21, delete
  1.20-1.24, iterate 1.04-1.09) came from the spike harness, which timed
  every phase inside one frame; a spesh artefact doubled the C engine's
  delete there, and the sort of the medians was lexical. Task 1 of the plan
  fixed both (each phase is its own sub; numeric sort) and re-took the
  baseline; the plan's "## Profile and baseline" supersedes §3's nqp rows.
- §8 criterion 3: the engine campaign's recorded Raku-level band came from
  one favourable run. Task 9 re-ran the engine campaign's own build in the
  same session and it reads as high or higher on the cells above the band,
  so criterion 3 is recorded as a pass against the re-measured band and a
  shortfall against the literal one (plan, Task 9 acceptance row 3).
- §8 criterion 4: peak spectest RSS measured 3 percent above the C engine
  (Zig runs 686/713/725 MB climbing, C 696/686/692 MB flat); accepted by
  the user on 2026-11-02 with a note to revisit.
