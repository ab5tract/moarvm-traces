# GC call-boundary parity: design

Campaign 7 of the MoarVM C-to-Zig migration. Follows the Zig-native collector (`2026-11-09-zig-native-gc-design.md`, Campaign 6, merged into `zig-hash-engine` 2026-11-11 at 66ff45c8c). Author: the controller session; approved by the user before execution.

## 1. Intent

Campaign 6's after-profile left one collector cost standing: the object allocator, 786 bytes against the C's 384, with a five-register prologue and `num_temproots` kept in memory. The record read that as register pressure and named the allocator's code shape as the next thing to look at. A spike on 2026-11-11 (section 4) found the cause one level up: under LTO the Zig build inlines two slow paths that the C calls out of line, the gen2-root add inside the write barrier and the finalizer-queue add, and each drags mimalloc's realloc fast path into its caller. The same two inlines bloat `allocateStable`, `allocateTypeObject` and `processWorklist`, the collector's hottest loop. Keeping those two calls out of line, as the C's translation-unit boundaries keep them, puts the allocator at 369 bytes with the C's register and frame shape, and the collector's rows at parity with the C's in one sampled profile.

This campaign makes that change properly: with the oracle, the A/B and the profile that turn a spike into evidence, a rule the collector's later ports can apply, and the two deferred C cross-calls replaced while the oracle is being rerun anyway. It ends with the branch included in `zig-hash-engine`.

## 2. Goals, non-goals, anti-goals

Goals
- Every collector function whose C counterpart calls a slow path out of line keeps that call out of line in Zig. The two sites the spike found are the minimum; an audit (section 5) decides whether there are more.
- The two remaining C cross-calls from Zig collector code, `c.MVM_gc_mark_collectable` in roots.zig and `c.MVM_gc_root_gen2_add` in gen2.zig, become Zig imports of the functions they name.
- The collector's decisions stay byte-identical to the C collector's: the Campaign 6 oracle, every cell equal.
- The after-profile shows the allocator row at or below the C's (the gate, section 7). The C-ABI export wrappers (`gen2AddExport`, `addToQueueExport`, `markCollectableExport`) keep calling the Zig definitions; `noinline` on the definition makes the wrapper a tail call and changes no exported symbol, so the `nm -D` set stays at Campaign 6's 2850.

Non-goals
- No statement of the collector changes meaning. This campaign moves no logic, renames nothing and adds no abstraction; it changes where the compiler may inline and which symbol a call binds to.
- No change outside `src/zig/gc`, `src/zig/moar.zig`, the bench tools, the docs and the traces records. C sources untouched.
- No spectest run (the user's ruling, section 13): the change is two keywords and two imports, and the oracle plus the unit tests cover the decisions.

Anti-goals (a failure even if the numbers come out)
- A `noinline` placed where the C inlines, or an inline forced where the C calls out: the rule is parity with the C's boundaries, not "smaller is better".
- A change that reads as tuning, with no C counterpart to point at.
- Any claim about wall time stronger than the A/B protocol of section 7 supports.

## 3. Constraints

As Campaign 6 (its section 3) with no additions: Zig 0.17.1 (`/usr/bin/zig`), the `zig build` prefixes under `/tmp/claude-1000/` with equal-length sibling names, `rm -f src/gen/config.{h,c,o}` before every `zig build`, builds and benchmarks under `systemd-run --user --scope -q -p MemoryMax=8G` with the 1-minute load under 2.0, no worktrees, no `pkill -f`, kill by PID only, no `git stash`/`reset --hard`/`clean`, nothing pushed and nothing merged by the builder except the one merge section 10 names. Branch `gc-call-boundary` off `zig-hash-engine` at 66ff45c8c, in the main checkout. Commits by the controller end with the Fable attribution lines, by implementers with the Opus lines, both with the session line.

## 4. The starting point (the spike's evidence, 2026-11-11)

Builds: `ng-c-syms` (C collector, Zig hash), `ng-n-syms` (Campaign 6 native collector), and the spike `sp-n-syms` (native plus `noinline` on `roots.gen2Add` and `finalize.addToQueue`), all `-Dstrip=false`, otherwise defaults. Raw data in `/tmp/claude-1000/ngc/spike/` until the next reboot (the Campaign 6 prefixes `ng-c-*`, `ng-f-*`, `ng-n-*` were all present on 2026-11-11, so no rebuild is needed unless a reboot intervenes); the builder's Task 1 reproduces every number below from the branch, and the records (section 9) cite the reproduction, not the spike.

Symbol sizes (`nm -S`, bytes): `allocateObject` 786 -> 369 (C 384); `allocateStable` 585 -> 344; `allocateTypeObject` 494 -> 259; `processWorklist` 2047 -> 1568. No other `gc.*`, `MVM_gc_*` or `moar.*` symbol changed size. Total `.text` of the spike build is within 400 bytes of the C build's.

Disassembly: the spike's `allocateObject` has the C's three callee-saved registers and 16-byte frame, the same branch structure, and direct calls where the C goes through the PLT. The native build's 786-byte body had both `MVM_realloc` paths inlined through mimalloc's thread-local heap lookup (`__tls_get_addr`, `_mi_theap_realloc_zero`, `_mi_malloc_generic`), once for the gen2 roots list and once for the finalize queue.

Counters, `--bad-packages`, five `perf stat` runs per side, medians: cycles native/C 1.012, spike/C 1.003; instructions native/C 1.004, spike/C 0.998. Samples, one run per side: `allocateObject` plus its export 1.60 % on the spike against `MVM_gc_allocate_object` 1.75 % on C (Campaign 6 measured 1.87 against 1.56); `processWorklist` 0.10 against `process_worklist` 0.10. A three-round A/B put wall at native/C 1.025 and spike/C 1.014 against a C spread of 1.009; three rounds on `-syms` builds are not the number, and section 7 says what is.

## 5. The change and the rule

Rule (call-boundary parity): where the C collector calls a function out of line, the Zig collector's call to the ported function is out of line too; where the C inlines (a `static inline` in a header, a macro), the Zig inlines (`inline fn`, Campaign 6's R6 and R11 shapes). Under `-Dlto=true` LLVM inlines across the Zig module freely, so parity has to be stated at the Zig definition. `noinline fn` on the definition is the shape; `@call(.never_inline, ...)` at a site is allowed only where the same function must inline at another site, and the builder records why.

