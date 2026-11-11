# Final whole-branch review: gc-call-boundary (3145f190e..bd7ac476a; traces 0f10957..6845d66)

Reviewer: Fable (final review, plan Task 4). Read-only; no subagents. Both review packages read in full, the spec, the plan, `ngc-profile-after.md`, and the raw data under `/tmp/claude-1000/cb/` where a number needed recomputing.

## What I verified independently (all pass)

| check | method | result |
|---|---|---|
| no C/H change | `git diff --name-only 3145f190e bd7ac476a -- 'src/*.c' 'src/**/*.c' 'src/*.h' 'src/**/*.h'` | 0 files; `src/zig/moar.zig` also untouched; the range touches exactly `docs/zig-build.md`, four `src/zig/gc/*.zig`, the new script and the submodule pointer |
| Zig edits are the permitted kinds | read the full diff | six `noinline` on definitions (gen2Add, addToQueue, addSlow, create, presizeFor, walkQueues), two `@import` lines, two `c.MVM_...` calls replaced by the Zig function they name; nothing else, no `@call(.never_inline)` |
| exports | `nm -D --defined-only` set diff, cb-n-base vs ng-c-base; cb-n-syms vs ng-n-syms | both `same`, 2850 and 2850 |
| `call-boundary.sh` | `sh -n`; run on cb-n-syms, ng-n-syms, ng-n-base, no arg, bad dir | 0 (18 rows), 1 at `allocateObject -> gen2Add`, 2 (stripped), 64, 64, as the header documents |
| C-side evidence (plan Review Focus 1), four audit-added callees | `objdump --disassemble=<C caller> ng-c-syms` | `MVM_gc_collect`: add_slow@plt x5, create@plt x1, presize_for@plt x1, mark_collectable@plt x1; `MVM_gc_mark_collectable`: add_slow@plt x10 + tail `jmp` x1; `run_gc`: walk_queues@plt x1; `MVM_gc_root_add_tc_roots_to_worklist`: x15; `..._frame_roots_...`: x9; `MVM_gc_root_add_gen2s_to_worklist`: presize_for@plt x1. Every count equals the audit table's |
| spike numbers reproduced | `nm -S` on cb-n-syms / ng-c-syms | allocateObject 369 / 384, processWorklist 1568 / 1359, markCollectable 952 / 1073, addSlow 201 / 206, create 328 / 325, presizeFor 172 / 172, walkQueues 93 / 534; the export wrappers are 5-13 byte tail jumps |
| allocator shape (spec section 4) | prologue/epilogue and call set of `gc.allocation.allocateObject` vs `MVM_gc_allocate_object` | identical: `push %r15; push %r14; push %rbx; sub $0x10,%rsp`, the same eight call targets (Zig direct where the C goes through the PLT) |
| gate arithmetic (cb-profile.md) | recomputed from `/tmp/claude-1000/cb/profile/{plain,bad}/{c,n}-r1/report.txt` | C collector rows 3.93 % (17 rows) / 4.02 % (14); cb 4.08 % (18) / 3.90 % (16); allocator C 1.59 / 1.61, cb 1.53+0.10 / 1.41+0.13; full precision from `report-period.txt`: C 580892242/36519333079 = 1.5906 %, cb (37287276+551975114)/36153419593 = 1.6299 %, margin 0.0607 above the 0.05 repeat threshold. Bounds 1.69 / 1.71 and 0.30: pass on all four numbers |
| A/B arithmetic (cb-crc-ab.md, both runs) | recomputed from all 315 `.time` files with my own script | plain: C 7.53 [7.47-7.54] spread 0.0093, head/C 0.9987, head2/C 1.0013, diff +0.0027; bad: C 7.98 [7.92-7.99] spread 0.0088, head/C 1.0013, head2/C 1.0100, diff +0.0088; re-run: C 7.95 spread 0.0088, head/C 1.0113, head2/C 1.0101, diff -0.0013; RSS 0.9842/0.9838, 0.9847/0.9829, 0.9956/1.0034. Every cell matches the record and summary.md |
| LTO clones | `nm` on both -syms builds | 0 `.llvm.`-suffixed symbols in either; the only numbered clones are the C header static inline `MVM_gc_allocate_gen2_default_clear.NNNN` (6 in each build), none in the script's table; no duplicate `gc.*` names, so `--disassemble=` is unambiguous |
| import cycles (Review Focus 2) | read every `comptime` block in roots/collect/gen2/worklist/finalize | all are self-contained (offset/size asserts over `c.*` types, `@export` of local wrappers); none evaluates a declaration of the other file at comptime |
| oracle | `matrix.tsv` at traces 6845d66 | rows 1-8 group a exit 0 `same`; rows 9-10 group s exit 2 `differ` (the unrepeatable C control), as the record says |
| commits | `git log` | eight commits, imperative subjects, reasoning bodies, both attribution lines on each |

