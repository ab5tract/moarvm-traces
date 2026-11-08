# Zig 0.17 Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build, test and ship MoarVM's Zig build graph, generators and ports on Zig 0.17.1 with no behaviour change, and re-baseline every performance record on the new toolchain so the next campaign (the Zig-native GC) starts from a clean 0.17 pair.

**Architecture:** Four layers break in turn and are fixed in turn: the build graph (`build.zig`, `build/zig/`), the translate-c step (the std step is deprecated; the `translate_c` package replaces it), the ports and their tests (`src/zig/`), and the verification harness (`zig build test`, the Perl `--zig` path, the bench tools). Then the C and Zig prefixes are rebuilt on 0.17 next to the surviving 0.16 prefixes, and one toolchain A/B separates the compiler's own drift (clang 22.1.8, the new Zig backend) from anything the migration changed.

**Tech Stack:** Zig 0.17.1 (`/usr/bin/zig`); Zig 0.16.0 for controls only (`/home/longwalker/code/raku/x.core/zmoarz/zig/zig-x86_64-linux-0.16.0/zig`, never on PATH); the `translate_c` package (codeberg.org/ziglang/translate-c, branch `zig-0.17.x`); C (untouched); Perl, sh, Python for the existing runners.

**Spec:** There is no separate design document. The decision record is the user's instruction on 2026-11-08 ("migration first, then the gc campaign"; 0.17.1 installed by the user; 0.16.0 made available for controls), the Zig 0.17.0 release notes (https://ziglang.org/download/0.17.0/release-notes.html), and the "Rulings made while planning" below. The recon that produced this plan is in `.superpowers/sdd/2026-11-08-zig-017-migration/recon.md` in the MoarVM checkout (scratch, not committed).

## Global Constraints