Known sites (the spike): `pub noinline fn gen2Add` in roots.zig (C: `MVM_gc_root_gen2_add`, roots.c, called from wb.c, collect.c, gen2.c and the write-barrier inline); `pub noinline fn addToQueue` in finalize.zig (C: `MVM_gc_finalize_add_to_queue`, finalize.c, called from allocation.c).

Audit: the builder walks every call in `src/zig/gc/*.zig` and `moar.zig` whose C counterpart is a call to a function defined in another `.c` file of `src/gc` (or elsewhere in src), and checks in the `-syms` build whether the callee has been inlined into the caller: a callee symbol missing from the caller's disassembly where a call is expected, or a caller whose `nm -S` size is more than 1.5 times its C counterpart's. The audit's output is a table in the record: Zig call, C call, Zig inlined or not, C inlined or not (from the `ng-c-syms` disassembly, which is an LTO build like every default build), action. The 1.5x size threshold and the missing-callee check are triggers to inspect, not to act: `noinline` is added only where the C disassembly shows the same call out of line, and the builder may add it at such a site without a new ruling. A site where the C inlines and the Zig does not, or the reverse with no allocation, lock, panic path or loop in the callee, gets no change and a row saying so; a site that fits neither description is a question for the controller, recorded in the ledger, not a guess. Only callees containing an allocation, a lock, a panic path or a loop are candidates for `noinline`; a small leaf the C compiler would also inline under LTO (the C build is `-Dlto=true` too) is left alone and the table says so. The two spike sites are the expected result; the audit exists to say the list is complete.

Imports: roots.zig's `c.MVM_gc_mark_collectable(tc, worklist, col)` (gen2-roots marking) becomes a call to the Zig definition in collect.zig; gen2.zig's `c.MVM_gc_root_gen2_add(dest, root)` (gen2 roots transfer on thread exit) becomes `roots.gen2Add(dest, root)`. Both call the same code the export points at; the change is the symbol a call binds to. `markCollectable` is on the C's out-of-line side (collect.c, called from roots.c), so after the import it is a candidate for the rule like any other: the audit decides, and the builder notes that under the C's own LTO this call may inline.

## 6. Fidelity oracle

Campaign 6's, unchanged: `traces/llm/bench/ngc-oracle-driver.sh`, the C control against the new native build on `-Dgc-debug=1` prefixes (`-Doracle` tier and the stress tier at `-Dnursery-size=524288`), three program groups, two volumes, 24 cells of two logs, every cell byte-identical. Prefixes: the existing `ng-c-oracle`/`ng-c-stress` and new `cb-n-oracle`/`cb-n-stress` built from the branch (equal-length names). Any differing cell stops the campaign; a `noinline` keyword cannot change a decision, so a difference means something else moved and the controller rules before any benchmark runs.

## 7. Gate, aim and A/B protocol

Builds: `cb-n-base` (defaults) and `cb-n-syms` (`-Dstrip=false`) from the branch; `ng-c-base`, `ng-c-syms`, `ng-n-base`, `ng-n-syms` as they stand from Campaign 6 (rebuilt from their recorded commits if `/tmp` was wiped). The `.text` equality check of Campaign 6's section 7 is repeated for the new `-syms` build.

