# Internal Tables on Their Own Strategies Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Measure what MoarVM's 26 internal hash tables actually do in a running Rakudo, then put each hot table on the layout its numbers favour, porting the Swiss tier to the uni and index kinds where needed, proven by per-site benchmarks and a not-slower spectest.

**Architecture:** A comptime-off statistics layer (`-Dhash-stats`) in the engine's policy layer counts operations, cycles and sizes per table kind and per C creation site, the site minted from the caller's return address in the export layer and stored in a stats-only extension of the table header; the counters are dumped at `atexit` into one TSV per process and aggregated by a Perl tool into a survey report. After the user's ruling on the survey, each hot site is switched at compile time (a per-site macro for str sites, a new default or per-site set for the other kinds), with a Swiss tier set added to `uni.zig` and `index.zig` as needed, each switch judged by a benchmark that stresses that site at the nqp level, and the whole by an interleaved spectest against the branch point.

**Tech Stack:** Zig 0.16 (engine, stats layer, C-API benchmarks), C (creation sites, shims), NQP (benchmarks), Perl (aggregator and TAP fixture tests, as `hash-compare.pl`), Python 3 (the committed `time -v` stand-in), sh (runners), the rakudo spectest.

**Spec:** `traces/llm/specs/2026-11-03-zig-hash-internal-tables-design.md` (traces 6ba8b56; the spec calls the tier's comptime parameter `KeySpec`, the source still spells it `Spec`). The bake-off spec and plan (`2026-11-03-zig-hash-layout-bakeoff-*.md`) and the census (`traces/llm/bench/bakeoff-census.md`, site labels s1-s9, u1-u4, f1-f8, i1-i3, p1-p2) are context every task may read.

## Global Constraints

- MoarVM work on branch `zig-hash-internals` from `zig-hash-engine` 1478311f6, in the main checkout. **No git worktrees** (the user's standing instruction, 2026-11-03). nqp and rakudo checkouts are not committed to unless a task says so (spec section 9 expects none).
- Set 0 of the str table, its tiers, migration and dispatch, the LOOKUP and APPEND strategies, the `hashstrategy` op and the `MVM_HASH_STRATEGY` override do not change (spec section 9). A diff to them is a plan violation unless a task names it.
- The C engine (`-Dzig-impl=false`) compiles and passes `zig build test` after every task (spec decision 5). No internal site ever hands the C engine a strategy other than 0.
- With `-Dhash-stats=false` (the default) the stats layer compiles to nothing: `@sizeOf(tier.Header) == 8`, no counters, no `atexit`; Task 2's ladder guard proves it and Task 10 re-proves it.
- Builds: `rm -f src/gen/config.h src/gen/config.c src/gen/config.o` before any `zig build` without `-Dconfig-h`; default options (`zig build install --prefix <P>`, LTO on, ReleaseFast, x86-64-v3) unless a task says otherwise; always an absolute `--prefix`. Prefixes: `/tmp/claude-1000/tune-zig-prefix` (default build of HEAD, nqp and rakudo installed against it, from the bake-off), `/tmp/claude-1000/stats-zig-prefix` (stats build, Task 3), `/tmp/claude-1000/internals-base-prefix` (default build of 1478311f6, Task 10). A variant is run against the shared nqp/rakudo of `tune-zig-prefix` by putting its `lib` first in `LD_LIBRARY_PATH`, as the post-LTO records did.
- Long runs (spectests, survey workloads, benchmark rounds) run as background scripts logging under the scratchpad `$CLAUDE_JOB_DIR/tmp`; the machine's 1-minute load is under 2.0 before a timed run starts (`until awk '{exit !($1 < 2.0)}' /proc/loadavg; do sleep 10; done`) and is recorded per run.
- Win rule for a site switch (spec decision 7): ratio at or below 0.90 with disjoint round spreads on the cells of the site's surveyed op mix, judged on the nqp-level cell; the C-API cell explains. Spectest gate (decision 8): zero new failures (a failure present on HEAD and absent in the interleaved base run), wall not slower than base beyond the run spread, peak RSS not worse; the 3 percent target is reported, not gated. Roast stays at fb1d87214.
- `zig fmt --check` clean on every Zig file touched; Perl passes `perl -c`; sh passes `sh -n`; Python passes `python3 -m py_compile`.
- Commit attribution lines as the session reminder gives them; plan sections and bench records are committed inside `traces/` and the pointer bumped in MoarVM in the same task.

## Rulings made while planning

- **Dump at `atexit`, not at instance teardown.** `MVM_vm_destroy_instance` runs only under `--full-cleanup`; the default path is `MVM_vm_exit` → `exit(0)`, and `nqp::exit` (`interp.c:3557`) and uncaught exceptions (`exceptions.c:692, 722, 874, 905, 956`) call `exit()` directly. One `atexit` handler registered by the engine on its first build (spec 4.2 said "at instance teardown"; this reaches every exit path with no C changes). Its storage is static or page-allocated, never `MVM_malloc`, because mimalloc's own `atexit` may have run.
- **The site id lives in a stats-only extension of `tier.Header`** (spec 4.2 left the place open): under stats, `Header` is 16 bytes, `{ tier, set, entry_size, stale, cur_items, site: u8, _pad: [3]u8, max_items: u32 }`; every tier embeds `Header` and computes offsets from `@sizeOf`, so the layouts follow. The "Header is 8 bytes" test becomes conditional.
- **The site is minted in the export layer and handed to `build` through a threadlocal.** `Table` has no caller information; the exported `*_build`, `*_insert`, `*_lvalue_fetch*` functions set `stats.pending_site = stats.siteOf(@returnAddress())` before calling in, and `Table.build` stores it. Those exports are `noinline` under stats so LTO cannot fold them into the C caller and move the return address. Shallow copies carry the source's site in the copied header for free.
- **`-Dhash-stats` implies `-Dstrip=false` and `-g` on the C objects**, so `addr2line` resolves return addresses to `file:line`; addresses are recorded as offsets from libmoar's load base (`dladdr`), so ASLR does not matter.
- **The stats flag reaches the pure-Zig files through `@import("root")`**: `tier.zig` reads `stats_enabled = @hasDecl(root, "hash_stats") and root.hash_stats`; `src/zig/root.zig` and `hash_test.zig` define `hash_stats` from their options module; the pure-Zig unit-test roots have none and see `false`.
- **One stats file per process in a directory** named by `MVM_HASH_STATS` (spec 4.2 after the builder check).
- **Benchmark key material comes from one committed data file**, `tools/bench/uni-bench-keys.tsv`, generated once from `unicode_db.c` by `tools/bench/uni-bench-keys.pl`; the nqp benchmark reads it and the Zig benchmark `@embedFile`s it, so the two levels fetch the same names.
- **The nqp op is `nqp::codepointfromname`**, not `nqp::getcpbyname` (that is the moarop); spec section 3 gets an erratum in Task 10.
- **The A/B runner and the timing stand-in are committed** (`tools/bench/hash-ab.sh`, `tools/bench/timev.py`); the bake-off's lived in a scratchpad and nearly vanished.
- **Per-site sets for uni are selected with a `build_strategy` entry point mirroring str's** (`MVM_uni_hash_build_strategy`, C-engine fallback accepting only 0), because u3 and u4 are built implicitly by `insert` into a zeroed table and the only way to give them a set is an explicit build call at the site. Index needs none: `i2` is the only index site with volume and `MVM_index_hash_build` is explicit; its default set changes if it wins.

## Review Focus

1. A table built on one thread and used or demolished on another (an `MVMHash` handed to a worker): per-thread counters must merge without loss or double count. Pinned in Task 2 (`std.Thread` test).
2. `MVM_HASH_STATS` names a directory that does not exist or is not writable: the exiting program must still exit with its own status, writing one line to stderr. Pinned in Task 2.
3. More than 255 distinct build sites, or an export inlined by LTO so the return address is the caller's caller: attribution must degrade to a counted "other" site, never index out of bounds, and the end-to-end check must see `s1` resolve to `src/moar.c`. Pinned in Tasks 2 and 3.
4. Swiss on uni's 32-bit codes: every key would share the salt's tag without widening; the tag distribution over the real 4,380 property names must be near-uniform, and lookups must still hit after `grow`. Pinned in Task 7.
5. A Swiss index table shallow-copied into a cloned static frame (`i3`) must answer lookups through the new owner's `list`, and `insert_nocheck` of equal strings under different indices must remain distinct entries. Pinned in Task 8.

---

### Task 1: `-Dhash-stats` and the statistics module

**Files:**
- Modify: `build/zig/options.zig` (`hash_stats: bool` field, `b.option(bool, "hash-stats", ...)` default false), `build/zig/zigimpl.zig` (`zig_opts.addOption(bool, "hash_stats", opts.hash_stats)`; `-g` in the C cflags and `strip = false` when `opts.hash_stats`), `build/zig/moar.zig` (same cflags/strip rule for libmoar's C objects), `build.zig` (`bench_opts.addOption(bool, "hash_stats", opts.hash_stats)`; add `src/zig/core/hash/stats.zig` to the pure-Zig unit-test roots), `src/zig/root.zig` (`pub const hash_stats = @import("zig_options").hash_stats;`), `src/zig/core/hash/hash_test.zig` (`pub const hash_stats = @import("build_options").hash_stats;`), `docs/zig-build.md` (options table row; a "### Statistics" subsection under "Hash engine" describing `-Dhash-stats` and `MVM_HASH_STATS`)
- Create: `src/zig/core/hash/stats.zig`

**Interfaces:**
- Produces, in `stats.zig` (all `pub`; everything is a comptime no-op returning zero values when `enabled` is false):
  - `pub const enabled: bool` (from `@import("root")` as the ruling says), `pub const max_sites: u8 = 255` (id 255 is `other`), `pub const Op = enum(u8) { build, insert, overwrite, fetch_hit, fetch_miss, delete_hit, delete_miss, iter_start, iter_step, copy, grow, migrate, demolish }`, `pub const buckets = [_]u32{ 4, 16, 32, 64, 65, 128, 256, 1024, 16384 }` (a tenth bucket is "more").
  - `pub fn siteOf(ret_addr: usize) u8` (interns under a mutex; returns `max_sites` when full), `pub threadlocal var pending_site: u8`, `pub fn takePendingSite() u8` (returns and resets to `max_sites`).
  - `pub inline fn now() u64` (`rdtsc` on x86_64, `std.time.Instant` nanoseconds elsewhere), `pub inline fn count(site: u8, op: Op) void`, `pub inline fn countCycles(site: u8, op: Op, t0: u64) void`, `pub inline fn probe(site: u8, hit: bool, len: u32) void`, `pub fn sizeAtBuild(site: u8, expected: u32) void`, `pub fn sizeAtDemolish(site: u8, set: u8, rung: u8, max_items: u32) void`.
  - `pub fn dump(w: *std.Io.Writer) !void` (the format below) and `pub fn ensureRegistered() void` (registers the `atexit` handler once, via `std.once`; the handler opens `<MVM_HASH_STATS>/<pid>.tsv` with `std.fs` and calls `dump`; on any failure it writes one line to stderr and returns).
- Dump format (TSV, `#`-prefixed header lines): `# cmdline: <argv joined by spaces, from /proc/self/cmdline>`, `# pid: N`, `# tsc_hz: <calibrated from the first build to the dump>`, `# total_cycles: <dump tsc - first build tsc>`, `# libmoar: <path from dladdr>`; then rows `site\t<id>\t<offset_hex>` (one per interned site, offset from libmoar's load base), `op\t<site>\t<op name>\t<count>\t<cycles>`, `probe\t<site>\t<hit|miss>\t<count>\t<sum_len>\t<max_len>`, `build\t<site>\t<bucket>\t<count>`, `demolish\t<site>\t<set>\t<rung>\t<bucket>\t<count>`.
- Per-thread storage: a `threadlocal var local: ?*Counters`, page-allocated on first use and pushed onto a global mutex-guarded list that `dump` merges; nothing atomic on the hot path.

- [ ] **Step 1: Failing pure-Zig tests** in `stats.zig` (they run with `enabled` false under the pure root, so test the pure parts): `"siteOf interns and saturates"` (256 distinct addresses: ids 0..254 then 255 for every further one; a repeated address returns its id), `"buckets map sizes to the ladder"` (`bucketOf(4) == 0`, `bucketOf(5) == 1`, `bucketOf(65) == 4`, `bucketOf(16385) == 9`), `"dump of empty counters is only the header"` (into a `std.Io.Writer.Allocating`; every line starts with `#`). Run `zig build unit-test`. Expected: FAIL, module missing.
- [ ] **Step 2: Implement `stats.zig`** to the interface above; run `zig build unit-test` until PASS; `zig fmt --check`.
- [ ] **Step 3: Plumb the option.** `options.zig`, `zigimpl.zig`, `moar.zig`, `build.zig`, `root.zig`, `hash_test.zig` as listed. Verify: `zig build -Dhash-stats=true --prefix $PWD/zig-out install` succeeds and `nm -C zig-out/lib/libmoar.so | grep -c ' T MVM_str_hash_build$'` is 1 with `readelf -S zig-out/lib/libmoar.so | grep -c debug_line` at least 1; the default build still passes `zig build test` for both `-Dzig-impl` values.
- [ ] **Step 4: Docs.** The options row and the "### Statistics" subsection (what is counted, the file format, that it is a diagnostic build, that it is zig-build only).
- [ ] **Step 5: Commit** MoarVM ("Hash engine: -Dhash-stats option and the statistics module").

---

### Task 2: The hooks, the header extension, site minting, the ladder guard

**Files:**
- Modify: `src/zig/core/hash/tier.zig` (`Header` conditional on `stats.enabled`; `test "Header is 8 bytes"` becomes `"Header is 8 bytes without stats, 16 with"`), `src/zig/core/hash/table.zig` (hooks at the choke points: `build`, `lvalue` found/inserted/full, `fetch` hit/miss, `delete`, `first`/`start` and `next`, `shallowCopy`, `growOrMigrate` grow vs `migrate`, `demolish`; `max_items` maintained on `.inserted`), the five `*_exports.zig` (set `stats.pending_site` in `*_build`, `*_build_strategy`, `*_insert*`, `*_lvalue_fetch*`; those functions `noinline` under stats), the tier files only if a size assertion on the control block needs the conditional (`swiss.zig`'s `Control` pad, `ordered.zig`'s), `src/zig/core/hash/hash_test.zig` (import the new test file)
- Create: `src/zig/core/hash/test/stats_test.zig`, `tools/bench/hash-ab.sh`, `tools/bench/timev.py`
- Record: `traces/llm/bench/internals-ladder-guard.md` (+ raw TSVs `internals-ladder-guard-*.tsv`)

**Interfaces:**
- Consumes Task 1's `stats` API. Produces: every `Table` op attributed to `header.site`; `Table.build(ctx, h, entry_size, expected, set_index)` unchanged in signature, reading `stats.takePendingSite()` when stats are on; `tools/bench/hash-ab.sh --rounds=R --sizes=S --out=DIR --variant=NAME:LIBDIR[:BENCH_EXE] ...` (two or more variants, rotated per round, nqp ladder through `tune-zig-prefix`'s `nqp-m` under `LD_LIBRARY_PATH=LIBDIR`, C-API ladder through `BENCH_EXE` when given; raw rows `variant round <7 harness columns>`; `load.log`; ends by running `hash-compare.pl` per level); `tools/bench/timev.py OUTFILE CMD...` (the scratchpad script, unchanged).

- [ ] **Step 1: Failing tests** in `test/stats_test.zig`, libmoar-linked, skipped (`return error.SkipZigTest`) unless `build_options.hash_stats`: `"a str table's ops are counted under its site"` (build through the C-shaped `MVM_str_hash_build` of `str_exports`, 100 inserts, 100 hits, 50 misses, 10 deletes, one iteration, demolish; the dump contains `op\t<id>\tinsert\t100`, `fetch_hit\t100`, `fetch_miss\t50`, `delete_hit\t10`, `iter_step\t90`, `demolish\t1`, and a `build` row in bucket 128's line), `"two threads merge"` (Review Focus 1: a table built on the main thread, 1,000 inserts from a `std.Thread`, demolished on main; the merged dump shows `insert\t1000` once), `"site ids saturate at other"` (Review Focus 3: mint 300 addresses through `stats.siteOf`, build a table with `pending_site = 255`, its ops land under site 255). Run `zig build unit-test -Dhash-stats=true`. Expected: FAIL.
- [ ] **Step 2: Header extension and hooks.** `tier.zig`, `table.zig`, the exports; `test "the four single-rung tables dispatch without a set comparison"` unchanged. Run until PASS with `-Dhash-stats=true`; then `zig build unit-test` and `zig build test` without it (the stats tests skip; the 8-byte test holds). `zig fmt --check`.
- [ ] **Step 3: Zero-cost check by disassembly.** `objdump -d zig-out/lib/libmoar.so --disassemble=MVM_str_hash_fetch_nocheck` on the default build: no `rdtsc`, no call into `stats`. Note the instruction count in the record.
- [ ] **Step 4: Commit the tools.** `tools/bench/timev.py` (from the scratchpad, header comment naming its origin) and `tools/bench/hash-ab.sh` (generalising the scratchpad's `interleave2.sh`: variants by name and lib dir, both ladders, `hash-compare.pl` at the end); `sh -n`, `python3 -m py_compile`; a dry run with `--rounds=1 --sizes=16`.
- [ ] **Step 5: Ladder guard.** Base build: with the tree clean (everything committed), `git checkout --detach 1478311f6`, `zig build install --prefix /tmp/claude-1000/internals-base-prefix`, `git checkout zig-hash-internals` (no worktree; the build touches no tracked file). HEAD default build into `tune-zig-prefix`. `hash-ab.sh --rounds=5 --sizes=4,16,32,63,64,65,128,256,1024,16384 --variant=base:/tmp/claude-1000/internals-base-prefix/lib --variant=head:/tmp/claude-1000/tune-zig-prefix/lib` (nqp ladder; C-API ladder with each prefix's `hash-bench` exe built by `zig build hash-bench --prefix <P>` and copied beside). Expected: every cell within the round spread or within 5 percent (the bake-off's baseline rule). Record `internals-ladder-guard.md` (header as `bakeoff-baseline-check.md`: machine, shas, load, rule, verdict per cell that fails the rule, if any).
- [ ] **Step 6: Commit** MoarVM ("Hash engine: statistics hooks, site attribution, A/B runner and timing stand-in"); traces ("internals: ladder guard after the stats hooks") and the pointer.

---

### Task 3: The aggregator and the stats prefix

**Files:**
- Create: `tools/bench/hash-stats.pl`, `tools/bench/t/hash-stats.t`
- Modify: `docs/zig-build.md` ("### Statistics": the aggregator's usage)
- Record: `traces/llm/bench/internals-smoke.md`

**Interfaces:**
- Produces: `tools/bench/hash-stats.pl DIR --lib=PATH/libmoar.so [--census] [--tsv=OUT.tsv] > report.md`: reads every `*.tsv` in DIR, resolves each `site` offset with `addr2line -e LIB -f -C 0x<offset>` to `function` and `file:line`, maps `(file, function)` to the census label through a built-in table (s1 `src/moar.c` `MVM_vm_create_instance`; s2 `src/core/bytecode.c` `deserialize_frames`; s3 `HashAttrStore.c` `copy_to`; s4 `HashAttrStore.c` `bind_attribute`; s5 `MVMHash.c` `bind_key`; s6 `MVMHash.c` `deserialize`; s7/s8 `nativecall_*.c`; s9 `MVMHash.c` `copy_to`; u1 `generate_property_codes_by_names_aliases`; u2 `generate_property_codes_by_seq_names`; u3 `generate_codepoints_by_name`; u4 `MVM_unicode_init`; f1-f8 by line within `MVM_vm_create_instance` and `MVM_disp_syscall_setup`; i1 `MVM_vm_create_instance`; i2 `deserialize_frames`; i3 `MVMStaticFrame.c` `copy_to`; p1 `MVM_gc_object_id`; p2 `heapsnapshot.c`), unmapped sites keep `function@file:line`; aggregates across files (sums of counts and cycles, max of max, bucket histograms) with the file count and the count of header-only files; prints, per site, a table of op counts, cycles, cycles per op, share of hash cycles and of `total_cycles`, probe mean and max, build and demolish histograms, then a `## Hash share` section per program name (the first `.moarvm` or `-e` in `cmdline`). `--tsv` writes the merged rows.

- [ ] **Step 1: Fixture test** `tools/bench/t/hash-stats.t` (pattern of `hash-bakeoff.t`): two synthetic stats files in a tempdir, a fake `addr2line` on `PATH` (a shell script in the tempdir printing fixed `function` and `file:line` pairs), asserts: counts summed across files (`is`/`like` on the `insert` row), a site mapped to `s1`, an unmapped site printed as `function@file:line`, the share column sums to 100 within rounding, exit non-zero and a message when DIR has no files. A second part, skipped unless `HASH_STATS_MOAR` names a stats-build `moar` (Review Focus 2): `MVM_HASH_STATS=/nonexistent/dir $HASH_STATS_MOAR --version` exits 0 and prints exactly one stderr line containing `MVM_HASH_STATS`; `MVM_HASH_STATS=<tempdir> $HASH_STATS_MOAR --version` leaves one `*.tsv` whose first line starts with `# cmdline:`. `prove tools/bench/t/hash-stats.t`. Expected: FAIL, script missing.
- [ ] **Step 2: Write `hash-stats.pl`**; `perl -c`; fixture PASS.
- [ ] **Step 3: The stats prefix.** `zig build install --prefix /tmp/claude-1000/stats-zig-prefix -Dhash-stats=true` (after the `rm -f src/gen/config.*`). `HASH_STATS_MOAR=/tmp/claude-1000/stats-zig-prefix/bin/moar prove tools/bench/t/hash-stats.t` passes both parts. Verify `LD_LIBRARY_PATH=/tmp/claude-1000/stats-zig-prefix/lib MVM_HASH_STATS=$CLAUDE_JOB_DIR/tmp/smoke /tmp/claude-1000/tune-zig-prefix/bin/raku -e 'say 1'` prints 1 and leaves one file.
- [ ] **Step 4: End-to-end smoke** (Review Focus 3): `hash-stats.pl $CLAUDE_JOB_DIR/tmp/smoke --lib=/tmp/claude-1000/stats-zig-prefix/lib/libmoar.so`: `s1` resolves to `src/moar.c`, `u4` to `MVM_unicode_init`, `i2` to `deserialize_frames`, `s5` to `bind_key`; no site is `other`; the report lists at least 12 distinct sites for `raku -e 'say 1'`. Also `nqp::exit(3)` path: `raku -e 'exit 3'` leaves a file and exits 3. Record `internals-smoke.md` (which sites appear at startup, with counts).
- [ ] **Step 5: Commit** MoarVM ("tools/bench: hash-stats aggregator"); traces ("internals: startup smoke") and the pointer.

---

### Task 4: The unicode benchmark (nqp level and C API)

**Files:**
- Create: `tools/bench/uni-bench-keys.pl`, `tools/bench/uni-bench-keys.tsv`, `tools/bench/uni-bench.nqp`, `tools/bench/t/uni-bench.t`, `src/zig/core/hash/uni_bench.zig`, `src/zig/core/hash/uni_bench_shim.c`
- Modify: `build.zig` and `build/zig/zigimpl.zig` (`addUniBench` beside `addHashBench`; step `uni-bench`), `tools/bench/hash-ab.sh` (`--ladder=NAME`, default `hash`: a round runs `tools/bench/NAME-bench.nqp` and, when a variant names an exe, that exe; later tasks add `lex` and per-site ladders by adding scripts, not runner changes), `docs/zig-build.md` (command list line for `zig build uni-bench`)

**Interfaces:**
- `uni-bench-keys.pl src/strings/unicode_db.c > tools/bench/uni-bench-keys.tsv`: rows `kind\tname[\tvalue]`, kinds `prop` (every `unicode_property_keypairs` name whose value's canonical name it is), `alias` (the other names of the same array), `pval` (`<propcode>-<valuename>` keys from `unicode_property_value_keypairs`, 1,024 sampled with a fixed stride), `seq` (every `uni_seq_pairs` name). Codepoint names are not in the file: both benchmarks harvest them at runtime (`nqp::getuniname(cp)` / `MVM_unicode_get_name`) for `cp` in 0..0x2FFFF, skipping empty names and names starting with `<`, then take `--sample` (default 4096) with a seeded LCG shuffle (seed 0x5eed).
- `uni-bench.nqp [--engine=NAME] [--runs=K] [--ops=a,b] [--sample=N] [--keys=PATH]`: cells `cpbyname_hit`, `cpbyname_miss` (hit names with ` ZZZ` appended), `cpbyname_miss_prefix` (`CJK UNIFIED IDEOGRAPH-<hex>` over 0x4E00.., and the second prefix form the builder finds in `MVM_unicode_lookup_by_name`), `propcode_hit`, `propcode_alias`, `propcode_miss` (`_X` suffix), `pvalcode_hit`, `pvalcode_miss`, `strfromname_seq`; each cell one sub (as `hash-bench.nqp`), the key list walked `repeat` times so a timed region exceeds 10 ms, output the harness's 7 columns with `size` = number of distinct keys of the cell, engine default `zig`.
- `zig build uni-bench -- [--runs=K] [--ops=...] [--sample=N]`: `uni_bench.zig` creates an instance, forces u1/u3 to exist by one call each to `MVM_unicode_name_to_property_code` and `MVM_unicode_lookup_by_name`, harvests codepoint names with `MVM_unicode_get_name` + `MVM_string_utf8_encode_C_string`, reads the `prop`/`alias`/`pval`/`seq` rows from `@embedFile("uni_bench_keys")` (the build adds the TSV with `mod.addAnonymousImport("uni_bench_keys", .{ .root_source_file = b.path("tools/bench/uni-bench-keys.tsv") })`, since `@embedFile` cannot leave the module's directory), and times `bench_uni_fetch(tc, &instance->codepoints_by_name, key)` (u3 hit, miss), `&instance->property_codes_by_names_aliases` (u1 hit, alias, miss), `instance->unicode_property_values_hashes[propcode]` (u4 hit, miss) and `&instance->property_codes_by_seq_names` (u2 hit) through `uni_bench_shim.c` wrappers `bench_uni_fetch`, `bench_uni_insert`; same 7-column TSV, engine from `build_options.zig_impl`.

- [ ] **Step 1: Keys file.** Write `uni-bench-keys.pl`, generate the TSV, `perl -c`; the file has at least 100 `prop`, 100 `alias`, 1,024 `pval`, 3,000 `seq` rows (assert in the script).
- [ ] **Step 2: Failing TAP test** `tools/bench/t/uni-bench.t` (as `hash-bench-hint.t`: skip unless `UNI_BENCH_NQP`): runs `--runs=1 --sample=64 --ops=cpbyname_hit,propcode_miss`, asserts two output rows with those op names, `size` 64 and at least 100 respectively, and that `--ops=bogus` dies naming the op. Also a pure fixture: `--keys=<tempfile>` with a malformed row dies. `UNI_BENCH_NQP=/tmp/claude-1000/tune-zig-prefix/bin/nqp-m prove tools/bench/t/uni-bench.t`. Expected: FAIL, script missing.
- [ ] **Step 3: Write `uni-bench.nqp`**; PASS; every cell verifies its hits (a `_hit` cell with any miss dies, a `_miss` cell with any hit dies).
- [ ] **Step 4: C-API benchmark.** `uni_bench_shim.c`, `uni_bench.zig` (parse/median/spread helpers shared with `bench.zig` by moving them into a small `bench_util.zig`), build wiring; `zig build uni-bench -- --runs=3 --sample=256` prints 9 rows for both `-Dzig-impl` values; `zig fmt --check`. Add `uni_bench.zig` to `hash_test.zig`'s imports so its parse tests run under `unit-test`.
- [ ] **Step 5: `hash-ab.sh --ladder=uni`** runs the nqp script and the exe per variant; dry run with two variants both `tune-zig-prefix`.
- [ ] **Step 6: W4, the coverage check.** `MVM_HASH_STATS=$CLAUDE_JOB_DIR/tmp/w4 LD_LIBRARY_PATH=/tmp/claude-1000/stats-zig-prefix/lib tune-zig-prefix/bin/nqp-m tools/bench/uni-bench.nqp --runs=1`, aggregate: u1-u4 together hold at least 95 percent of the `fetch_hit + fetch_miss` counts (the rest is startup); note the figure in the plan's "## Survey" section later.
- [ ] **Step 7: Commit** MoarVM ("tools/bench: unicode lookup benchmark, nqp and C API").

---

### Task 5: The survey

**Files:**
- Record: `traces/llm/bench/internals-survey.md`, `internals-survey-{w1,w2,w3,w4}.tsv` (merged rows from `--tsv`), `internals-survey-overhead.md`, `internals-survey-load.log`; this plan ("## Survey" section)

**Interfaces:** consumes the stats prefix (Task 3), `hash-stats.pl`, `uni-bench.nqp`; produces the hot list the stop rules on.

- [ ] **Step 1: Overhead bound.** `hash-ab.sh --rounds=5 --sizes=16,64,65,1024,16384 --variant=default:/tmp/claude-1000/tune-zig-prefix/lib --variant=stats:/tmp/claude-1000/stats-zig-prefix/lib` (C-API and nqp ladders). The stats/default ratio per op is the overhead factor; record `internals-survey-overhead.md`.
- [ ] **Step 2: W1 startup.** 50 × `raku -e ''` and 50 × `nqp -e ''` with `MVM_HASH_STATS=$CLAUDE_JOB_DIR/tmp/w1` and the stats lib; aggregate.
- [ ] **Step 3: W2 the core setting.** In the rakudo checkout (configured for `tune-zig-prefix`): `make clean`, then `make` with the stats lib and `MVM_HASH_STATS=.../w2`; aggregate; restore the prefix's rakudo afterwards with a default-lib `make install` so the prefix stays a default install (the bytecode is identical; only the running libmoar differed).
- [ ] **Step 4: W3 the spectest.** `make spectest` (`TEST_JOBS=24`) once under the stats lib with `MVM_HASH_STATS=.../w3`, roast fb1d87214, `.precomp` dirs removed first; must pass (`Result: PASS`, spec section 8 item 4); aggregate; count files against `Files=1365` plus the harness processes and state the loss.
- [ ] **Step 5: W4.** The Task 4 Step 6 figure, re-run on this build if anything changed.
- [ ] **Step 6: The report.** `internals-survey.md` as spec 4.4: one section per site in census order (counts, cycles, share of hash cycles and of total cycles per workload, probe mean/max, build and demolish histograms, lifetime class), the **hot list** (sites at or above 5 percent of hash cycles in any workload, plus u1-u4; for each the scoreboard's suggested layout for its size range and op mix and the benchmark that will judge it), the per-workload hash share scaled by Step 1's overhead factor, and the answers to the census's open questions (lexical-name table sizes, MVMHash growth past Small, the SC weak hash per GC). Write the plan's "## Survey" section: the hot list and the proposed assignment per hot site, one line each.
- [ ] **Step 7: Commit** traces ("internals: survey") and the pointer.

---

### Task 5b: Lookups binned by table size (added at the stop, 2026-11-03, at the user's request)

**Files:**
- Modify: `src/zig/core/hash/stats.zig` (a per-thread histogram `fetch[site][hit|miss][bucket]` of counts and cycles, bucketed by the table's `cur_items` at the time of the fetch with the existing `bucketOf`; dump rows `fetch\t<site>\t<hit|miss>\t<bucket>\t<count>\t<cycles>`), `src/zig/core/hash/table.zig` (the `fetch` hit/miss hooks pass `header.cur_items`; a fetch on a null handle goes to bucket 0 under site 255), `tools/bench/hash-stats.pl` (parse the rows; per site a "Lookups by table size" table: per bucket the hit and miss counts, cycles, share of the site's fetch cycles; `--tsv` carries the rows), `tools/bench/t/hash-stats.t` (fixture rows), `src/zig/core/hash/test/stats_test.zig`
- Record: `traces/llm/bench/internals-survey-binned.md`, `internals-survey-binned-w{1,2,3}.tsv`; the survey (`internals-survey.md`: a "Lookups by table size" section and corrected s5/i2 rows) and this plan's "## Survey" section (s5 and i2 lines restated from lookup shares)

**Interfaces:** consumes Task 1-3's stats module and aggregator; produces the `fetch` row kind (the only change to the dump format) and the share of each site's fetch cycles that falls on tables above 64 entries, which is the number the stop's s5 and i2 rulings need.

- [ ] **Step 1: Failing tests.** `stats_test.zig`: `"fetches are binned by the table's size"` (build a str table with 100 keys, 10 hits and 10 misses; the dump has `fetch\t<site>\thit\t5\t10` and `fetch\t<site>\tmiss\t5\t10`, bucket 5 being 65-128; a 10-key table's fetches land in bucket 1). `hash-stats.t`: two synthetic files with `fetch` rows; the report's per-site "Lookups by table size" table sums them and the share column sums to 100. RED, then implement until GREEN; `zig build unit-test` with and without `-Dhash-stats=true`; `zig build test` both engines; `zig fmt --check`; `perl -c`; `prove`.
- [ ] **Step 2: Rebuild the stats prefix** (`zig build install --prefix /tmp/claude-1000/stats-zig-prefix -Dhash-stats=true`). The default prefix is unchanged (no default-build code changed; confirm with the Step 3 disassembly check of Task 2 on a default `zig build`).
- [ ] **Step 3: Re-run W1, W2 and W3** exactly as Task 5 did (same commands, `.precomp` removal, load wait, `make install` with the default lib after W2), into fresh `MVM_HASH_STATS` directories; W3 must pass again.
- [ ] **Step 4: Aggregate and write** `internals-survey-binned.md`: per site (every site with fetches; s5 and i2 first) the hit/miss counts and cycles per bucket per workload and the share of the site's fetch cycles at or above 65 entries (bucket 4 and up) and at or above 128; then the two conclusions the stop needs, stated from lookup shares, not table shares: for s5, what share of its lookups and lookup cycles hit tables above 64; for i2, the same, plus the hit/miss split above 64. Correct the survey's s5 and i2 rows and the plan's "## Survey" lines; the "measurement gap" caveat is replaced by the measured figures.
- [ ] **Step 5: Commit** MoarVM ("Hash engine: stats bin fetches by table size; aggregator reports them"); traces ("internals: lookups binned by table size") and the pointer.

---

### Task 6: The stop: the user's ruling on the assignment

**Files:**
- Modify: this plan ("## Assignment ruling" section)

**Interfaces:** consumes "## Survey"; produces the list of sites Tasks 7-9 switch and the layout each gets.

- [ ] **Step 1: STOP for the user.** Present the hot list with, per site, the proposed layout and the benchmark; the cold sites with their numbers; the hash share per workload with the overhead bound; any site where two layouts are plausible, with the cells that pull each way. Ask the user to add or strike sites, move the 5 percent threshold if they wish, and rule on the ambiguous ones. This is the one planned stop (spec 4.5).
- [ ] **Step 2: Record** the ruling in "## Assignment ruling" (site, layout, reason, benchmark), and mark which of Tasks 7, 8, 9 run; a task whose sites were all struck is recorded as "not run: <reason>" and skipped. Commit traces and the pointer.

---

### Task 7: Swiss for the uni kind (u1-u4 as ruled)

**Files:**
- Modify: `src/zig/core/hash/uni.zig` (`UniSpec.hash` widening; `swiss_rung` set; `sets = &.{ &only_rung, &swiss_rung }` with the ruled default first; `buildStrategy`), `src/zig/core/hash/uni_exports.zig` (`MVM_uni_hash_build_strategy`), `src/core/uni_hash_table_funcs.h` (declaration), `src/core/uni_hash_table.c` (C-engine fallback: strategy 0 is `MVM_uni_hash_build`, else `MVM_exception_throw_adhoc("hash strategies need the Zig hash engine")`), `src/core/hash_internal_strategies.h` (new: `MVM_HASH_INTERNAL_UNI_PROPERTY_CODES`, `_UNI_SEQ_NAMES`, `_UNI_CODEPOINTS`, `_UNI_PROPERTY_VALUES`, each the ruled `MVMHashStrategy` under `#if MVM_ZIG_IMPL` and `MVM_HASH_STRATEGY_DEFAULT` otherwise; included from `moar.h`), `src/strings/unicode_ops.c:910-935` and `unicode_db.c:129534` and `unicode_ops.c:952` (explicit `MVM_uni_hash_build_strategy(tc, table, expected, MACRO)` before the inserts, with the real expected counts: 4380, 3680, `MVM_CODEPOINT_NAMES_COUNT + num_unicode_namealias_keypairs`, and per u4 table 0), `src/zig/core/hash/hash_test.zig` (the four-single-rung dispatch test now lists three kinds), `docs/hash-strategies.md`
- Test: `src/zig/core/hash/test/uni_test.zig`
- Record: `traces/llm/bench/internals-uni-bench.md` (+ raw), `internals-uni-spectest.txt` if the ruling put any uni site on a non-default set (it reaches every program through `MVM_unicode_init`)

**Interfaces:**
- Consumes: `swiss.Tier(.{})`'s requirements (entry size a nonzero multiple of 8: uni's is 16; zero key means unfilled: `UniKey.key == null`), `str.zig`'s `buildStrategy` shape.
- Produces: `uni.swiss_rung`, `pub fn buildStrategy(tc, ht, entries: u32, strategy: u8) void` (0 → set `only_rung`, 1 → `swiss_rung`; other values throw "hash strategy N is not available in this engine"); `MVM_uni_hash_build_strategy(MVMThreadContext *tc, MVMUniHashTable *hashtable, MVMuint32 entries, MVMuint8 strategy)`; `UniSpec.hash(ctx, key) u64 = widen(key.hash_val)` where `widen(h: u32) u64` is `(@as(u64, h) *% 0x9E3779B97F4A7C15) ^ (@as(u64, h) << 32)` or the builder's equivalent that a test shows spreads the top 7 bits.

- [ ] **Step 1: Failing tests** in `test/uni_test.zig`: `"widen spreads the tag bits over the property names"` (Review Focus 4: hash the 4,380 property-name strings from `tools/bench/uni-bench-keys.tsv` via `hashCode` then `widen`; count the 128 tag values `>> 57`; every tag count within 3x of the mean; no tag empty), `"strategy 1 round trip"` (buildStrategy 1, insert 70,000 generated names, every fetch hits, 10,000 misses miss, fsck 0, demolish), `"strategy 1 grows from an implicit zero start"` (build with 0 expected, 5,000 inserts, all hit), `"buildStrategy refuses 2"`. `zig build unit-test`. Expected: FAIL.
- [ ] **Step 2: Implement** `uni.zig`, exports, C declaration and fallback, the macro header, the three C sites (u4's 115 tables: one build each in the `MVM_unicode_init` loop, expected 0). Dispatch test updated. PASS; `zig build test` for both `-Dzig-impl` values; `zig fmt --check`.
- [ ] **Step 3: Benchmark, before.** With the macros still resolving to DEFAULT, build HEAD into `tune-zig-prefix`; `hash-ab.sh --ladder=uni --rounds=7 --variant=base:/tmp/claude-1000/internals-base-prefix/lib --variant=head:/tmp/claude-1000/tune-zig-prefix/lib`: expected within spread (the explicit builds change nothing). Then set the macros per the ruling, rebuild into a third prefix `/tmp/claude-1000/internals-uni-prefix`, and run `--variant=default:tune-zig-prefix/lib --variant=swiss:internals-uni-prefix/lib`, 7 rounds, nqp and C-API cells.
- [ ] **Step 4: Decide** per site by the win rule on the site's cells (u3: `cpbyname_*`; u1: `propcode_*`; u4: `pvalcode_*`; u2: `strfromname_seq`): kept sites keep their macro; a losing site's macro returns to DEFAULT (the entry point and the set stay, as LOOKUP did for user hashes). If u4 was ruled in and loses on the bare Swiss set, one more round with a two-rung set `small_then_swiss` (`small.Tier(.{ .max_capacity = 64 })` from 0, Swiss from 64; spec 5.1) as strategy 2 for the uni kind, same A/B, same rule; it ships only if it wins u4's cells without losing u1-u3's. Record `internals-uni-bench.md` (header as `bakeoff-final-nqp.md`; per cell ratio, spread, verdict; the C-API cell beside each nqp cell with one sentence where they disagree) and a "## Assignment results" row per site in this plan.
- [ ] **Step 5: Spectest gate** if any uni site is kept on Swiss: `make spectest` on the kept build (stats off), zero new failures against an interleaved base run (run base and HEAD alternately, one each, more only if a failure needs confirming); record `internals-uni-spectest.txt`.
- [ ] **Step 6: Commit** MoarVM ("Uni hash: Swiss tier set, build_strategy entry point, internal assignments: <sites kept>"); traces and the pointer.

---

### Task 8: Swiss for the index kind (i2, i3) — runs only if the ruling names them

**Files:**
- Modify: `src/zig/core/hash/index.zig` (`swiss_rung`; `IndexSpec.sets` with the ruled default first; the `only_rung` kept as set 1 for the A/B), `src/zig/core/hash/hash_test.zig` (dispatch test), `docs/hash-strategies.md`
- Create: `tools/bench/lex-bench.nqp`, `tools/bench/t/lex-bench.t`
- Test: `src/zig/core/hash/test/index_test.zig`
- Record: `traces/llm/bench/internals-lex-bench.md` (+ raw), `internals-index-spectest.txt`

**Interfaces:**
- Produces: `index.swiss_rung`; the kind's default set is a comptime constant `default_set: u8` in `index.zig` (0 or 1) that the task flips for the A/B build; `lex-bench.nqp [--engine=NAME] [--runs=K] [--lexicals=8,16,32,64] [--depth=8] [--ops=dynlex,outer]`: for each lexical count N it compiles with `nqp::getcomp('nqp').compile(source)` a chain of `depth` nested subs each declaring N lexicals (`my $v<i> := <i>;`), the outermost declaring `$*TARGET` (dynlex) and `$target` (outer); the innermost loops `nqp::getlexdyn('$*TARGET')` (cell `dynlex`: `depth - 1` misses then a hit per lookup, on tables of N) or `nqp::getlexouter('$target')`-style outer-chain lookups (cell `outer`); output the 7 columns with `size` = N. Lexical counts of 5 or fewer are not cells: those frames have no index table.

- [ ] **Step 1: Failing tests** in `test/index_test.zig`: `"strategy set 1 round trip"` (build on the Swiss set, 64 names inserted with their indices, every fetch returns its index, misses return `not_found`), `"shallow copy of a Swiss index table serves the clone's list"` (Review Focus 5: copy, then fetch through a second `list` holding the same strings; equal strings under two indices stay two entries), `"Swiss index tables of 6 to 64 entries fsck clean"`. `zig build unit-test`. Expected: FAIL.
- [ ] **Step 2: Implement**; PASS; dispatch test; `zig build test` both engines; `zig fmt --check`.
- [ ] **Step 3: `lex-bench.nqp`** with its TAP test (`LEX_BENCH_NQP=... prove`, asserting the cells appear and that `--lexicals=4` dies); verify with the stats build that `i2` holds at least 90 percent of the run's `fetch_miss` count.
- [ ] **Step 4: A/B.** Two builds (`default_set` 0 and 1) into `tune-zig-prefix` and `/tmp/claude-1000/internals-index-prefix`; `hash-ab.sh --ladder=lex --rounds=7`; decide by the win rule on the `dynlex` and `outer` cells at the N range the survey showed; record `internals-lex-bench.md` and the plan row.
- [ ] **Step 5: Spectest gate** if kept (the lexical-name tables reach every program; spec 5.3): interleaved base/HEAD, zero new failures; record `internals-index-spectest.txt`.
- [ ] **Step 6: Commit** MoarVM ("Index hash: Swiss tier set; lexical-name tables on <set>"); traces and the pointer.

---

### Task 9: The str sites and ptr — runs only for sites the ruling names

**Files:**
- Modify: `src/core/hash_internal_strategies.h` (`MVM_HASH_INTERNAL_SC_WEAKHASH`, `_HASH_DESERIALIZE`, `_HASHATTRSTORE`, as ruled), `src/zig/core/hash/fixkey.zig` (a `swiss_rung` and `default_set`, only if a fixkey site is ruled; the census expects none), `src/moar.c:203` (`MVM_str_hash_build_strategy(..., MVM_HASH_INTERNAL_SC_WEAKHASH)`), `src/6model/reprs/MVMHash.c:192` (deserialize: the macro in place of `hash_strategy_default` only if ruled, since the override must keep applying to user hashes: the site uses `tc->instance->hash_strategy_default ? that : MACRO`), `src/6model/reprs/HashAttrStore.c:33,96` (same pattern), `src/zig/core/hash/ptr.zig` (`swiss_rung` and a `default_set`, only if p1 is ruled), `docs/hash-strategies.md`
- Create: one `tools/bench/<site>-bench.nqp` per ruled site, named in the ruling (the census's expectations: a module-load benchmark for s1 is unlikely to be asked for; a deserialize-heavy one for s6 loads a precompiled module with large constant hashes `N` times; a HashAttrStore one binds and reads attributes of a class with many attributes)
- Record: `traces/llm/bench/internals-<site>-bench.md` per site

**Interfaces:** consumes `MVM_str_hash_build_strategy` (exists), `MVMHashStrategy` values; produces the macros, each resolving to `MVM_HASH_STRATEGY_DEFAULT` in C-engine builds.

- [ ] **Step 1: Site benchmark** per ruled site, with its TAP test, and the stats-build check that the site holds most of the benchmark's hash cycles.
- [ ] **Step 2: Switch, A/B** (two prefixes through `hash-ab.sh --ladder=<site>`, 7 rounds), decide by the win rule, record, plan row. A C-engine build (`-Dzig-impl=false`) still passes `zig build test`.
- [ ] **Step 3: Spectest gate** if s6 or any site reaching every program is kept (spec 5.3).
- [ ] **Step 4: Commit** MoarVM ("Internal str tables: <sites> on <strategies>"); traces and the pointer.

---

### Task 10: Whole-system acceptance, documentation, errata

**Files:**
- Modify: `docs/hash-strategies.md` (a "## Internal tables" section: the assignment table site / kind / layout / reason / benchmark record; the sentence "The other tables (pointer, fixkey, index, Unicode) always use their own layout" replaced by one pointing at that table; an `MVM_HASH_STATS` bullet under the override bullet), `docs/zig-build.md` (anything Tasks 1-9 left stale), the spec (errata: `codepointfromname`; `atexit` in place of "instance teardown"; the Header extension; any ruling that changed a section), this plan ("## Acceptance" table)
- Record: `traces/llm/bench/internals-final-spectest.txt`, `internals-final-ladder.md` (+ raw)

- [ ] **Step 1: Ladder guard, final.** Default build of HEAD into `tune-zig-prefix`; `hash-ab.sh --rounds=7 --sizes=4,16,32,63,64,65,128,256,1024,16384 --variant=base:internals-base-prefix/lib --variant=head:tune-zig-prefix/lib`, both ladders: within spread or 5 percent on every default-ladder cell (the user-hash path is untouched). Record `internals-final-ladder.md`.
- [ ] **Step 2: Spectest A/B.** Rakudo checkout, roast fb1d87214, `.precomp` removed, `TEST_JOBS=24`, stats off, order base HEAD HEAD base base HEAD (as `post-lto-spectest.txt`), each run `python3 tools/bench/timev.py <out>.time make spectest` under the variant's `LD_LIBRARY_PATH`, load recorded before each; medians of three per side; record `internals-final-spectest.txt` in the format of `bakeoff-final-spectest.txt` with the wall and RSS ratios and the sentence stating whether the 3 percent target was met.
- [ ] **Step 3: Suites.** `zig build unit-test`, `zig build test` (both `-Dzig-impl`, with and without `-Dhash-stats`), `zig build strategy-test -Dnqp-prefix=/tmp/claude-1000/tune-zig-prefix`, `prove tools/bench/t/`, `zig fmt --check` on every touched Zig file, `perl -c`, `sh -n`, `py_compile`.
- [ ] **Step 4: Docs and errata** as listed; the spec's status line gains "executed; see the plan's Acceptance".
- [ ] **Step 5: Acceptance table** in this plan: the spec's 9 criteria, verdict, evidence path each.
- [ ] **Step 6: Commit** MoarVM ("Internal hash tables: assignment docs, final acceptance"); traces ("internals: acceptance") and the pointer. Do not merge into `zig-hash-engine`; the user says when.

---

## Measurement conventions (for every task that measures)

Variants are libmoar builds in their own prefixes, run against `tune-zig-prefix`'s nqp and rakudo through `LD_LIBRARY_PATH`; rounds interleaved with the variant order rotated per round (`tools/bench/hash-ab.sh`); medians of at least 5 runs per round, spreads the min and max of round medians; load under 2.0 before a run and recorded; nothing judged from a single run; records in `traces/llm/bench/internals-*` with the header fields of `bakeoff-scoreboard.md` (date, shas, build flags, CPU, prefix, rounds, commands, load, raw files). Spectests from the rakudo checkout, `TEST_JOBS=24`, roast fb1d87214, timed with `tools/bench/timev.py` only where wall and RSS are part of the criterion.

## Survey

Task 5, 2026-11-03; full record `traces/llm/bench/internals-survey.md` (raw TSVs `internals-survey-w{1..4}.tsv`, overhead bound `internals-survey-overhead.md`). The spectest under the stats build passed (`Result: PASS`, Files=1365, 138715 tests; every test file left its stats file, loss 0). This is what the user rules on at the stop.

**Hash share of cycles** (counted on the stats build, so an upper bound; the lower bound applies the overhead factor 2.3 / 3.49): W1 startup 7.9 percent (3.6 / 2.4), W2 the core setting build 2.9 (1.3 / 0.8; the CORE.c compile alone 4.3, 1.9 / 1.3), W3 the spectest 4.4 (1.9 / 1.3), W4 uni-bench 11.1 (5.1 / 3.4).

**Layouts are chosen per table only at the build call, from the size known there; there is no mid-life switch.**

**Hot list and proposed assignment** (share of hash cycles W1 / W2 / W3; rule: 5 percent in any one of them, plus u1-u4):

- s5 MVMHash (63.4 / 81.7 / 81.3): stay on default, provisionally. Built with hint 0, so no size is known at the build call and no mid-life switch exists: a layout change would apply to every MVMHash. 0.14-4.1 percent of builds migrate past Small (the demolished-tables figure of 99.8 percent on Small undercounts: about 18.7M W3 tables, builds plus shallow copies, were alive at exit, and a unit test confirms `migrate` is counted once per migration). Caveat: these are shares of tables by size, not of the 940M W3 fetches by table size; the small minority of big tables could carry a disproportionate share. A measurement gap: the stop will offer a binned re-measurement; s5 is not settled. Growth is 13-26 percent of insert cycles (W2/W1; W3's 55 is contention-inflated), so the lever is a size hint or growth path. Judge: `hash-bench.nqp` sizes 4-64 plus an MVMHash-churn benchmark. Ruling needed: close the site, or open a presizing task.
- i2 lexical names (8.3 / 14.0 / 6.6): default for the 94.6-98.6 percent of tables at 64 entries or fewer (a share of tables, not of the 397M W3 fetches by table size; the binned re-measurement is offered at the stop). `num_lexicals` is known at the build call, so LOOKUP per frame at 65 or more is implementable; whether the 1.4-5.4 percent of frames justify it is the user's ruling. Judge: a lexical-lookup benchmark (to be written at the ruling) plus the C-API index-kind fetch ladder.
- i1 REPR registry (9.7, 6.0 without the stats-init artifact / 0.3 / 3.6, about 0.8 corrected): strike; a 47-key table built once per process, cold by decision 6, hot only by the 5 percent rule in W1.
- u1 property names (1.3 / 0.0 / 1.1; 38.2 in W4): LOOKUP (4380 entries). Judge: uni-bench `propcode_alias`/`propcode_hit`/`propcode_miss`.
- u3 codepoint names (- / - / 0.2; 34.1 in W4): LOOKUP plus a size hint (about 52K entries, 24 grows per build). Judge: uni-bench `cpbyname_hit`/`miss`/`miss_prefix`.
- u4 property values (9.1 / 0.4 / 3.6; 21.7 in W4): LOOKUP where the pre-counted size is 65 or more, default below (a per-build choice at the site: `MVM_unicode_init` can pre-count each of the 115 tables from the static array); size hint for the build (grows are 61 percent of its W1 cycles). Judge: uni-bench `pvalcode_hit`/`pvalcode_miss`.
- u2 sequence names (- / - / 0.0; 2.1 in W4): LOOKUP with u1. Judge: uni-bench `strfromname_seq`.

u1-u4 hold 97.48 percent of uni-bench's fetch operations (Task 4: 97.67). Cold and left on default: every f, s1, s6, p1, `other` (mostly misses on never-built MVMHash handles). Never seen: s2 s3 s4 s7 s8 s9 i3 p2.