### Strengths

- The code change is exactly what the rule says and nothing more: six keywords, two imports, two call-site renames. No logic moved, no symbol exported or lost, and the oracle's 8 of 8 byte-identical cells plus 105/105 and 66/66 unit tests cover the decisions.
- The audit (`cb-audit.md`) is the best piece of the campaign. It is built from the binary, not the source: the 52 cross-file C calls of `ng-c-syms` are the deciding list, each looked up on the Zig side; every `noinline` row carries the C-side call count, the Zig before/after count, the callee's alloc/loop property and the size pair; the reverse case (Zig out of line where the C inlines, `addPermanentsToWorklist` etc. into `collect`) is recorded and correctly left alone; the 1.5x trigger's two residual hits (`compactOverflows`, `gen2Cleanup`) are explained as leaf loops inlined in both builds. I verified six of its C-side counts and all agree.
- The result is strong and honestly measured: allocateObject 369 bytes with the C's register and frame shape; `markCollectable` 3360 -> 952 (now smaller than the C's 1073); the profiled cycle gap 1.90 % -> 0.38 % plain, 2.20 % -> 0.24 % bad; the cb side executes fewer instructions than the C control; the allocator row moved from +0.31 points to +0.04.
- `call-boundary.sh` has exact-name matching, honest exit codes, a `--help` that prints its own header, a negative test on the Campaign 6 binary and a stripped-build test, and it gates the A/B driver. It is the right artefact to make the rule outlive the two spike sites.
- The three-sided A/B design paid off: the same-day head/C moving from 1.001 to 1.011 between the two bad-packages runs while head2/C held at 1.010 is exactly the evidence that separates "the change" from "the day", and the record draws that conclusion in its combined verdict.
- The tripwire reading on the bound was neither rounded into a pass with a margin nor into a failure; Errata 5 states it as a reading on the bound, and the re-run was ordered in the direction that could only hurt the branch.
- Records are reproducible: drivers committed, raw data beside them, commit hashes and build options for every prefix, load logged before every run, the `-syms` "different binary" caveat carried from Campaign 6.

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

1. **`traces/llm/bench/cb-crc-ab.md:63` and `:76-77`: two first-run sentences assert a conclusion the re-run withdraws, without annotation.** Line 63: "On this day the change reads as up to about 0.9 % slower than Campaign 6's native build on --bad-packages wall"; lines 76-77: "the day's noise against the C does not explain the miss: it is head2's, against the head's 1.001 on the same base." The re-run section (line 114, "it reads as round-to-round noise of the head sides") and the combined verdict say the opposite, and the record's title agrees with the re-run. A reader who stops at the first-run sections, which come first and are the larger part of the record, concludes the change made the native collector slower than Campaign 6's binary; the data as a whole does not support that. Fix: a parenthetical after each sentence, "(first run; the re-run below does not reproduce this, see 'Re-run')", or move the two sentences into a past-tense "first run read" framing. Two lines.

2. **Spec Errata: sections 2 and 13 say "allocator row at or below the C's"; section 7 says "at or below ... plus 0.10 percentage points"; plain lands 0.04 above.** Section 13's "clearly better" definition (the controller's reading of the user's condition for keeping the shape when the aim is missed) is phrased as the strict form, and the plain allocator row is 1.63 % against 1.59 %: above the C's, inside the +0.10 bound. The gate that section 7 defines is the operative one, the verdict is correct under it, and the records print the numbers plainly, so this is not a false verdict; but the Errata, which are the place the spec promises to reconcile its own wording with what was built, do not say that the goal's strict phrasing was met on bad (1.54 against 1.61) and not on plain (0.04 above, inside the bound, the order of one sampled run's noise since the C's own row moved 1.56 -> 1.59 between days). Fix: one Errata item (6) saying so. The user relied on "clearly better"; the record should let them see that on plain the row is at parity within noise, not below.

3. **`tools/bench/gc/README.md`: no row for `call-boundary.sh`.** Every other script in the directory has a row describing its purpose, inputs and exit codes; the README is how a maintainer finds the tools. Deferred at Task 1 and still absent. Fix: one row (purpose, `LIBDIR` of a `-Dstrip=false` build, exits 0/1/2/64, "not part of `zig build test`", pointer to `cb-audit.md`).

#### Minor (Nice to Have)