The gate (must pass for inclusion):
- Profile: `allocateObject` plus its export at or below `MVM_gc_allocate_object`'s cycle share on the C side plus 0.10 percentage points, and the collector total (the `gc.*`, `moar.*` and `MVM_gc_*` rows against the C's collector rows, aligned by the table in `ngc-profile-after.md`) within 0.30 percentage points of the C's. One `perf record` per side per setting, as Campaign 6; if either number lands within 0.05 points of its bound, the builder takes two more records per side and reads the gate off the medians of the three. At about 3.6e6 cycles per 0.01 points on this run, 0.30 points is 1.1e8 cycles, below the +1.24e8 the allocator alone carried at Campaign 6. Protocol: `tools/bench/gc/profile.sh`, five `perf stat` runs per side and one `perf record`, both settings, C and new native interleaved, as `ngc-profile-after-driver.sh` ran it.
- Oracle 24 of 24; `zig build test` and `zig build unit-test -Dgc-debug=1` as at Campaign 6's close (105 of 105, 66 of 66); exports unchanged (`nm -D` sets equal to Campaign 6's 2850).
- Tripwire: no crc-getter ratio new/C above the same-day native/C ratio (the head side of the three-sided run below, not Campaign 6's recorded 1.004/1.002 plain and 1.010/1.017 bad) by more than the C spread, on either measure of either setting. The tripwire asks whether the change made the native collector worse; the aim asks whether it reached the C. They do not conflict: a bad wall that reads 1.010 against 1.010 passes the tripwire and misses the aim, and the ruling of section 13 keeps the shape. A tripwire crossing is a stop: Task 5 hands back instead of merging, after one seven-round re-run as Campaign 6's R3 provided.

The aim (reported, not gated; the user's words, 2026-11-11: "bad-packages wall inside the C spread, 4 of 4"): crc-getter new/C within the C control's spread on wall and RSS, both settings. Protocol: three-sided `ab.sh --rounds=7 --runs=5 --volume=100000`, base `ng-c-base`, head `ng-n-base`, head2 `cb-n-base`, both settings, so the Campaign 6 number is re-measured on the same day and the gain is read off two ratios sharing a base. A miss is recorded as a miss with the spread beside it. The user's ruling (section 13) is that a miss by noise width does not revert the change if the profile gate passed; the spike's profile (section 4) already says the remaining wall gap is outside the collector, and the record says so in those words if the aim is missed.

## 8. Testing

- `zig build test` and `zig build unit-test -Dgc-debug=1`; the `gc-test` suite as at Campaign 6.
- One new check is required by the rule, not by the behaviour: `tools/bench/gc/call-boundary.sh LIBDIR`, which reads the `-syms` build's disassembly and exits non-zero unless each audited callee is reached by a `call` from each of its expected callers (the table of section 5 is its input, kept in the script). It runs in the acceptance driver and in the final review, not in `zig build test`, so the unit-test counts stay at 105 and 66. A `comptime` check was considered and dropped: it would assert the keyword, not the binary.
- Cleanup and stress: `tools/bench/gc/cleanup.sh` on `cb-n-base` and `cb-n-stress`, 60 of 60 each, as Campaign 6's acceptance ran them.

## 9. Records

In `traces/llm/bench/`, prefix `cb-`: `cb-audit.md` (section 5's table, with the `nm -S` before/after per function), `cb-oracle.md`, `cb-crc-ab.md`, `cb-profile.md` (counters, rows, the gate verdict, the finding paragraph), `cb-prefixes.md`; raw data beside them as Campaign 6 kept it. `docs/zig-build.md` "### Native shapes" gains a paragraph on the call-boundary rule. The plan's Outcome table and this spec's Errata section are filled at acceptance. Campaign 6's deferred list in `ngc-ledger.md` gets a pointer to what this campaign closed.

## 10. Task ladder (the short staircase)

1. Branch, the two `noinline` keywords, the two imports, the audit and its table, the out-of-line check of section 8; `zig build test`; `nm -S` before/after; commit.
2. Prefixes (`cb-n-oracle`, `cb-n-stress`, `cb-n-base`, `cb-n-syms`), the oracle, the unit tests, exports; commit the records.
3. The seven-round three-sided A/B on both settings, the after-profile on both settings, cleanup and stress; the gate verdict and the aim's result; records and docs; Outcome and Errata; commit.
4. Final whole-branch review (fable), one fix wave at most, re-review.
5. Inclusion: with the gate passed and the review clean, fast-forward `zig-hash-engine` to the branch tip in the main checkout. Nothing is pushed. If any gate fails or the review is not clean after its fix wave, stop and hand back instead.

Three implementer tasks, one review, one merge. Per-task review (Sonnet) after Tasks 1 to 3 as the SDD process requires; implementers Opus; the final review fable.

## 11. Risks

- The audit finds a third site where `noinline` changes the profile the other way (a hot leaf the C compiler inlined under its own LTO). The rule's wording covers it: parity with what the C build does, checked in the C `-syms` disassembly, not with the C source's file boundaries alone.
- `/tmp` wiped by a reboot: the Campaign 6 prefixes are rebuilt from their recorded commits (`ngc-prefixes.md`) before any three-sided run.
- Seven rounds read the aim as missed by noise width again. Section 7's ruling applies; the record states the collector's share of the remaining gap from the profile, as Campaign 6's record did.
- A `noinline` on `gen2Add` also reaches `processWorklist`, the hottest collector loop: the spike shows it shrinking by 479 bytes and its cycle share unchanged at 0.10 %, but the after-profile must confirm the row did not grow.

## 12. Left to the builder

How `call-boundary.sh` locates callers in the disassembly (symbol names of the `-syms` build; LTO may rename or clone, and the script says what it matched); whether `markCollectable` gets the keyword after the import (the audit decides); the wording of the docs paragraph; prefix build order; how the audit table lists the C side's inlining evidence.

## 13. Decisions recorded

The user's (2026-11-11): the target is "bad-packages wall inside the C spread, 4 of 4"; a miss by noise width keeps the shape "if the profile is clearly better"; "spike it first" (done, section 4); "short staircase to inclusion": the short ladder without a spectest run, ending with the merge into `zig-hash-engine`.

Mine: "clearly better" is section 7's gate (allocator row at or below the C's, collector total at parity); the two deferred imports ride along; the audit and the out-of-line check are in scope so the rule outlives the two sites; the merge in Task 5 is the inclusion the user asked for and is conditional on the gate and the review; no spectest.

## Errata (as built)

Filled at acceptance (Task 3, 2026-11-11).

1. Section 6, "the stress tier at `-Dnursery-size=524288`", and section 7's "Oracle 24 of 24": Campaign 6's two
   oracle tiers are `oracle.sh --tier=1` and `--tier=2` (tier 2 adds `MVM_GC_DEBUG_RSS`) on the `-oracle` prefixes;
   the stress prefixes never fed the oracle, and the C control itself does not repeat at that nursery (three runs of
   `ng-c-stress` give three different logs; `cb-oracle.md`, "Stress pair"). Campaign 6's 24 cells were three groups of
   8; this campaign has one pair, so the gate is group a's 8 cells (`ng-c-oracle` against `cb-n-oracle`, two volumes x
   two settings x two tiers), 8 of 8 byte-identical. The stress prefixes' consumer is `cleanup.sh --stress`
   (`cb-cleanup.md`).
2. Section 5, "The two spike sites are the expected result": the audit found four more definitions the C build calls
   out of line and the Zig build had inlined, `worklist.addSlow`, `worklist.create`, `worklist.presizeFor` and
   `finalize.walkQueues`, and added `noinline` to them under the section's own clause (C disassembly shows the call
   out of line, the callee allocates or loops); six definitions in all, 18 checked rows in `call-boundary.sh`
   (`cb-audit.md`). Section 10's "the two `noinline` keywords" (and the plan's "the two sites" for the docs paragraph)
   read accordingly as six.
