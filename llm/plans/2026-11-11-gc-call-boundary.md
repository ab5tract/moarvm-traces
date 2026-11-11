# GC Call-Boundary Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** written 2026-11-11; not started.

**Goal:** Keep the Zig collector's slow-path calls out of line where the C collector's are, replace the two remaining C cross-calls with Zig imports, prove the decisions unchanged with the oracle, measure the gain with the three-sided A/B and the after-profile, and include the branch in `zig-hash-engine`.

**Architecture:** Task 1 makes the code change (two `noinline` keywords, two imports), builds the symbols prefix, audits every Zig-to-Zig collector call against the C build's disassembly, and adds the `call-boundary.sh` check. Task 2 builds the remaining prefixes and runs the oracle, the unit tests and the export comparison. Task 3 runs the seven-round A/B, the after-profile, cleanup and stress, writes the records and docs, and fills the spec's Errata and this plan's Outcome. Then the final review and the fast-forward merge.

**Tech Stack:** Zig 0.17.1 (`/usr/bin/zig`), binutils (`nm -S`, `objdump -d`), perf 7.2 (`perf_event_paranoid` 2, `:u` events), the runners under `tools/bench/gc/` (`ab.sh` with `--head2`, `profile.sh`, `cleanup.sh`, `oracle.sh`), the Campaign 6 drivers under `traces/llm/bench/` (`ngc-oracle-driver.sh`, `ngc-crc-ab-driver.sh`, `ngc-profile-after-driver.sh`, `ngc-prefixes-raw/build9.sh`).

**Spec:** `traces/llm/specs/2026-11-11-gc-call-boundary-design.md` (section numbers below refer to it). The Campaign 6 spec and plan (`2026-11-09-zig-native-gc-design.md`, `../plans/2026-11-09-zig-native-gc.md`) and its records (`../bench/ngc-*`) are the starting point; `ngc-profile-after.md` is the before-profile of this campaign.

## Global Constraints

