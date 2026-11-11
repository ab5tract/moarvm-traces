# SDD ledger — plan: traces/llm/plans/2026-11-11-gc-call-boundary.md

Spec: traces/llm/specs/2026-11-11-gc-call-boundary-design.md (reachable). Branch gc-call-boundary created 2026-11-11 off zig-hash-engine 3145f190e (main checkout, no worktree per user rule).

## Pre-flight scan (2026-11-11)

| pair / task | produces vs consumes | found |
|---|---|---|
| T1 / T2 | T1 creates cb-prefixes.md (cb-n-syms line); T2 appends three lines | consistent |
| T1 / T3 | T1 produces call-boundary.sh LIBDIR (exit 0/1/2); T3's cb-crc-ab-driver.sh runs it on cb-n-syms/lib and refuses on non-zero | consistent |
| T1 / T3 | T1 builds cb-n-syms; T3 profile driver uses c=ng-c-syms n=cb-n-syms | consistent |
| T2 / T3 | T2 builds cb-n-base/cb-n-stress; T3 A/B head2=cb-n-base, cleanup on both | consistent; equal-length names (ng-c-base/ng-n-base/cb-n-base) |
| T3 / T5 | T3 fills Outcome; T5 preserves ledger/review as cb-ledger.md, cb-final-review.md | consistent |
| T1 self | Step 1 branch creation already done by controller (3145f190e); edits listed under Files match Step 2; Step 3 expectations match spike; Step 6 negative test uses ng-n-syms | consistent; dispatch tells implementer the branch exists |
| T2 self | driver group a only = 8 cells / 16 logs; exports 2850 | consistent |
| T3 self | 7 rounds x 5 runs x 3 sides x 2 settings = 210 runs | consistent |
| T4/T5 self | fable review; ff-only merge, nothing pushed | consistent with spec s13 |
| Global vs T1 | only permitted Zig edits: noinline, @import, c.MVM_ -> Zig call, comments; T1's four edits are exactly these kinds | consistent |

Scan clean; no rulings needed before Task 1.

## Task 1
BASE 3145f190e; implementer dispatched (opus) 2026-11-11 18:08.
Task 1: implementer DONE_WITH_CONCERNS; commits 782a56faa (four briefed edits), c5aebb78a (four audit noinlines: worklist.addSlow, worklist.create, worklist.presizeFor, finalize.walkQueues + call-boundary.sh), 6cfbe7e3f (traces pointer; traces 0e384b9). Sizes join exactly the briefed 4 rows; tests 105/105, 66/66; script 0/1/2; exports 2850.
Task 1: Ruling: the four extra noinlines stand pending review of their C-side evidence — spec s5 lets the builder add noinline without a new ruling where the ng-c-syms disassembly shows the C call out of line and the callee has alloc/lock/panic/loop — cost if wrong: a Zig shape the C does not have, visible in the profile and reversible by one commit (c5aebb78a).
Task 1: Ruling: one unit-test run at load 2.38 accepted (deterministic count, the re-run under 2.0 was cached) — Task 2 Step 4 re-runs both suites on the tip under load — cost if wrong: none to the result, only to the process record.
Task 1: minor (deferred): tools/bench/gc/README.md has no row for call-boundary.sh (implementer concern 5; reviewer may raise it).
Task 1: review dispatched (sonnet) on review-3145f190e..6cfbe7e3f.diff.
Task 1: review clean (sonnet); four extra noinline rows verified against ng-c-syms disassembly by the reviewer; controller resolved the two cannot-verify items: zig fmt --check clean, trailers present on all four commits.
Task 1: minor (deferred): call-boundary.sh header does not say a .llvm. clone also yields exit 2; the script counts `call` only, so the mark_last_handler_result -> addSlow tail `jmp` row has no script row (audit records it); README.md row for the script.
Task 1: complete (commits 3145f190e..6cfbe7e3f, review clean)

## Task 2
BASE 6cfbe7e3f; implementer dispatched (opus).
Task 2: implementer DONE_WITH_CONCERNS; commits 2f1c61e62 (pointer; traces 1cfd8ec). Builds 3/3 exit 0 from 6cfbe7e3f; exports same, 2850; oracle group a 8/8 exit 0 raw_cmp same; tests 105/105, 66/66 genuine.
Task 2: Ruling: the oracle gate is group a's 8 cells (oracle.sh tier 1 and tier 2, as Campaign 6 ran it); the spec s6 phrase "the stress tier at -Dnursery-size=524288" and the plan's "stress tier ng-c-stress vs cb-n-stress" were the controller's error (Campaign 6's tier 2 is MVM_GC_DEBUG_RSS, not a stress prefix) — the implementer's group s showed the C control itself does not repeat at the 512 KiB nursery (promoted counts differ run to run), so no stress oracle exists to pass; the stress prefixes serve cleanup.sh --stress in Task 3 as in Campaign 6; Task 3 records this in the spec's Errata — cost if wrong: an oracle cell the campaign never had; the native-vs-C comparison at the stress nursery remains covered by cleanup --stress and Campaign 6's acceptance.
Task 2: review dispatched (sonnet).
Task 2: review (sonnet): 1 Important (driver default "a s" runs the known-unrepeatable group s), 2 Minor. Fix round 1 dispatched to the implementer (default a; header note; cb-oracle.md command line + ruling sentence).
Task 2: minor (deferred): cb-oracle.md Raw line could say matrix.tsv rows 9-10 are group s; Stress pair section could name cleanup.sh --stress as the stress prefixes' consumer (the fix round's ruling sentence covers the second).
Task 2: fix round 1/5 (1 addressed pending re-review, 0 open — driver default a; commits 2f1c61e62..11a2e2e84, traces 1cfd8ec..e4758f9); re-review dispatched (sonnet).
Task 2: re-review: all findings addressed, no new breakage.
Task 2: complete (commits 6cfbe7e3f..11a2e2e84, review clean after 1 fix round)

