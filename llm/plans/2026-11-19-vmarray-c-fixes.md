# The C bugs the VMArray port found: fixes and upstream PRs

Date: 2026-11-19. Asked for by the user after campaign 8 (`2026-11-16-zig-vmarray-repr.md`, Outcome, "For the
user" item 2): "go and fix all of those bugs and create individual PRs per area of concern". The same day the
user accepted memmove semantics for the overlapping self-splice and had `zig-vmarray` merged into
`zig-hash-engine` (fast-forward, df104d5ac).

There is no separate spec: this plan is the requirement, the bug list of campaign 8 is its input, and the GC
interlude of campaign 4 (branch `gc-fixes-from-zig-port`, PRs MoarVM/MoarVM#2069-#2074) is the precedent for
how it is done: C fixes on clean branches off `origin/main`, upstream PRs from the fork, then the fixes
mirrored in the Zig port.

## Goal

Every bug on the list is either (a) reproduced on unmodified `origin/main`, fixed in C on a branch of its
area, shown fixed by the same reproducer, and offered upstream as one PR per area; or (b) shown by evidence
not to be a bug, or not fixable without a design decision, and reported to the user as such with no PR.
Afterwards the Zig array carries the same fixes.

## Global Constraints

- **No git worktrees, ever.** Work in the main checkout `P = /home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM`,
  one branch checked out at a time. No `git stash`, `reset --hard`, `clean`. Never add `.superpowers/` or
  `tools/lib/MAST/Ops.rakumod`. Never `pkill -f` / `pgrep -f`; kill by PID.
- **Nothing is pushed and no PR is opened by a subagent.** The controller pushes and opens PRs after each
  area's review. Subagents never touch remotes.
- Fix branches start at `origin/main` **f112c3998** and contain C only: no Zig, no `traces` pointer, no build
  changes. One commit per bug unless two bugs are one defect. A branch's diff is the smallest that fixes its
  bugs: no refactoring, no reformatting, no drive-by fixes (a second bug seen on the way is reported, not
  fixed, unless it is on this plan's list for that branch).
- Each fix branch is independent of the others (each applies to `origin/main` alone). Where two areas touch
  adjacent lines of `VMArray.c`, keep the hunks apart if that costs nothing; say so in the report if not.
- Commit style: upstream's, as in a27bfbd80: an imperative subject without a prefix, a body that says what was
  wrong, how it is reached, what the fix does, and how it was found ("Found while porting the VMArray REPR to
  Zig"). Author is the repo's configured identity (do not change it). Trailer: the harness's standard
  `Co-Authored-By` line.
- **A fix changes behaviour only where the old behaviour was a crash, memory corruption, undefined behaviour,
  or a wrong result nobody could rely on.** Where a fix has to choose a new defined behaviour (throw? clamp?),
  choose what the neighbouring code already does for the nearest similar case, say so in the commit body, and
  flag it in the report: the maintainers may want another choice.
- Evidence for every bug: a minimal reproducer (an nqp or Raku program, or a C-level argument where no
  program can reach it on this machine), its output on unmodified `origin/main` (plain build and
  AddressSanitizer build where memory is involved), and its output on the fix branch. "Found by reading, not
  reproduced" is an allowed outcome and must be stated as such, in the report and in the PR text.
- No regressions: `make test` in nqp, and rakudo's `make test`, give the same verdicts under the fixed moar as
  under unmodified `origin/main` (same nqp and rakudo sources for both).
- Machine: 32 GB, no swap. Builds and test runs under `systemd-run --user --scope -q -p MemoryMax=8G`
  (`MemoryMax=24G` for anything with 24 jobs); 1-minute load < 2.0 before a build or a test run. Reproducers
  that allocate a lot run under an explicit `MemoryMax` and `timeout`. Core dumps off (`ulimit -c 0`) for
  runs expected to crash. zsh: quote globs.
- Prefixes under `/tmp/claude-1000/`, names `cfix-*`. The `va-*` and `tune-zig-prefix` prefixes are not
  touched. The nqp and rakudo checkouts (`P/..`, `P/../..`) end every task with an empty `git status --short`
  (build in copies, as campaign 8's whole-system check did: `traces/llm/bench/va-whole-system.md`).
- Records in `traces/llm/bench/cfix-*` (committed in `traces` on its `main`; the pointer is updated only on
  `zig-hash-engine`, by the controller). Reproducers live in `traces/llm/bench/cfix-repro/`.
- The user's email address never appears in anything pushed or sent anywhere.

## The bugs

Line numbers are `origin/main`'s (the C files are identical to `zig-hash-engine`'s). "Driven" says whether
campaign 8 ran it or only read it. Sources: `traces/llm/bench/va-differential.md` sections 4-6,
`va-adoption-audit.md` section 3, `va-kind-differences.md`, and the Outcome of the campaign 8 plan.

| id | area (branch) | bug | driven |
|---|---|---|---|
| S1 | self-splice (`vmarray-self-splice-memmove`) | `copy_elements`/`asplice` use `memcpy` where source and target ranges of the same array overlap: undefined behaviour, and wrong results with this libc (195 lines of the differential) | yes |
| G1 | growth (`vmarray-size-overflow`) | `set_size_internal`: growth to 2**64 - 4096 or more on an array with 8,192+ slots wraps the rounded size to a 0-byte realloc, then a crash | read |
| G2 | growth | a size at or just under the limit panics in malloc: the limit check is `>` | read |
| P1 | splice sources (`vmarray-splice-guards`) | a splice from a non-empty object that is not a VMArray dereferences NULL REPR data | read |
| P2 | splice sources | a splice copying into or out of a kind without storage (the six 1/2/4-bit kinds) reaches `abort()` | read |
| P3 | splice sources | a splice between a reference kind and a numeric kind reinterprets bits (pointers as numbers, numbers as pointers the collector then follows) | read |
| T1 | stale slots (`vmarray-stale-slots`) | an OBJ/STR array: a rejected `pop` (wrong register kind) has already decremented `elems`; growing back over the slot resurrects a pointer the collector stopped tracking | read |
| T2 | stale slots | the same for a rejected `unshift` after a `shift` (`start` already decremented) | read |
| T3 | stale slots | a self-splice at offset 0 with `start > 0` resurrects pointers in the same way | read |
| B1 | buffers (`vmarray-buf-bounds`) | `read_buf` whose bounds check passes can read past the storage when `start > 0` | read |
| B2 | buffers | `write_buf`/`read_buf`: `offset * elem_size` wraps for offsets >= 2**62 (4-byte kinds) / 2**61 (8-byte kinds); the bounds check passes and the copy lands at the aliased position | read |
| B3 | buffers | `writeint` on an array recomposed to a kind without storage writes into the old storage | read |
| M1 | mark (`vmarray-mark-presize`) | `VMArray_gc_mark` passes `elems` (64-bit) as `MVM_gc_worklist_presize_for`'s `MVMint32` count; once `items + elems` reaches 2**32 the list is presized short and the unchecked adds write past it | read; needs ~32 GiB of slots |
| R1 | recompose (`vmarray-recompose`) | composing an array type a second time ignores an object element type | read |
| N1 | normalizer (`normalize-array-result`) | `normalize.c:90` stores a byte count as `ssize` (about 4x the allocation): a later push/bindpos/setelems below `ssize` writes past the buffer | read |
| N2 | normalizer | `normalize.c:200-203` overwrites `out`'s slots without freeing them | read |
| O1 | process output (`procops-buf-type`) | `procops.c:686` adopts a byte buffer into `buf_type` without checking that it is a VMArray of 1-byte elements | read |
| E1 | encode append (`encode-append-offset`) | `src/strings/ops.c:1910`: the append branch offsets by `prev_elems` bytes, ignoring `start` and the element size, and truncates `elems` to 32 bits | read |
| D1 | deserialization (`serialization-root-array-var`) | `serialization.c:1806-1817` `read_array_var` may not root `result` across `MVM_serialization_read_ref` | not verified |

Area names and the grouping are the controller's; Task 1 may propose merging or splitting areas where the
code shows two bugs are one defect or one area is two.

---

### Task 1: Baseline builds and a reproducer for every bug

**Files:** `traces/llm/bench/cfix-repro/*`, `traces/llm/bench/cfix-baseline.md`, `traces/llm/bench/cfix-baseline-raw/`

- [ ] **Step 1: Baseline prefixes of unmodified `origin/main` f112c3998**, built with upstream's own build
  (`perl Configure.pl --prefix=... && make install`; this branch has no Zig build): `cfix-base` (default
  options) and `cfix-asan` (`--asan`, or the flags Configure.pl offers for AddressSanitizer; read
  `Configure.pl --help`). Check out `origin/main` as a local branch `cfix-baseline` to build; return the
  checkout to `zig-hash-engine` at the end of the task. An nqp that runs on these: build nqp from a copy of
  the nqp checkout against a copy of `cfix-base` (campaign 8's `va-whole-system-raw/build-nqp.sh` shows how),
  or show that the existing `/tmp/claude-1000/tune-zig-prefix/share/nqp/lib/nqp.moarvm` loads under
  `cfix-base/bin/moar` and use that. A Rakudo for the reproducers that need Raku-level types (native arrays,
  `Buf`, `Proc`, `NFC`): build from a copy of the rakudo checkout the same way, or show the existing one
  runs. Record exactly what runs under what, and probe which `libmoar` each run loads.
- [ ] **Step 2: For each bug in the table, the smallest program that reaches it** (nqp ops preferred; Raku
  where the op is only reachable there), kept as `cfix-repro/<id>-<slug>.{nqp,raku}` with a header comment:
  what it does, what a correct VM would print, what the bug prints or how it dies. Read the C to derive each
  one; the campaign 8 records say where each was seen. Run each on `cfix-base` and `cfix-asan` (bounded
  memory and time, no core dumps) and keep the outputs.
- [ ] **Step 3: Classify every bug** in `cfix-baseline.md`, one row each: **reproduced** (the program and the
  failing output, or the ASAN report's first frames), **not reachable here** (the argument from the code, and
  what machine would show it), **not a bug** (the evidence), or **needs a decision** (what the options are).
  For D1, follow the code far enough to say whether a collection can move `result` there (which allocation
  default deserialization runs under, whether `read_ref` can trigger a nursery collection); do not guess.
  For O1 and N1/N2/E1, find which nqp/Raku-level operations reach the site at all, and with what types.
- [ ] **Step 4: Propose the final areas** (confirm or amend the table's grouping, with the reason), and for
  each bug the fix you would make and the behaviour it defines, in two or three sentences, without writing it.
- [ ] **Step 5: Baseline suites**: nqp `make test` and rakudo `make test` under `cfix-base`, per-file verdict
  lists kept (the later tasks compare against them).

No fix is written in this task. Commit the records in `traces` (no pointer update).

### Task 2: Fix area S (self-splice) and area G (growth)

Two branches off f112c3998, each per the Global Constraints: fix, rebuild plain and ASAN prefixes
(`cfix-<area>` / `cfix-<area>-asan`), run the area's reproducers and show them flip, run every other
reproducer of `cfix-repro/` to show nothing else changed, nqp and rakudo `make test` against Task 1's lists.
For S, also run campaign 8's differential (`tools/bench/repr/` lives on `zig-hash-engine`, so copy the
programs out before switching branches) between `cfix-base` and the fixed build. (Amended after Task 1:
the plain upstream build already prints the memmove result on the fast path with this glibc, so) the only
differing lines may be self-splice lines of the element-by-element path, each now equal to the memmove model;
the fast path's evidence is the AddressSanitizer run of the S reproducers going clean. Area S also carries T3
and makes the element-by-element path overlap-safe for a self-splice (controller's ruling, ledger). Write `cfix-<area>.md` per
area with the evidence and a draft PR text (title, body in the style of #2069: what is wrong, how it is
reached, what the fix does and what behaviour it defines, the reproducer inline, how it was found).

### Task 3: Fix area P (splice sources) and area T (stale slots)

As Task 2. These define new behaviour (what a splice from a non-array, to or from a kind without storage, or
across reference and numeric kinds should do): follow the Global Constraint on choosing it, and put the
choice first in the draft PR text.

### Task 4: Fix area B (buffers), area M (mark) and area R (recompose)

As Task 2. M cannot be reproduced on this machine: the report and the draft PR text say so and give the
arithmetic.

### Task 5: Fix areas N, E, O and D (outside `VMArray.c`)

As Task 2, for whichever of these Task 1 classified as bugs. D only if Task 1 showed a collection can happen
there.

### Task 6: Mirror the fixes in the Zig port

Branch `zig-vmarray-c-fixes` off `zig-hash-engine`. Cherry-pick each C fix commit (the C array stays the
control under `-Dzig-reprs=false`), and make the Zig array (`src/zig/6model/reprs/vmarray/*`) behave as the
fixed C, one commit per area, with unit tests. Where the Zig already differed on purpose (memmove on
self-splice, NULL for kinds without storage), reconcile: after S the differential's undefined-lines list
should be empty and `diff.sh` should exit 0; update `tools/bench/repr/` accordingly (the cases campaign 8
left out because the C crashed can now be driven: add them). Gate: unit tests on both switch settings,
exports equal, `diff.sh` exit 0, serialization identical, nqp and rakudo `make test` same verdicts on both
settings, the reproducers of `cfix-repro/` give the fixed outputs on both. Records `cfix-mirror.md`.
The adoption sites outside the array (N, E, O) stay C: only the cherry-picks.

### Task 7: Final review and hand-back (controller)

Whole-set review of the fix branches and the mirror; one fix wave; preserve the ledger as
`traces/llm/bench/cfix-ledger.md`; report to the user: the PR list, what was not fixed and why, the
decisions the maintainers may want to revisit. The mirror branch is handed back unmerged.

## Outcome

(filled at the end)