- Branch `gc-call-boundary` from `zig-hash-engine` at 67e0c065f (the spec's pointer commit) or later, in the main checkout. **No git worktrees.** Address every repository with `git -C <absolute path>`. Records go in the `traces/llm` submodule under `bench/cb-*`; commit there first, then the pointer commit in MoarVM. Never add `.superpowers/` or `tools/lib/MAST/Ops.rakumod`. No `git stash`, `reset --hard` or `clean`.
- **No decision change, no logic change.** No file under `src/*.c` or `src/**/*.h` changes. In `src/zig/gc/*.zig` and `src/zig/moar.zig` the only permitted edits are: `noinline` on a function definition the audit approves (spec 5), `@import` lines, replacing a `c.MVM_...` call with the Zig function it names, and comments. Every oracle cell (spec 6) is byte-identical.
- **Prefixes** (under `/tmp/claude-1000/`, equal-length names within a comparison): new `cb-n-oracle` (`-Dgc-debug=1`), `cb-n-base` (defaults), `cb-n-stress` (`-Dgc-debug=1 -Dnursery-size=524288`), `cb-n-syms` (`-Dstrip=false`); existing `ng-c-oracle`, `ng-c-base`, `ng-c-stress`, `ng-c-syms`, `ng-n-base`, `ng-n-syms` (present 2026-11-11; if a reboot wiped them, rebuild from the commits in `../bench/ngc-prefixes.md` with `ngc-prefixes-raw/build9.sh`'s recipe before the task that needs them, and record it). Scripts reach a prefix through `LD_LIBRARY_PATH=<P>/lib` with the rakudo and nqp of `/tmp/claude-1000/tune-zig-prefix`.
- **Builds:** `rm -f src/gen/config.h src/gen/config.c src/gen/config.o` before every `zig build`; 1-minute load under 2.0 before every build, test run or benchmark round (poll every 60 s; record the value); everything that can grow under `systemd-run --user --scope -q -p MemoryMax=8G <cmd>`; kill by PID only, never `pkill -f`/`pgrep -f`.
- **Measurement:** interleaved rounds, rotated side order, medians of five runs per round, spreads the min and max of round medians, load recorded before every run, nothing judged from one run. The cycle-share gate (spec 7): allocator row at or below C's plus 0.10 points, collector total within 0.30 points, repeats if within 0.05 of a bound.
- **Gate (spec 7):** any differing oracle cell, a changed export set, a failing unit test, a tripwire crossing (new/C above same-day native/C by more than the C spread, after one seven-round re-run), or a profile gate miss stops the campaign at Task 5: hand back, no merge.
- **Hygiene:** `zig fmt --check src/zig build.zig build/zig tools/zig` clean; `sh -n` on touched shell; test output pristine. Exports: `nm -D --defined-only <P>/lib/libmoar.so | awk '{print $3}' | sort` equal between `cb-n-base` and `ng-c-base` (2850 names).
- **Commit messages:** imperative subject, a body with the reasoning, then the two attribution lines exactly as the dispatching session gives them.

## Review Focus

1. A `noinline` whose C counterpart is itself inlined by the C LTO build: the audit table must show the C-side evidence for every row, not the source file boundary alone (Task 1 Step 5).
2. The import of `markCollectable` into roots.zig creates a roots -> collect -> roots import cycle; Zig permits it, but a `comptime` dependency between the two files would not. `zig build test` and `unit-test -Dgc-debug=1` both compile both files (Task 1 Step 4).
3. `call-boundary.sh` matching the wrong symbol: LTO may clone a function (`.llvm.`-suffixed or numbered names). The script must match the exact `gc.roots.gen2Add`-style name and fail loudly on zero callers found (Task 1 Step 6, the negative test).
4. `allocateStable`/`allocateTypeObject` share the inlines but are not on the crc-getter hot path; the profile cannot see a regression there. The oracle and the unit tests are the only cover, and the audit table records their size change (Task 1 Step 5).
5. The three-sided A/B's head side (`ng-n-base`) is the same binary Campaign 6 measured, so a same-day head/C far from 1.010 means the day is noisy, not the code; Task 3 Step 2 reports head/C beside head2/C and names the C spread before any ratio is read.

---

### Task 1: The change, the audit and the check

**Files:**
- Modify: `src/zig/gc/roots.zig:457` (`pub fn gen2Add` -> `pub noinline fn gen2Add`), `src/zig/gc/roots.zig:501` (`c.MVM_gc_mark_collectable(tc, worklist, col)` -> `collect.markCollectable(tc, worklist, col)`; add `const collect = @import("collect.zig");` beside the imports at lines 17-21)
- Modify: `src/zig/gc/finalize.zig:57` (`pub fn addToQueue` -> `pub noinline fn addToQueue`)
- Modify: `src/zig/gc/gen2.zig:347` (`c.MVM_gc_root_gen2_add(dest, root)` -> `roots.gen2Add(dest, root)`; add `const roots = @import("roots.zig");` beside the imports at lines 14-16)
- Create: `tools/bench/gc/call-boundary.sh`
- Create: `traces/llm/bench/cb-audit.md`, `traces/llm/bench/cb-prefixes.md` (the `cb-n-syms` line; Task 2 adds the rest)

**Interfaces:**
- Produces: `tools/bench/gc/call-boundary.sh LIBDIR` exits 0 when every row of its built-in table (caller symbol, callee symbol) is satisfied by a `call <addr> <callee>` line inside the caller's disassembly of `LIBDIR/libmoar.so`, exits 1 naming the first unsatisfied row, exits 2 if a caller or callee symbol is absent from `nm`. Table rows at minimum: (`gc.allocation.allocateObject`, `gc.roots.gen2Add`), (`gc.allocation.allocateObject`, `gc.finalize.addToQueue`), (`gc.collect.processWorklist`, `gc.roots.gen2Add`), plus every row the audit adds.
- Consumes: the spec's section 5 table definition; `ng-c-syms` for the C side.

- [ ] **Step 1: Branch and record the before-sizes**

```sh
git -C <MoarVM> checkout -b gc-call-boundary zig-hash-engine
nm -S --defined-only /tmp/claude-1000/ng-n-syms/lib/libmoar.so | awk '$4 ~ /^gc\.|^MVM_gc|^moar\./ {printf "%s %d\n",$4,strtonum("0x"$2)}' | sort > <workspace>/sizes-before.txt
nm -S --defined-only /tmp/claude-1000/ng-c-syms/lib/libmoar.so | awk '$4 ~ /^MVM_gc|^gc_|^process_worklist|^add_|^mark_|^pass_|^cleanup_|^finaliz/ {printf "%s %d\n",$4,strtonum("0x"$2)}' | sort > <workspace>/sizes-c.txt
```

Expected: `gc.allocation.allocateObject 786`, `gc.collect.processWorklist 2047` in sizes-before.txt; `MVM_gc_allocate_object 384` in sizes-c.txt.

- [ ] **Step 2: The four edits**

Apply the four modifications listed under Files. Nothing else in those files changes. `zig fmt --check src/zig` clean.

- [ ] **Step 3: Build `cb-n-syms` and compare sizes**

```sh
rm -f src/gen/config.h src/gen/config.c src/gen/config.o
systemd-run --user --scope -q -p MemoryMax=8G zig build install --prefix /tmp/claude-1000/cb-n-syms -Dstrip=false
nm -S --defined-only /tmp/claude-1000/cb-n-syms/lib/libmoar.so | awk '$4 ~ /^gc\.|^MVM_gc|^moar\./ {printf "%s %d\n",$4,strtonum("0x"$2)}' | sort > <workspace>/sizes-after.txt
join <workspace>/sizes-before.txt <workspace>/sizes-after.txt | awk '$2!=$3'
```

Expected: exactly `gc.allocation.allocateObject 786 369`, `gc.allocation.allocateStable 585 344`, `gc.allocation.allocateTypeObject 494 259`, `gc.collect.processWorklist 2047 1568`, plus whatever the two imports do to `gc.gen2.transfer` (a call-target change only, `gen2Add` being `noinline`) and to `gc.roots.addGen2sToWorklist` (LLVM may now inline `markCollectable` into it; that row is the audit's `markCollectable` question in Step 5, with the C side's `MVM_gc_root_add_gen2s_to_worklist` disassembly as the evidence). Any other row is a finding for the audit, not an error. Record the join in cb-audit.md.

- [ ] **Step 4: Tests compile and pass with the import cycle**

```sh
rm -f src/gen/config.h src/gen/config.c src/gen/config.o
systemd-run --user --scope -q -p MemoryMax=8G zig build test
systemd-run --user --scope -q -p MemoryMax=8G zig build unit-test -Dgc-debug=1
```

Expected: 105 of 105 and 66 of 66 (gc-test), as at Campaign 6's close (`../plans/2026-11-09-zig-native-gc.md` Status). Any count change is a stop.

- [ ] **Step 5: The audit**

For every call in `src/zig/gc/*.zig` and `src/zig/moar.zig` from one Zig collector function to another whose C counterpart is a call into a function defined in a different `src/gc/*.c` file (or a `MVM_*` function outside `src/gc`), fill one row of the table in `cb-audit.md`:

| Zig caller | Zig callee | C caller | C callee | Zig inlined? (`objdump -d --disassemble=<caller>` of `cb-n-syms`: callee reached by `call`?) | C inlined? (same, `ng-c-syms`, C names) | callee has alloc/lock/panic/loop? | size Zig/C | action |

Method for the candidate list: `grep -n '^\s*[a-z_]*\.[a-zA-Z]*(\|^\s*[a-zA-Z]*(' src/zig/gc/*.zig` is too wide; instead, for each `pub fn` in the ten files, list its callers with `grep -n '<name>(' src/zig/gc/*.zig src/zig/moar.zig` and keep the cross-file ones. Rows with action `noinline` are allowed only where the C column says "out of line" and the callee column says yes; the two spike sites must appear with that action. Rows where the C inlines, or where the callee is a leaf without allocation, lock, panic path or loop, get action `none`. A row that fits neither is action `ask` and goes in the report's concerns. `markCollectable` (now imported) gets its own row.

Expected: the two spike rows with action `noinline`; `markCollectable` with the C evidence either way; the rest `none` or `ask`.

- [ ] **Step 6: Write `tools/bench/gc/call-boundary.sh` and its negative test**

Header comment: purpose, usage `call-boundary.sh LIBDIR`, exit codes as in Interfaces, the table. Implementation: for each row, `nm --defined-only LIBDIR/libmoar.so` must list both symbols (else exit 2); `objdump -d --no-show-raw-insn --disassemble=<caller> LIBDIR/libmoar.so | grep -c 'call .*<<callee>>'` must be at least 1 (else exit 1, printing the row). Then:

```sh
sh -n tools/bench/gc/call-boundary.sh
tools/bench/gc/call-boundary.sh /tmp/claude-1000/cb-n-syms/lib; echo "exit $?"
tools/bench/gc/call-boundary.sh /tmp/claude-1000/ng-n-syms/lib; echo "exit $?"
```

Expected: `exit 0` on `cb-n-syms`; `exit 1` on `ng-n-syms` naming the `allocateObject -> gen2Add` row (the Campaign 6 binary inlines it: this is the negative test, recorded in cb-audit.md).

- [ ] **Step 7: Commit**

MoarVM: `git add src/zig/gc/roots.zig src/zig/gc/finalize.zig src/zig/gc/gen2.zig tools/bench/gc/call-boundary.sh` then commit "GC: keep gen2Add and addToQueue out of line as the C does". Body: the rule (spec 5), the size table, the two imports. Traces: `cb-audit.md`, `cb-prefixes.md` ("cb: call-boundary audit"), then the pointer commit in MoarVM. Report: `## Reading notes` section with anything the audit made visible.

---

### Task 2: Prefixes, oracle, unit tests, exports

**Files:**
- Create: `traces/llm/bench/cb-oracle.md`, `traces/llm/bench/cb-oracle-driver.sh` (copy of `ngc-oracle-driver.sh` re-pointed: group a = `ng-c-oracle` vs `cb-n-oracle`, stress tier `ng-c-stress` vs `cb-n-stress`; groups b and c dropped), `traces/llm/bench/cb-prefixes-raw/build.sh` (build9.sh's recipe with the list `cb-n-oracle -Dgc-debug=1`, `cb-n-base`, `cb-n-stress -Dgc-debug=1 -Dnursery-size=524288`)
- Modify: `traces/llm/bench/cb-prefixes.md` (the three new lines with commit, options, build time, load, `moar --version`)

**Interfaces:**
- Consumes: Task 1's branch tip.
- Produces: the three prefixes; `cb-oracle.md` with the 8-cell table (one group: two volumes x two settings x two tiers, 16 logs, as `ngc-oracle-driver.sh` lays a group out).

- [ ] **Step 1: Build the three prefixes** with `cb-prefixes-raw/build.sh`; expected three `exit 0` lines in its builds.tsv; `/tmp/claude-1000/cb-n-base/bin/moar --version` prints the version.

- [ ] **Step 2: Exports**

```sh
diff <(nm -D --defined-only /tmp/claude-1000/cb-n-base/lib/libmoar.so | awk '{print $3}' | sort) <(nm -D --defined-only /tmp/claude-1000/ng-c-base/lib/libmoar.so | awk '{print $3}' | sort) && echo same
nm -D --defined-only /tmp/claude-1000/cb-n-base/lib/libmoar.so | wc -l
```

Expected: `same`, 2850.

- [ ] **Step 3: The oracle**

```sh
systemd-run --user --scope -q -p MemoryMax=8G sh traces/llm/bench/cb-oracle-driver.sh /tmp/claude-1000/cb/oracle
```

Expected: every row of matrix.tsv `exit 0` and `raw_cmp same`. One differing cell: stop, report `BLOCKED` with the cell and both logs' first differing line.

- [ ] **Step 4: Unit tests again on the branch tip** (as Task 1 Step 4, in case Task 1's fix round touched a file): 105 of 105, 66 of 66.

- [ ] **Step 5: Commit** traces (`cb-oracle.md`, driver, prefixes; "cb: prefixes and oracle"), pointer in MoarVM.

---

### Task 3: A/B, after-profile, cleanup, records, docs

**Files:**
- Create: `traces/llm/bench/cb-crc-ab.md`, `cb-crc-ab-driver.sh` (`ngc-crc-ab-driver.sh` re-pointed: `--base=ng-c-base --head=ng-n-base --head2=cb-n-base`), `cb-profile.md`, `cb-profile-driver.sh` (`ngc-profile-after-driver.sh` re-pointed: c = `ng-c-syms`, n = `cb-n-syms`; the `nlto` pass dropped), `cb-cleanup.md`
- Modify: `docs/zig-build.md` (under `### Native shapes`, line 451 onwards: one paragraph "Call-boundary parity" with the rule, the two sites, and `tools/bench/gc/call-boundary.sh`), `traces/llm/specs/2026-11-11-gc-call-boundary-design.md` (Errata), this plan (Outcome, Status), `traces/llm/bench/ngc-ledger.md` (one line under the deferred follow-ups pointing at `cb-*` for the two items this campaign closes: the imports, the allocator shape)

**Interfaces:**
- Consumes: the prefixes of Task 2; Campaign 6's `ngc-profile-after.md` alignment table (its "Before and after, per symbol" section) for the collector-row alignment.
- Produces: the gate verdict and the aim result, in `cb-profile.md` and `cb-crc-ab.md`.

- [ ] **Step 1: The three-sided A/B**, both settings, seven rounds of five, through `cb-crc-ab-driver.sh` into `/tmp/claude-1000/cb/crc`. Expected: 210 runs exit 0 per the driver's runs.log. Record in `cb-crc-ab.md`: the two summary tables; head/C and head2/C for wall and RSS on both settings; the C spread (max minus min of C round medians over the C median) beside each; the tripwire verdict (head2/C minus head/C against the spread) and the aim verdict (head2/C inside the spread or at most 1.00), each stated as pass or miss in those words.

- [ ] **Step 2: The after-profile**, both settings, through `cb-profile-driver.sh` into `/tmp/claude-1000/cb/profile`. Expected: six `exit 0` per setting in driver.log. Record in `cb-profile.md`: the `.text` check of `cb-n-syms` against `cb-n-base` (spec 7, Campaign 6's method); counter medians and ratios; the per-symbol table aligned as `ngc-profile-after.md` aligns it; the allocator row and the collector total against the C's with the gate bounds (0.10 and 0.30 points) and the verdict; if a number is within 0.05 of its bound, two more `--record` runs per side and medians. End with the finding paragraph: what share of the remaining total-cycle gap lies in the collector, in the spec 7 words if it is unresolvable.

- [ ] **Step 3: Cleanup and stress**

```sh
systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/cleanup.sh --prefix=/tmp/claude-1000/cb-n-base --runs=20
systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/cleanup.sh --prefix=/tmp/claude-1000/cb-n-stress --runs=20 --stress
```

Expected: 60 of 60 each; record in `cb-cleanup.md`.

- [ ] **Step 4: `call-boundary.sh` on the shipped-shape build**: `tools/bench/gc/call-boundary.sh /tmp/claude-1000/cb-n-syms/lib` exit 0 (already true at Task 1; repeated here because this is the acceptance driver's place for it, and `cb-crc-ab-driver.sh` runs `tools/bench/gc/call-boundary.sh /tmp/claude-1000/cb-n-syms/lib` first and refuses to start on non-zero).

- [ ] **Step 5: Docs, Errata, Outcome, ledger pointer** as listed under Files. The Outcome table below is filled with the numbers of Steps 1 to 3.

- [ ] **Step 6: Commit** traces ("cb: acceptance records"), MoarVM ("GC: call-boundary docs" and the pointer).

---

### Task 4: Final whole-branch review

Dispatch per `superpowers:requesting-code-review` on the most capable model: the whole branch against `zig-hash-engine`, the spec and this plan, with the audit table, `cb-profile.md` and `cb-crc-ab.md` as the evidence to check. One fix wave at most, one scoped re-review. The review confirms independently: no file under `src/*.c`/`src/**/*.h` changed; the only Zig edits are the permitted kinds (Global Constraints); the export set; `call-boundary.sh` exit 0 on `cb-n-syms` and 1 on `ng-n-syms`; the gate arithmetic in `cb-profile.md`.

### Task 5: Inclusion

With every gate passed (Global Constraints) and the review clean: in the main checkout, `git -C <MoarVM> checkout zig-hash-engine && git -C <MoarVM> merge --ff-only gc-call-boundary`; verify both branches name the same tip and `git status` shows only the two untracked paths. Nothing is pushed. Preserve the ledger and the review as `traces/llm/bench/cb-ledger.md` and `cb-final-review.md` (Campaign 6's precedent) before the merge, with their pointer commit. If any gate failed or the review is not clean after its fix wave: do not merge; hand back with the Outcome table and the ledger.

## Outcome (filled at Task 3)

| check | result |
|---|---|
| sizes (allocateObject / processWorklist, bytes, before -> after, C) | |
| audit rows (noinline / none / ask) | |
| `call-boundary.sh` (cb-n-syms / ng-n-syms exit) | |
| oracle cells identical | |
| unit tests (test / gc-test) | |
| exports | |
| crc-getter head2/C wall / RSS, plain; C spread | |
| crc-getter head2/C wall / RSS, bad; C spread | |
| same-day head/C (Campaign 6 binary), plain / bad | |
| tripwire | |
| aim (4 of 4) | |
| profile: allocator row cb vs C (points); collector total cb vs C (points); gate | |
| cycles cb/C, plain / bad | |
| cleanup (base / stress) | |

## Deviations

Filled at Task 3.