3. Section 7, the `.text` check "repeated for the new `-syms` build": `cb-n-syms` differs from `cb-n-base` as
   Campaign 6's pairs did (+265168 bytes of std.debug, the same two 4-byte `nm -D -S` differences), so the fallback
   A/B ran for the cb-n pair (cb-n-syms 1.1 % faster than its base); the ng-c pair's A/B was cited from
   `ngc-profile-after.md` (0.8 % faster), not re-run, and the attribution pass on `-nlto` builds was dropped (no cb
   nlto prefix). Both profiled sides are labelled "a different binary" (`cb-profile.md`).
4. Section 8, cleanup "as Campaign 6's acceptance ran them": Campaign 6 ran its `-stress` prefixes with the plain
   program set (its Ruling R4); this campaign ran `cb-n-stress` with `cleanup.sh --stress` (the 20x variants), as the
   plan's Task 3 names it.
5. Section 7, the tripwire: the --bad-packages wall reading lands exactly on the bound, not above it (cb/C 1.010
   against the same-day ng-n/C 1.001, a difference of 0.07 s against a C spread of 0.07 s at timev's 0.01 s
   resolution; `cb-crc-ab.md`). The rule's "by more than" makes it a pass; a reading at the bound is recorded as
   such, not as a margin. The controller ruled the one seven-round re-run all the same; it reads cb/C 1.010 against
   ng-n/C 1.011, a pass.