## Task 3
BASE 11a2e2e84 (traces e4758f9); implementer dispatched (opus).
Task 3: implementer DONE_WITH_CONCERNS; commits bcb1e18b9 (docs), c35551455 (pointer; traces 9e5486e). A/B 210/210: head2/C wall 1.001 plain / 1.010 bad, RSS 0.984/0.983; same-day head/C 0.999/1.001; C spread 0.0093/0.0088. Tripwire bad wall: +0.0088 vs spread 0.0088 (equal, not more than) = pass by the letter; 6 of 7 cb round medians above every ng-n round median. Aim 3 of 4 (bad wall misses). Profile gate passes: plain allocator 1.63 vs C 1.59 (bound 1.69), collector +0.15 (bound 0.30); bad allocator 1.54 vs 1.61, collector -0.12. Cleanup 60/60 both.
Task 3: Ruling: run the one seven-round bad-packages re-run now although the tripwire did not cross — a reading exactly on the bound with 6/7 rounds ordered is too thin to carry the inclusion decision; the Global Constraints allow one re-run at a crossing and nothing forbids one at the bound; both runs go in cb-crc-ab.md with verdicts per run and a combined verdict (pass only if neither run crosses) — cost if wrong: about 20 minutes of machine time.
Task 3: note: dispatch gave process_worklist's C size as 1073 (that is markCollectable's); implementer used 1359 from cb-audit.md, correct. The crc driver exit-column defect was already fixed at Campaign 6 Task 9; copy keeps it.
Task 3: re-run (bad only, 105/105): head2/C wall 1.010 RSS 1.003; head/C 1.011 / 0.996; C spread 0.0088; ordering 0 of 7 (first run 6 of 7, a day effect). Tripwire pass both runs; aim bad wall misses both runs at 1.010 (= Campaign 6's miss), 3 of 4. Commits bd7ac476a (traces 6845d66).
Task 3: review dispatched (sonnet) on 11a2e2e84..bd7ac476a + traces e4758f9..6845d66.
Task 3: review clean (sonnet): all arithmetic recomputed and matching; 0 Important, 4 Minor. Controller resolved the cannot-verify items: 105 .time files per setting plus 105 for the re-run (315 runs), ab.sh exits 0 in runs.log, cleanup 60/60 + 60/60 in cb-cleanup.md, analyze.pl exit 2 is the missing nlto section (analysis-note.txt), benign.
Task 3: minor (deferred -> final review): cb-crc-ab.md first-run aim paragraph ("the day's noise does not explain the miss: it is head2's") and the "up to about 0.9 % slower" tripwire sentence are contradicted by the re-run section and were not annotated; docs/zig-build.md call-boundary paragraph missing the word "absent" ("2 when a symbol is (a stripped build)"); cb-cleanup.md title "120 of 120" vs the gate wording "60 of 60 each"; plain setting rests on one run (stated in the record).
Task 3: complete (commits 11a2e2e84..bd7ac476a, review clean)

## Task 4: final whole-branch review
Task 4: final review dispatched (fable) on 3145f190e..bd7ac476a + traces 0f10957..6845d66; report to final-review.md.
Task 4: final review (fable): With fixes. 0 Critical; 3 Important: (1) cb-crc-ab.md:63 and :76-77 first-run sentences ("up to about 0.9 % slower", "it is head2's") contradicted by the re-run, unannotated; (2) spec Errata needs item 6: sections 2/13 say "allocator row at or below the C's", section 7 "plus 0.10"; strict phrasing met on bad (1.54 vs 1.61), not plain (1.63 vs 1.59, inside the bound); (3) README.md row for call-boundary.sh. Minors 4-11. Rulings (1)-(3) judged correct. Declined-to-judge list recorded in final-review.md; controller rules: all nine lines are outside this campaign's scope and stay as recorded (aim miss reported per spec 13; C control non-repeatability at 512 KiB is a follow-up for the user).
Task 4: fix wave dispatched (opus) per final-fix-brief.md: Important 1-3, Minor 4 (docs "absent"), Minor 5 (callq?), Minor 7 (toolchain line). Deferred (ledger): Minor 6 clone diagnostic / tail-jmp row; Minor 8 .text total and prologue shape not reproduced in cb-audit.md; Minor 9 cb-oracle Raw line; Minor 10 cb-cleanup title; Minor 11 docs sentence on the frozen C reference.
Task 4: fix wave: traces 15d6897, MoarVM d0a42f79f; six findings fixed; toolchain line names Zig 0.17.1 bundled clang 22.1.8 (system clang 23.1.1 built none of the libraries). Scoped re-review dispatched (sonnet).
Task 4: re-review (sonnet): all six findings addressed, no new breakage. Out of scope (deferred): cb-crc-ab.md "It is not a margin either" sentence unannotated (accurate for the first run); Toolchain line omits GCC 16.2.1 from .comment (immaterial).
Task 4: complete (final review clean after one fix wave; commits bd7ac476a..d0a42f79f, traces 6845d66..15d6897)

## Task 5: inclusion
Gate check: oracle 8/8 identical; exports same 2850; unit tests 105/105, 66/66; tripwire pass (both bad runs, no crossing); profile gate pass both settings; cleanup 60/60 x2; final review clean after the fix wave. Every condition of spec s13 / plan Task 5 met: fast-forward zig-hash-engine to gc-call-boundary in the main checkout, nothing pushed.
Preserved as traces/llm/bench/cb-ledger.md and cb-final-review.md (this ledger up to this line; final-review.md verbatim).