4. `docs/zig-build.md:560-561`: "1 when a call is missing and 2 when a symbol is (a stripped build)" elides "missing" before the parenthetical; grammatical as an ellipsis but a reader stumbles. Write "2 when a symbol is absent (a stripped build)".

5. `tools/bench/gc/call-boundary.sh:93`: `grep -E '[[:space:]]call[[:space:]]'` matches GNU binutils >= 2.37 (`call`); older binutils and `llvm-objdump` print `callq`, on which every row would fail with exit 1, a loud but misleading false negative. `callq?` costs nothing. Relatedly the header could name GNU binutils (`--disassemble=` is a GNU option) as a requirement.

6. `tools/bench/gc/call-boundary.sh` failure diagnostics: on exit 1 the script prints only "does not call". If LLVM ever cloned a callee (`gc.worklist.addSlow.llvm.NNNN` or a numbered clone like the six `MVM_gc_allocate_gen2_default_clear.NNNN` already in both builds), the exact match would fail while the call is present under the clone's name. Printing the caller's `call` lines whose target starts with the callee's name on failure would make a clone visible in one run. The header's note that a clone yields exit 2 (the deferred minor) is only right when the canonical symbol has vanished; with the canonical symbol still defined, a clone yields exit 1. Say both.

7. `traces/llm/bench/cb-audit.md` header: no toolchain line. The C-side evidence is one clang's (22.1.8) LTO decision and the symbol matching is one binutils' (2.47) output format; `cb-profile.md` records both, the audit does not. Add a `Toolchain:` line, since this is the record a future audit will be compared against.

8. `traces/llm/bench/cb-audit.md`: spec section 4 asked Task 1 to reproduce "every number below", and two are not in the record: the `.text` total ("within 400 bytes of the C build's" for the two-site spike; with six sites `cb-n-syms` is 2645493 against `ng-c-syms` 2657221, 11.7 KB smaller, `ng-n-syms` 2658613) and the allocator's register/frame shape (identical to the C's, verified above). One sentence each; the first corrects the spike's figure for the built shape.

9. `traces/llm/bench/cb-oracle.md:24` Raw line: say that `matrix.tsv` rows 9-10 are the group s cells (exit 2, `differ`), so a reader of the tsv alone does not read them as a failed gate.

10. `traces/llm/bench/cb-cleanup.md:1` title "120 of 120" against the gate's "60 of 60 each": consistent with the body; harmless.

11. `docs/zig-build.md` paragraph: once the C collector is removed from the tree (the deferred full-Zig stack), the script's table becomes the rule's only frozen form. One sentence saying the table is the record of the C build's boundaries at clang 22.1.8 would tell the next maintainer what to do when a row fails after a compiler upgrade (consult `cb-audit.md`, re-audit, do not delete the row).

### Deferred-minor triage

Must fix before merge (fold into the one fix wave with Important 1-3):
- `tools/bench/gc/README.md` row for the script (Important 3).
- `cb-crc-ab.md` first-run sentences annotated (Important 1).
- `docs/zig-build.md` "absent" (Minor 4; same file as the fix wave touches anyway).

May stay deferred (record in the ledger):
- Script header on `.llvm.` clones and exit code (Minor 6), the tail-`jmp` site having no script row (the audit records it; a `kind` column would be a redesign the rule does not need today).
- `cb-oracle.md` Raw line wording (Minor 9).
- `cb-cleanup.md` title (Minor 10).
- The plain setting resting on one seven-round run: the spec's protocol was one run per setting; the re-run was ruled for bad only and the plain readings (+0.0027 against 0.0093) are not near any bound. Stated in the record; stays.

### Judgement items the brief asked for