- MoarVM work on branch `zig-017` from `zig-hash-engine` (7ec451d5b), in the main checkout. **No git worktrees.** Address every repository with `git -C <absolute path>`; never rely on `cd` carrying between commands. Records go in the `traces/llm` submodule under `bench/z017-*`; commit there first, then the pointer commit in MoarVM.
- **No behaviour change.** No file under `src/*.c`, `src/**/*.h` (other than `src/zig/moar_c.h`) or `build/sources.list` changes. The oracle must be byte-identical between the 0.17 C collector and the 0.17 Zig collector, and between the 0.16 C collector (`/tmp/claude-1000/gc-c-oracle`) and the 0.17 C collector. Every test suite must produce the same list of test names and the same pass/skip verdicts as the 0.16 build of the parent commit.
- **Deprecated-API policy:** every API the 0.17.0 release notes list as deprecated or renamed is replaced by its new form, even when the old name still compiles (the point of the migration is that 0.18 does not break the tree again). The only exception is `std.builtin.OptimizeMode` in the `translate_c` package's own option type, which is not ours.
- Builds: `rm -f src/gen/config.h src/gen/config.c src/gen/config.o` before any `zig build` without `-Dconfig-h`; 1-minute load under 2.0 before every build, test run or benchmark round (poll every 60 s; record the value); anything that can grow runs under `systemd-run --user --scope -q -p MemoryMax=8G <cmd>` (32 GB machine, no swap, no oomd); kill by PID only, never `pkill -f`/`pgrep -f`.
- Prefix names in an A/B pair must have equal length (the install path is baked into libmoar's config strings and changes allocation sizes): the 0.17 prefixes are `/tmp/claude-1000/g7-c-oracle`, `g7-z-oracle`, `g7-c-base`, `g7-z-base`, `g7-c-stress`, `g7-z-stress` (compare with each other), and the surviving 0.16 prefixes `gc-c-oracle`, `gc-c-base`, `gc-z-base`, `gc-c-stress`, `gc-z-stress` (compare `gc-c-*` with `gc-z-*`, and `gc-?-oracle` logs with `z17-?-oracle` logs, which the oracle filters by content, not path).
- Measurement conventions as in the GC plan: interleaved rounds, rotated variant order, medians of at least five runs per round, spreads are min and max of round medians, load recorded before every run; spectest recipe `TEST_JOBS=24 python3 <MoarVM>/tools/bench/timev.py <out>.time make -o spectest_update spectest` in the rakudo checkout with roast pinned at fb1d87214 and `.precomp` removed before each run; `MVM_SPESH_BLOCKING`/`MVM_SPESH_DISABLE` untouched.
- `zig fmt --check src/zig build.zig build/zig tools/zig` clean after every task (0.17's formatter); `perl -c` on touched Perl, `sh -n` on touched shell; test output pristine.
- Commit messages: imperative subject, body with the reasoning, then the two attribution lines exactly as the dispatching session gives them.

## Rulings made while planning

- **translate-c moves to the package.** `std.Build.Step.TranslateC` still exists in 0.17 but is deprecated for removal in 0.18. `build.zig.zon` gains the dependency `translate_c` pinned to the `zig-0.17.x` branch of codeberg.org/ziglang/translate-c (fetched once into the global cache; a first build on a fresh machine needs the network once, which `docs/zig-build.md` must say). The deprecated step is the fallback only if the package cannot translate `src/zig/moar_c.h` at all; that fallback is recorded in the ledger and the plan's Deviations, and the decision is revisited at 0.18.
- **The fixup pass survives only if it still fires.** `build/zig/fixup_translated.zig` repairs a translate-c 0.16 rendering of `x++` on narrow integers. Task 2 counts the lines the new translator produces that match; if the count is zero, the executable, its run step and its docs paragraph are deleted in that task (dead code is not kept "just in case"). If it is nonzero, the tool stays and its header comment names the translator version.
- **One formatting commit.** 0.17's `zig fmt` may reformat lines (it already rejects `{0} ** n` spacing). Formatting-only changes land in one commit per task ("zig fmt 0.17") before the semantic commit, so reviewers can diff semantics alone.
- **The 0.16 toolchain has exactly two jobs**: producing the reference list of unit-test names and verdicts from the parent commit (Task 3), and building nothing new. The 0.16 prefixes in /tmp are the toolchain-control artefacts; if they are gone (reboot), the control build recipe is the GC plan's Task 10 recipe with the 0.16 binary, and the plan says so rather than rebuilding them pre-emptively.
- **Performance is recorded, not gated.** The migration has one gate, no behaviour change. The crc-getter and spectest numbers it produces are the new baseline for the Zig-native GC campaign, and the toolchain A/B exists so that baseline can be read: C17/C16 is the compiler's doing, Z17/C17 is the port's standing on the new toolchain. A Z17/C17 ratio worse than 1.03 on either metric is a stop-and-report, since nothing in this plan should move it.
- **`b.root` replaces `b.build_root`** (now a `std.Build.Cache.Path` with `access`, `openFile`, `openDir`, `statFile` but no `readFileAlloc`). One helper, `readRootFile(b, sub_path) ?[]u8`, in a new `build/zig/root_files.zig`, serves the five read sites; the two `access` sites call `b.root.access(b.graph.io, …)` directly.
- **Reference counts to reproduce** (from `traces/llm/bench/gc-final-suites.md` plus the mirror round): `zig build test` 81/81 steps at `-Dgc-debug=0` and `1`; all-C `zig build test -Dzig-impl=false` 67/67; `strategy-test` success; `prove tools/bench/t/` 6 files 107 tests. Unit-test totals are taken from the 0.16 reference run in Task 3, not from these notes.

## Review Focus

- A translated `src/moar.h` whose static inline functions are no longer emitted as bodies (the package's `func_bodies` and `pub_static` defaults) would make the ports' `c.MVM_*` inline calls fail to compile, or worse, resolve to a different symbol: Task 2 pins it with the existing C layout probe (`zig build unit-test` compiles the probe) and Task 3 with the full unit-test list.
- A silently inert fixup pass (translator fixed the bug, the tool matches nothing) hides a dead build step: Task 2 counts matches and deletes the tool on zero.
- `{0} ** n` rewritten with the wrong array type (`@splat` needs the result type) changes a buffer size without a compile error when the surrounding code is generic: Task 3 keeps every site's type explicit and the unit tests that touch those buffers (hash tier tests) must pass with the same counts.
- The per-collection log, written by C `debug.c` and read by the oracle, could change format if clang 22 changes `%p`/`%zu` rendering: Task 5's 0.16-C versus 0.17-C oracle cell pins it.
- The GC unit tests that spawn threads and wait up to 5 s (`std.Thread.spawn`, `std.Io.Clock.awake.now`) could hang rather than fail under a changed Io: Task 3 runs the gc-test binary under `timeout 300` and records the wall time per run.

---

### Task 1: Build graph configures on 0.17

**Files:**
- Modify: `build.zig` (lines 20, 90: `build_root.handle.access`), `build/zig/options.zig:78` (optimize mode), `build/zig/config.zig:233`, `build/zig/sources.zig:162`, `build/zig/version.zig:41-49`, `build/zig/zigimpl.zig:114`, `build/zig/thirdparty.zig:147` (root reads), every `std.builtin.` in `build/zig/*.zig`, the `b.args` passthrough (`build/zig/moar.zig` or wherever `if (b.args) |args|` sits), `build.zig.zon` (`minimum_zig_version = "0.17.0"`).
- Create: `build/zig/root_files.zig`.
- Create (scratch, orchestrator): `.superpowers/sdd/2026-11-08-zig-017/progress.md`.

**Interfaces:**
- Produces: `pub fn readRootFile(b: *std.Build, sub_path: []const u8) ?[]u8` in `build/zig/root_files.zig` (returns null when the file is absent; any other error is fatal through `std.process.fatal` with the path in the message, as the current call sites do); `pub fn rootExists(b: *std.Build, sub_path: []const u8) bool`.
- Produces: `build/zig/options.zig` exposes `optimize: std.lang.Optimize` with default `.fast`; every comparison uses `.debug`/`.fast`.

- [ ] **Step 0: Reference run with 0.16 on the untouched tree**

Before any edit, with `Z16=/home/longwalker/code/raku/x.core/zmoarz/zig/zig-x86_64-linux-0.16.0/zig` and `rm -f src/gen/config.*` done: `timeout 600 $Z16 build unit-test --summary all 2>&1 | tee /tmp/claude-1000/z017/unit-016-g0.txt | tail -3`, the same with `-Dgc-debug=1` into `unit-016-g1.txt`, and `$Z16 build zig-objects` followed by `nm -g --defined-only <the object zigimpl.zig emits; its path is in build/zig/zigimpl.zig> | awk '{print $3}' | grep '^MVM_' | sort > /tmp/claude-1000/z017/exports-016.txt`. Record the two totals, the gc-test counts and the export count in the ledger. Tasks 3 and 4 compare against these files.

- [ ] **Step 1: Create the branch and record the parent**

Run: `git -C <MoarVM> checkout -b zig-017 zig-hash-engine && git -C <MoarVM> rev-parse --short HEAD` and write the hash into the ledger as "parent".

- [ ] **Step 2: Capture the 0.17 configure errors as the task's failing test**

Run: `rm -f src/gen/config.h src/gen/config.c src/gen/config.o; zig build --help 2>&1 | tee /tmp/claude-1000/z017/step1-before.txt | grep -c "error:"`
Expected: at least 2 (the `build_root` and `ReleaseFast` errors); save the file.

- [ ] **Step 3: Implement `root_files.zig` and switch the seven `build_root` sites**

`readRootFile` opens `b.root.openFile(b.graph.io, sub_path, .{})` and reads to end with `b.allocator` (`.unlimited`); `rootExists` is `b.root.access(b.graph.io, sub_path, .{})` mapped to bool. `version.zig:49` passes `b.root.sub_path` (or the joined string via `b.root.joinString`) where it passed `build_root.path`.

- [ ] **Step 4: Rename the optimize mode and the remaining deprecated Build APIs in build files**

`std.builtin.OptimizeMode` to `std.lang.Optimize`, literals `.ReleaseFast`/`.Debug` to `.fast`/`.debug` (grep `OptimizeMode|ReleaseFast|ReleaseSafe|ReleaseSmall|\.Debug\b` across `build.zig build/zig`, 20 sites in 9 files, some in `src/zig` handled in Task 3); `if (b.args) |args| run.addArgs(args)` to `run.addPassthruArgs()`; `addFileArg`/`addOutputFileArg`/`addPrefixedFileArg` to the `…2` forms with `PathArgOptions` (14 + 4 sites); `std.builtin.` to `std.lang.` in build files.

- [ ] **Step 5: Verify the graph configures and the all-C build installs**

Run: `zig build --help 2>&1 | grep -E "^\s+(check-jit-tools|config-h|hash-bench|strategy-test|test|thirdparty|uni-bench|unit-test|version|zig-objects)\s" | wc -l`
Expected: 10 (the step list as before; `hash-bench-exe` and `uni-bench-exe` make 12 with the exe variants).
Run: `zig build version` — prints the same `2026.09-…` string as `git describe --tags --match=20*`.
Run: `systemd-run --user --scope -q -p MemoryMax=8G zig build install -Dzig-impl=false --prefix /tmp/claude-1000/z017/c-smoke && /tmp/claude-1000/z017/c-smoke/bin/moar --version`
Expected: a version line; then `…/moar --libpath=/tmp/claude-1000/tune-zig-prefix/share/nqp/lib /tmp/claude-1000/tune-zig-prefix/share/nqp/lib/nqp.moarvm -e 'say(42)'` prints 42.

- [ ] **Step 6: Format, then commit twice**

Run: `zig fmt build.zig build/zig` (commit "zig fmt 0.17: build graph" if it changed anything), then commit the semantic change: "Build on Zig 0.17: root paths, optimize names, run-step passthrough".

### Task 2: translate-c through the `translate_c` package

**Files:**
- Modify: `build.zig.zon` (dependency), `build/zig/zigimpl.zig:11,39-66` (the translate step and the fixup run), `build/zig/fixup_translated.zig` (header comment or deletion), `docs/zig-build.md:85-122` ("## Zig implementations": the translate paragraph and the fixup paragraph).

**Interfaces:**
- Consumes: `opts.target: std.Build.ResolvedTarget`, `opts.optimize`, `moar.include_paths`, `moar.system_include_paths`, `moar.defines(b, opts)` as zigimpl.zig uses them today.
- Produces: `ZigImpl.translated: std.Build.LazyPath` (the translated file, pre-fixup) and `ZigImpl.c_mod: *std.Build.Module` unchanged in name and role, so Tasks 3-4 need no change.

- [ ] **Step 1: Add the dependency**

Run: `zig fetch --save=translate_c "git+https://codeberg.org/ziglang/translate-c#zig-0.17.x"` in the MoarVM checkout. Expected: `build.zig.zon` gains `.translate_c = .{ .url = …, .hash = … }`; record the resolved commit in the ledger.

- [ ] **Step 2: Replace the step**

In `zigimpl.zig`: `const dep = b.dependency("translate_c", .{});` then `const t: Translator = .init(dep, .{ .c_source_file = b.path("src/zig/moar_c.h"), .target = opts.target, .optimize = opts.optimize, .link_libc = true });` with `Translator = @import("translate_c").Translator`; the config header via `t.addConfigHeader(h)` or `t.addIncludePath(dir)` as the `switch` does now; include paths through `t.addIncludePath`/`t.addSystemIncludePath`; defines through `t.defineCMacro(d.name, d.value)`. The fixup run consumes `t.output_file` where it consumed `translate.getOutput()`. Keep `--help` output and option names unchanged.

- [ ] **Step 3: Count what the fixup pass still finds**

Run: `zig build zig-objects --verbose 2>&1 | grep -oE '[^ ]*translate[^ ]*\.zig' | head -1` to locate the translated file in the cache, then `grep -cE '^\s*@as\(c_[a-z_]+, [A-Za-z_][A-Za-z0-9_.]*\) [-+*/%&|^]= ' <that file>`.
Expected: a number. Zero means delete `fixup_translated.zig`, its `addExecutable`/`addRunArtifact` wiring and the docs paragraph, and feed `t.output_file` to `c_mod` directly. Nonzero means keep the tool, update its header comment to name translate-c 2.x and the pattern, and record the count.

- [ ] **Step 4: Verify the objects build and the layout probe compiles**

Run: `zig build zig-objects` exit 0; `zig build unit-test 2>&1 | tail -5` — compiles (test failures inside the ports belong to Task 3; a compile error that mentions a `c.` symbol missing from the translated output is this task's and is fixed in `src/zig/moar_c.h` or with `t.defineCMacro`, never by editing `src/*.h`).

- [ ] **Step 5: Docs, format, commit**

`docs/zig-build.md`: the translate sentence names the package and the branch, says the first build fetches it (network, once) and that `ZIG_GLOBAL_CACHE_DIR` holds it afterwards; the fixup paragraph updated or removed. Commit: "translate-c via the translate_c package".

### Task 3: Ports and unit tests on 0.17

**Files:**
- Modify: the seven `**` sites (`src/zig/core/hash/table.zig:147`, `uni_bench.zig:396`, `test/uni_test.zig:106`, `tiers/ordered.zig:592`, `tiers/robinhood.zig:887`, `tiers/small.zig:368`, `tiers/swiss.zig:732`); `@intFromEnum` (10 sites: `src/zig/core/hash/stats.zig:175,180,191`, `build/zig/sources.zig:67-77`); `std.builtin.` (17 sites in 16 files, mostly `std.builtin.SymbolVisibility` in the `*_exports.zig` files and `src/zig/gc/*.zig`); `std.fmt.allocPrint` (14 sites in 4 files); `std.debug.runtime_safety` (3); bit-set names (2 sites in 2 files); any further compile errors the suite surfaces.
- Test: the existing `src/zig/**/test/*.zig`; no new test files.

**Interfaces:**
- Consumes: `c_mod` and `moar_mod` from Task 2 unchanged.
- Produces: nothing new; every exported C symbol list unchanged (checked in Step 6).

- [ ] **Step 1: Locate the 0.16 reference**

The reference lists are `/tmp/claude-1000/z017/unit-016-g0.txt`, `unit-016-g1.txt` and `exports-016.txt` from Task 1 Step 0 (totals in the ledger). If /tmp was wiped since, stop and report; the orchestrator re-creates them from the parent commit with the 0.16 toolchain.

- [ ] **Step 2: Capture the 0.17 failures**

Run: `zig build unit-test 2>&1 | grep -E "error:" | sort | uniq -c | sort -rn > /tmp/claude-1000/z017/unit-017-errors.txt; wc -l < /tmp/claude-1000/z017/unit-017-errors.txt`. Expected: nonzero.

- [ ] **Step 3: Apply the mechanical renames**

`[_]T{v} ** n` to `@as([n]T, @splat(v))` with the array type written out (for `@sizeOf(Status)` keep the expression as the length); `@intFromEnum(x)` to `@backingInt(x)`; `std.builtin.X` to `std.lang.X`; `std.fmt.allocPrint(a, fmt, args)` to `a.print(fmt, args)`; `std.debug.runtime_safety` to `std.lang.Optimize.runtimeSafety(@import("builtin").mode)` (or the module's `optimize` where one exists); bit-set type names and `initEmpty`/`initFull` to the new names. Then fix whatever `zig build unit-test` still reports, one error class per commit if more than one class appears.

- [ ] **Step 4: Verify the suites match the reference**

Run: `timeout 300 zig build unit-test --summary all 2>&1 | tee /tmp/claude-1000/z017/unit-017-g0.txt | tail -3` and the `-Dgc-debug=1` variant.
Expected: the test totals equal Step 1's; `diff <(grep -oE '^[^ ]+ test [^ ]+' unit-016-g0.txt | sort) <(… 017 …)` empty (same names, same verdicts); gc-test wall time recorded.

- [ ] **Step 5: Export surface unchanged**

Run: `zig build zig-objects && nm -g --defined-only <the same object as Task 1 Step 0> | awk '{print $3}' | grep '^MVM_' | sort > /tmp/claude-1000/z017/exports-017.txt; diff /tmp/claude-1000/z017/exports-016.txt /tmp/claude-1000/z017/exports-017.txt`. Expected: empty.

- [ ] **Step 6: Format, commit**

`zig fmt src/zig` as "zig fmt 0.17: ports" if needed; then "Ports on Zig 0.17: splat, backingInt, lang, Allocator.print".

### Task 4: End-to-end suites, the Perl `--zig` path, the bench tools

**Files:**
- Modify: `Configure.pl:1419` (help text "0.16.0" to "0.17.1"), `docs/zig-build.md:3` (version), `tools/check-jit-tools.sh` only if it breaks.
- Test: `zig build test` (both debug levels), `zig build test -Dzig-impl=false`, `zig build strategy-test`, `zig build check-jit-tools`, `prove tools/bench/t/`, a Perl `Configure.pl --cc=zig --zig=/usr/bin/zig` build.

- [ ] **Step 1: zig build test at both levels and the all-C fallback**

Run (each under the memory scope, prefix deleted after): `zig build test --prefix /tmp/claude-1000/z017/t0`, `… -Dgc-debug=1 --prefix …/t1`, `… -Dzig-impl=false --prefix …/tc`. Expected: 81/81, 81/81, 67/67 steps.

- [ ] **Step 2: Generators and bench harness**

Run: `zig build check-jit-tools` (Zig generators equal Perl after canonical renumbering: exit 0); `zig build strategy-test` success; `prove tools/bench/t/` with `/tmp/claude-1000/gc-c-oracle` present: 6 files, 107 tests PASS.

- [ ] **Step 3: The Perl build's Zig path**

Run: `perl Configure.pl --prefix=/tmp/claude-1000/z017/perl --cc=zig --zig=/usr/bin/zig && make -j24 install`, then the nqp smoke from Task 1 Step 5 on that moar. Expected: pass. Then `make realclean; rm -f src/gen/config.h src/gen/config.c src/gen/config.o` and `git status --short` shows only the known untracked items.

- [ ] **Step 4: Commit**

"Zig 0.17 in the Perl path's help text and the docs version line".

### Task 5: Re-baseline on 0.17 and the toolchain A/B

**Files:**
- Create (traces): `bench/z017-prefixes.md` (recipe, versions, load, timings), `bench/z017-oracle.md` + `z017-oracle-logs/`, `bench/z017-crc-ab.md` + raw dirs, `bench/z017-spectest.txt` + `z017-spectest-raw/`, `bench/z017-suites.md` + raw.
- Reuse: `traces/llm/bench/gc-final-oracle-matrix.sh`, `gc-final-spectest-driver.sh`, `gc-final-maketest-driver.sh`, `tools/bench/gc/oracle.sh`, `tools/bench/gc/ab.sh` (parameterised by prefix; copy to `z017-*-driver.sh` with the new prefix names, do not edit the gc-final drivers).

- [ ] **Step 1: Build the six 0.17 prefixes**

`zig build install --prefix /tmp/claude-1000/g7-c-oracle -Dzig-impl=false -Dgc-debug=1`, `g7-z-oracle -Dgc-debug=1`, `g7-c-base -Dzig-impl=false`, `g7-z-base`, `g7-c-stress -Dzig-impl=false -Dgc-debug=1 -Dnursery-size=524288`, `g7-z-stress -Dgc-debug=1 -Dnursery-size=524288`; load under 2.0 before each; record `moar --version` of each (equal-length strings). No nqp or rakudo is installed into the prefixes: as `docs/zig-build.md` "Recipes the campaign used" says, the scripts reach the prefix through `LD_LIBRARY_PATH=<P>/lib` with the rakudo and nqp built against `/tmp/claude-1000/tune-zig-prefix` (a path of equal length), exactly as the 0.16 prefixes are used.

- [ ] **Step 2: Oracle matrix**

Cells: (a) `g7-c-oracle` vs `g7-z-oracle`, 10 000 and 100 000, plain and `--bad-packages`, tiers 1 and 2 (8 cells); (b) `gc-c-oracle` (0.16 C) vs `g7-c-oracle`, the same 8 cells. Expected: all 16 exit 0 with byte-identical logs. A difference in (b) is a toolchain finding: stop, diff the first differing line, report.

- [ ] **Step 3: crc-getter A/B**

`ab.sh --rounds=7 --runs=5 --volume=100000`, plain and `--bad-packages`, for the pairs `g7-c-base` vs `g7-z-base` (the new baseline) and `gc-c-base` vs `g7-c-base` (toolchain). Record medians, spreads and ratios in `z017-crc-ab.md` next to the 0.16 figures (plain 1.011/1.015, bad 1.003/1.005).

- [ ] **Step 4: spectest A/B**

Two pairs, six runs each in the order base head head base base head: `g7-c-base` vs `g7-z-base`, then `gc-c-base` vs `g7-c-base`. Roast at fb1d87214, `.precomp` removed, load recorded. Record wall and RSS medians, ratios, `Files=`/`Tests=` and the TODO-passed list; zero new failures against `gc-final-spectest.txt`'s summary.

- [ ] **Step 5: Suites under stress**

nqp `make test` under `g7-c-stress` and `g7-z-stress` (the maketest driver recipe); rakudo `make test` under `g7-z-base`. Expected: the same per-file lists as `gc-final-suites-raw/` (150/13746 PASS; 599/11162 with the one pre-existing nativecall failure).

- [ ] **Step 6: Records and commit**

Write the five records; the oracle record states the 0.16-vs-0.17 C result in its first line. Commit in traces ("z017: re-baseline on Zig 0.17"), then the MoarVM pointer commit.

### Task 6: Docs, deviations, close

**Files:**
- Modify: `docs/zig-build.md` ("### Zig 0.16 notes from the port" becomes "### Zig notes from the ports" with a 0.16 subsection kept as history and a new 0.17 subsection: `std.lang`, `@splat` for array repeats, `@backingInt`, `Allocator.print`, `translate_c` package and offline note, `b.root`), `traces/llm/plans/2026-11-08-zig-017-migration.md` (this file: a "## Deviations" section and a "## Outcome" table), the GC spec's "Zig 0.16 notes" erratum pointer if any item there is now wrong.
- Create: memory updates (orchestrator).

- [ ] **Step 1: Docs**

Edit the docs section; `grep -n "0\.16" docs/zig-build.md` afterwards lists only the history subsection.

- [ ] **Step 2: Outcome table**

| check | result | record |
|---|---|---|
| configure, 12 steps | | ledger |
| unit-test names and verdicts = 0.16 reference, both levels | | z017-suites.md |
| zig build test 81/81 ×2, all-C 67/67 | | z017-suites.md |
| oracle 16/16 byte-identical (incl. 0.16-C vs 0.17-C) | | z017-oracle.md |
| crc-getter Z17/C17 and C17/C16 | | z017-crc-ab.md |
| spectest Z17/C17 and C17/C16, zero new failures | | z017-spectest.txt |
| exports unchanged | | ledger |

- [ ] **Step 3: Commit, hand back**

Commit docs in MoarVM, plan in traces, pointer in MoarVM. Hand back with the Outcome table and the Deviations list. The orchestrator runs the whole-branch review before any merge into `zig-hash-engine` (user's call).

## Deviations (running list)

- 2026-11-08, before Task 5: the 0.17 prefixes are named `g7-?-*`, not `z17-?-*`, so each cross-toolchain pair (`gc-c-base` vs `g7-c-base`, …) has equal-length names as the Global Constraints require; the plan's original names were one character longer than the 0.16 ones.
- Tasks 1-4 deviations are in the ledger (`.superpowers/sdd/2026-11-08-zig-017-migration/progress.md`) and are copied here by Task 6.