- **`noinline` on `worklist.addSlow` and the marking hot path.** No cost the C does not pay. The C's `MVM_gc_worklist_add` macro is the same shape: inline test-and-store fast path, out-of-line `MVM_gc_worklist_add_slow` through the PLT when the list is full. The Zig fast path stays `inline fn worklistAdd`; the slow path is now a direct `call gc.worklist.addSlow` (LTO resolved through the protected export, no PLT), reached once per doubling. The Zig pays strictly less per growth event than the C, and the hot-path code shrank (markCollectable 3360 -> 952, below the C's 1073), which the profile confirms: processWorklist unchanged at 0.11 %, markCollectable 0.04 against 0.03.
- **Import cycles.** `roots <-> collect` and `gen2 -> roots -> collect -> gen2` are new; the collector already had cycles (collect imports roots, roots imports worklist, collect imports worklist and gen2). Zig's lazy analysis only fails on an actual comptime dependency loop, and every `comptime` block in the five files is self-contained (asserts over `c.*` layouts, `@export` of local wrappers). A future cross-file comptime dependency would fail at compile time with "dependency loop detected", never silently. Both unit-test builds compile. No action.
- **Script robustness and honesty.** Exact-name matching is right (the numbered clones in both builds show why), there are no `.llvm.` symbols in either build today, exit codes propagate correctly through the `set -e` pipeline (verified: 1, 2, 64), the temp file is cleaned by trap, and nothing is written. Minors 5 and 6 above are the only gaps.
- **Two bad-packages runs presented.** The title, the re-run section and the combined verdict are right; the two first-run sentences are the problem (Important 1).
- **Errata and Deviations.** Complete on the five items they list, each honest (Errata 5 in particular refuses to call a reading on the bound a margin). One addition needed (Important 2); Minor 8 is a smaller omission of the same kind.
- **Controller rulings.** (1) correct: every audit-added row has C-side evidence I reproduced, and each callee allocates or loops as section 5 requires. (2) correct: Campaign 6's tiers were `--tier=1/2` on `-oracle` prefixes; the group-s cells show the C control itself does not repeat at the 512 KiB nursery (promoted counts differ at line 12-13), so no such oracle exists; the stress prefixes serve `cleanup.sh --stress`. (3) correct and conservative: the re-run could only have hurt the branch; "pass only if neither run crosses" is the stricter reading; a reading on the bound with 6 of 7 rounds ordered was genuinely too thin, and the re-run (0 of 7 ordered, head/C itself at 1.011) resolved it.
- **The rule as architecture.** "Where the C build calls out of line under its own LTO, the Zig build calls out of line, held by `noinline` on the definition" is the right invariant for a port whose claim is parity: it compares compiler output with compiler output, it is checkable from the binary, and it is stated in three places (spec 5, the script header, `docs/zig-build.md`) with the audit method written down in `cb-audit.md` so the next port can repeat it. Its one dependency, on the C build of the day, is what Minors 7 and 11 ask the records to name.

### Declined to judge

- The bad-packages wall aim miss (1.010 on both runs, against a C spread of 0.0088): spec 7 and 13 make the aim reported, not gated, and the user's ruling keeps the shape when the profile gate passes. Set aside as outside the gate.
- The "unresolvable at volume 100 000" rule and the computed collector shares (0.437 / -0.467): Campaign 6's method applied unchanged; the record says they carry no weight. Not re-examined.
- The `-syms` versus `-base` "different binary" caveat (cb-n-syms 1.1 % faster than its base): Campaign 6's methodology and disclosure, applied as is.
- `analyze.pl` exiting 2 at its missing nlto section: a Campaign 6 tool's behaviour, disclosed in `analysis-note.txt`; not changed in this range.
- The C control's non-repeatability at the 512 KiB nursery (promoted bytes vary run to run with precompilation off): a pre-existing property of the C collector or the workload, worth a follow-up, not this campaign's.
- The six `MVM_gc_allocate_gen2_default_clear.NNNN` numbered clones in both builds: C header static inline duplicated per translation unit; not touched by the range.
- No spectest run: the user's ruling in spec 13.
- The two untracked paths (`.superpowers/`, `tools/lib/MAST/Ops.rakumod`): pre-existing, excluded by the Global Constraints.
- `cb-n-syms`'s version string naming 782a56faa while its `src/` equals c5aebb78a: disclosed in `cb-prefixes.md` and `cb-profile.md`; the equal-length requirement against `ng-c-syms`'s version line holds.

### Recommendations

1. Fix wave, one commit each side: Important 1 (two parentheticals in `cb-crc-ab.md`), Important 2 (Errata item 6), Important 3 (README row), Minor 4 ("absent"); optionally Minors 5 and 7 since they are one line each in files the wave already touches. Then the scoped re-review and Task 5.
2. Record in the ledger as deferred: Minors 6, 8, 9, 10, 11.
3. For the next port campaign: make the binary-level audit (`cb-audit.md` "The method") the template, and extend `call-boundary.sh` with a `kind` column (`call`/`jmp`) only if a tail-jump row ever becomes the sole evidence for a `noinline`.
4. When the C collector leaves the tree, cite `cb-audit.md` from the script header as the frozen reference (Minor 11).

### Assessment

**Ready to merge?** With fixes

**Reasoning:** The code is exactly the permitted edits, every number in the gate, the A/B and the audit recomputes from the raw data, and the C-side evidence for each `noinline` is in the C disassembly; nothing is Critical. Three Important items, all in records and docs (two unannotated first-run sentences that contradict the re-run, one missing Errata line on the "at or below the C's" wording, the README row for the new script), should land in the one fix wave before the fast-forward.
