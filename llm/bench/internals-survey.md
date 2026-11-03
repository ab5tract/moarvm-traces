# Internal tables survey (2026-11-03)

Measurement only; no production code changed. Spec section 4 of
`traces/llm/specs/2026-11-03-zig-hash-internal-tables-design.md`, plan Task 5.

```
Date:        2026-11-03
MoarVM:      zig-hash-internals at 1919eddda (no source change; the aggregator needed no fix)
traces:      29be364 (parent of the "internals: survey" commit)
nqp/rakudo:  tune-zig-prefix's installs (rakudo checkout configured against it; roast fb1d87214)
Builds:      default  zig build install --prefix /tmp/claude-1000/tune-zig-prefix
                      zig build hash-bench-exe --prefix /tmp/claude-1000/tune-zig-prefix
             stats    zig build install --prefix /tmp/claude-1000/stats-zig-prefix -Dhash-stats=true
                      zig build hash-bench-exe --prefix /tmp/claude-1000/stats-zig-prefix -Dhash-stats=true
             (LTO default, x86-64-v3, after rm -f src/gen/config.{h,c,o}; the stats build adds -g and
              -Dstrip=false; the stats header is 16 bytes, so absolute cycle figures carry a small
              layout bias)
CPU:         AMD Ryzen 9 5900X 12-Core Processor (24 hardware threads)
Overhead:    stats/default per op, C API: fetch 2.07-3.49x, delete 1.96-2.35x, insert 1.16-1.75x,
             iterate 1.13-1.31x; nqp: fetch 1.46-2.26x, insert 1.11-1.44x, iterate 1.05-1.12x
             (internals-survey-overhead.md; central 2.3x for a fetch-dominated mix, worst cell 3.49x)
Load:        overhead rounds 1.05-1.13 (1-minute, before every run); W3 start 0.79; W1, W2, W4 are
             counter runs, not timed, load not gated (internals-survey-load.log)
Workloads:   every one ran tune-zig-prefix's binaries against the stats libmoar:
  LD_LIBRARY_PATH=/tmp/claude-1000/stats-zig-prefix/lib MVM_HASH_STATS=<scratch>/wN <command>
  W1  50 x raku -e '' (6 s) and 50 x nqp -e '' (1 s): 100 stats files
  W2  rakudo checkout: make clean; make (251 s): 78 files; then make install with the default lib (17 s)
  W3  TEST_JOBS=24 make spectest (347 s wallclock under the stats build): Result: PASS, Files=1365,
      Tests=138715; 2624 stats files; roast fb1d87214, t/spec/**/.precomp removed first
  W4  nqp-m tools/bench/uni-bench.nqp --runs=1 (2 s): 2 files
Aggregation: tools/bench/hash-stats.pl <dir> --lib=/tmp/claude-1000/stats-zig-prefix/lib/libmoar.so
             --census --tsv=traces/llm/bench/internals-survey-wN.tsv > internals-survey-wN-report.md
Raw:         internals-survey-w{1,2,3,4}.tsv (merged rows, labels in place of site ids),
             internals-survey-w{1,2,3,4}-report.md (the aggregator's own report), the overhead files,
             internals-survey-load.log
```

## What the numbers are and are not

- **Counted cycles include the counting.** Every figure below was measured on the stats build; each
  hooked call pays two `rdtsc` and the counter updates inside its window, so hash cycles, cycles per
  op and the hash share are all upper bounds. The overhead record bounds it: about +10 ns per call at
  the C API. Shares *between* sites are inflated unevenly (more for fetch-dominated sites such as u1-u4
  and i2, less for insert-dominated ones).
- **`other` (site 255) is mostly fetch misses on never-built MVMHash handles**, attributed to 255 by
  design: a lookup in a zero-filled MVMHash has no site id. It carries only fetch_miss, 0.7 to 1.8
  percent of hash cycles, and cannot be hot.
- **Insert cycles include any grow or migrate the insert triggered**; grow and migrate are also
  counted separately (rows marked "inside insert") and are not added to the shares.
- **Probe lengths are not measured** in this build (no hook calls `stats.probe`; no probe row is in any
  file); cycles per fetch stand in. Iteration (`iter_start`, `iter_step`) and `copy` are counted but
  carry no cycles, so iteration and shallow-copy cost is not in the hash cycles at all (see the
  s1/GC answer below for an estimate).
- **A shallow copy inherits the source's site**: s9 (MVMHash clone) is counted as `copy` on s5, and i3
  (static-frame clone) as `copy` on i2. s9 and i3 therefore have no section of their own beyond
  "absent"; s5 shows 18.1M copies in W3, i2 none in any workload.
- **W3 cycles are inflated by contention.** 24 jobs on 24 hardware threads (12 cores) with `rdtsc`
  counting wall cycles: a descheduled or SMT-slowed call is charged in full. Cycles per op in W3 are
  3 to 25 times W1's for the same op (s5 insert 1992 against 194; grow 26580 against 1122). Counts and
  *shares* are the usable W3 figures; the share of s5 agrees between W2 (single process at a time,
  81.7) and W3 (81.3).
- **The first counted use in each thread pays the stats layer's own setup** (the page-allocated
  per-thread counter block, the exit handler, the clock). In W1 and W3 that first use is i1's build
  (moar.c:182): 646K cycles per build against about 50 for any other build, 64.6M of i1's 159.6M
  site cycles in W1. That is an artifact of the survey build, not a hash cost; with it removed i1 is
  95M cycles, 6.0 percent of W1's hash cycles, still above the line.
- **W3 file count.** `make spectest` reported `Files=1365`. The stats files name 1365 distinct test
  files (1367 runs: two tests ran twice), so **no test file lost its dump; loss 0**. The other 1257 of the
  2624 files are non-test processes (308 `raku -e` by the aggregator's labelling, helper-package compiles
  with `--target=mbc` under t/spec/packages, `-I` module compiles, and so on); the harness itself (prove, perl) is not a
  MoarVM process and writes none. Processes killed before the exit handler cannot be counted and
  cannot be told from the list; none of the test files is missing, which is the part that matters.
  No file was malformed or header-only: the aggregator needed no change.
- **Not seen in any workload:** s2 (debug server only), s3 and s4 (no HashAttrStore table is ever built in these workloads), s7 and s8 (native callbacks), s9 and i3 (copies, counted on s5 and i2), p2 (heap
  snapshots). u3 appears in W3 (36 builds: the tests that look up codepoint names) and W4 only; u2
  in W3 (a few) and W4 only. p1 is live in all of W1-W3.

## Lookups by table size

Task 5b re-ran W1-W3 on a stats build that bins every fetch by the table's entry count
(`internals-survey-binned.md`; raw `internals-survey-binned-w{1,2,3}.tsv`; W3 passed again, Files=1365,
Result: PASS). Headline, shares of LOOKUPS above 64 entries (W1 / W2 / W3):

- s5: 16.2 / 47.4 / 26.8 percent of fetches, 23.8 / 53.6 / 35.1 percent of fetch cycles; above 128: 11.9 / 47.3 / 23.9 and 19.6 / 53.5 / 33.2.
- i2: 13.1 / 0.8 / 6.6 percent of fetches, 33.1 / 1.9 / 27.9 percent of fetch cycles; above 64 the fetches are 99.2 / 96.1 / 97.2 percent hits.

W3 cycles are contention-inflated, so the W3 cycle shares are shares within W3 only. The table-share
reading above (0.14-5.4 percent of tables big) understated the big tables' weight in lookups.

## Hot list

Rule (spec decision 6): a site is hot when it takes at least 5 percent of all hash-engine cycles in
any one of W1-W3 (unweighted; W4 is the unicode benchmark's check, not a fourth workload), plus u1-u4
regardless. Shares of hash cycles, by workload:

| site | W1 | W2 | W3 | W4 (benchmark) | hot because |
|---|---:|---:|---:|---:|---|
| s5 MVMHash | 63.4 | 81.7 | 81.3 | 3.0 | all three |
| i2 lexical names | 8.3 | 14.0 | 6.6 | 0.5 | all three |
| i1 REPR registry | 9.7 (6.0 without the stats-init artifact) | 0.3 | 3.6 | 0.1 | W1 only |
| u4 property values | 9.1 | 0.4 | 3.6 | 21.7 | W1, and u regardless |
| u1 property names | 1.3 | 0.0 | 1.1 | 38.2 | u regardless |
| u3 codepoint names | - | - | 0.2 | 34.1 | u regardless |
| u2 sequence names | - | - | 0.0 | 2.1 | u regardless |

Nearest misses, all cold by decision 6 and below the line: f8 syscalls 3.4 (W1), s6 deserialize 0.8
(W2), s1 SC weak hash 1.0 (W1), f1 1.3, f4 1.3, p1 0.5 (W3). `other` is 1.8 at most.

**Rule for per-table layout (controller ruling): a layout can be chosen per table only at the build call, keyed on the expected size known there. There is no mid-life switch.** Layout per site, from the bake-off scoreboard (`bakeoff-scoreboard.md`) and `docs/hash-strategies.md`:
Swiss (LOOKUP) wins fetch hit, fetch miss, insert and iterate from 65 entries up (lookup miss 0.80-0.83,
hit 0.88-0.99 (a win, ratio at most 0.9, only at 65-256; 0.93 at 1024 and 0.99 at 16384), insert 0.78-0.86 from 128 up (1.04 at 65), iterate 0.72); APPEND wins insert, iterate and
clone but loses delete (1.4-2.2x slower); nothing beat the default below 65. "Default" below means
the engine's own tiering (the Small rung, then the default layout).

| site | surveyed size range and op mix | suggested layout | benchmark that will judge it |
|---|---|---|---|
| **s5** MVMHash (`MVMHash_bind_key`) | Of the tables the GC demolished, 99.8 percent ended on the Small rung (at most 64 entries; 55 percent of W3's at 4 or fewer). That is a demolished-tables figure. The better estimate of how many tables outgrow Small is the migration rate, 0.14-4.1 percent of builds (W1 4.1, W2 0.14, W3 2.45). Migrations are bounded, not matched, by the demolish histogram: a migrated table is either demolished on rung 1 or still alive at exit. W3: 979K migrations against 89K rung-1 demolishes, with about 18.7M tables alive at exit (39.91M built plus 18.14M shallow copies, which inherit this site, minus 39.33M demolished), so the histogram undercounts migrated tables there; W2 (10,579 against 10,477, about 2.4M alive at exit) happens to be near equal. The count of `migrate` was checked: a unit test (`stats_test.zig`, 100 inserts from hint 0) counts exactly one migration and four grows, so there is no double count. Mix (W3 counts): insert 403M, fetch hit 651M, fetch miss 289M, overwrite 10M, delete 2.2M, iterate 40M starts / 550M steps, copy 18M. Insert is 73 (W1), 33 (W2) and 73 (W3) percent of the site's cycles, and inside the insert the grow/migrate is 26 percent (W1) and 13 (W2); W3's 55 is a contention-inflated outlier (26,580 cycles per grow against 1,122 in W1). **Lookups by table size (measured, `internals-survey-binned.md`): tables above 64 entries take 16.2 / 47.4 / 26.8 percent of s5's fetches and 23.8 / 53.6 / 35.1 percent of its fetch cycles (W1 / W2 / W3); above 128 entries 11.9 / 47.3 / 23.9 percent of fetches and 19.6 / 53.5 / 33.2 percent of cycles. Above 64 the fetches are 45.1 / 97.0 / 76.2 percent hits. The few big tables carry a large share of the lookups. W3 cycle shares are shares within W3 only (contention-inflated).** | **Default as a per-table rule, but no longer settled by the table shares.** The site builds with hint 0, so no size is known at the build call, and no mid-life switch exists: a layout change would apply to every MVMHash, almost all of which are in the range where nothing beat the default. The measured lookup shares (up to 54 percent of fetch cycles on tables above 64) put a LOOKUP win of 0.88-0.99 on hits within reach of up to half the site's fetch cycles; whether that justifies anything without a build-time size is the user's ruling. The lever the numbers show for growth (13-26 percent of insert cycles, W2/W1) is a growth path or size hint at `bind_key`'s lazy build, a separate ruling. | nqp-level: `hash-bench.nqp` at sizes 4-64 (the default ladder, as the guard) plus an MVMHash-churn benchmark named at the ruling (build, bind 1-16 keys, read, drop; the shape of slurpy-named-arg and `Map` storage); C API: `hash-bench` at the same sizes |
| **i2** lexical names (`MVM_bytecode_finish_frame`) | Sealable, presized exactly at deserialization, only fetched after. 94.6-98.6 percent of tables hold 64 or fewer entries (a table is built only above 5 lexicals, `bytecode.c:667`); W3: 274M hits and 123M misses against 19M inserts. Misses are 31-37 percent of fetches in W2-W3 (outer-frame walk) and 2 percent in W1. **Lookups by table size (measured, `internals-survey-binned.md`): tables above 64 entries take 13.1 / 0.8 / 6.6 percent of i2's fetches and 33.1 / 1.9 / 27.9 percent of its fetch cycles (W1 / W2 / W3); the same above 128. Above 64 the fetches are hit-dominated: 99.2 / 96.1 / 97.2 percent hits (the misses are on the small tables). W3 cycle shares are shares within W3 only (contention-inflated).** | **Default for the 94.6-98.6 percent** (nothing beat it below 65). `num_lexicals` is known at the build call, so a per-frame choice (LOOKUP where it is 65 or more) is implementable. Whether the 1.4-5.4 percent of frames at 65 and up justify it (they carry 1.9-33.1 percent of the site's fetch cycles, almost all hits; hit 0.88-0.99 of the default's ns) is the user's ruling. | a lexical-lookup benchmark to be written at the ruling: nqp code with N nested lexical scopes of 6-200 lexicals and a loop of `nqp::getlexdyn`/`getlex` by name (misses through outer frames); C API: a fetch-only ladder on the index kind at 16, 64, 65, 128 |
| **i1** REPR registry | 47 core REPRs in one table (`<=64` bucket), built and filled once per process; 2640 fetches per process at startup (350 cycles each, cold). Its W1 share is 6.0 percent without the stats-init artifact; in W3 the artifact is just as large (the build is about 78 percent of i1's W3 cycles, 38.5G of 49.0G), so the corrected W3 share is about 0.8 percent, not 3.6; W2 0.3. | **Default.** Strike from the hot list at the stop: the table is built once, startup-only (0.8 percent of W1's total cycles, about 0.4 without the artifact), and a 47-key table is under the 65 threshold. | startup wall (`raku -e ''`, `hash-ab.sh` ladder) if the user keeps it |
| **u4** property values (`MVM_unicode_init`) | 115 tables built with hint 0, 5058 inserts per process (avg 44 per table; census: 5164 values), sealable, then fetch only (50 percent misses in W4). Grows 144 times per process (6370 cycles each) because there is no hint: 61 percent of the site's W1 cycles. | Per build: LOOKUP where the pre-counted size is 65 or more, default below (a per-build choice at the site: `MVM_unicode_init` can pre-count each of the 115 property tables from the static array before building it). The size distribution is not measured (the tables live to teardown and leave no demolish row; the average is 44, so most are probably under 65), but the pre-count makes it known at the build. A size hint at the same call is the cheaper lever for the grows. | uni-bench (property-value lookups, `pvalcode_hit`/`pvalcode_miss` rows) and its C-API twin |
| **u1** property names (`generate_property_codes_by_names_aliases`) | one table, hint 4380, 4380 inserts, then fetch: W4 7.47M hits and 3.36M misses at 68 and 57 cycles; startup-lazy (built in 50 of 100 W1 processes (raku only), 2615 times across W3's 2624 files). | **LOOKUP**: 4380 entries is in the range where the scoreboard's 1024 and 16384 cells give hit 0.93 and 0.99 (not a win by the 0.9 rule) and miss 0.83 (a win); 4380 lies between them | uni-bench (`propcode_alias`, `propcode_hit`, `propcode_miss`) and `hash-ab.sh --ladder=uni` |
| **u3** codepoint names (`generate_codepoints_by_name`) | one table of about 52K entries (1.87M inserts over 36 builds in W3; 103.7K over 2 in W4), hint 0 so it grows 24 times (2.1G cycles of the 2.5G insert cycles in W3, 395K cycles per grow in W4), then fetch with a real miss path (57 percent misses in W4). | **LOOKUP**, plus a size hint at the implicit build (a one-line change in the same task; its 24 grows per build are most of the site's cycles in W3: 2.1G of 2.5G) | uni-bench (`cpbyname_hit`, `cpbyname_miss`, `cpbyname_miss_prefix` rows) |
| **u2** sequence names | one table, hint 3680, fetch only (`strfromname_seq`); 2.1 percent in W4 and absent from W1-W2. | **LOOKUP** with u1 (same shape), no separate benchmark beyond uni-bench | uni-bench `strfromname_seq` |

### W4: does the benchmark drive u1-u4?

Re-run on this build (stats lib, `--runs=1`): u1 + u2 + u3 + u4 hold **97.48 percent** of
`fetch_hit + fetch_miss` operations (24,846,242 of 25,488,501), per site u1 42.47, u3 29.03, u4 24.67,
u2 1.31; the rest is s5 1.83, i2 0.53, `other` 0.15. Task 4 recorded 97.67 percent; the 0.19-point
difference is the run itself (process startup counts and run-to-run variation of the benchmark's own
setup), not a change of build. By hash cycles u1-u4 are 96.1 percent of W4.

## Hash share

Hash cycles over the process's total cycles, from the aggregator's `## Hash share` (counted cycles on
the stats build). **The counted cycles include the counting**, so the measured share is an upper
bound. The lower bound applies the overhead factor of internals-survey-overhead.md: hash cycles
divided by f, total cycles reduced by the same amount (all the counting cost is assumed to lie inside the
counted window, which makes the bound conservative). f = 2.3 is the fetch-dominated C-API figure (it understates the correction for insert-dominated sites such as s5, 59-73 percent inserts, whose overhead is 1.2-1.7x, so for them the 3.49 column is the safe bound),
f = 3.49 the worst cell.

| workload | measured (upper bound) | f = 2.3 | f = 3.49 (lower bound) | hash cycles / total cycles |
|---|---:|---:|---:|---|
| W1 startup, all 100 processes | 7.9 | 3.6 | 2.4 | 1.64G / 20.95G |
| W1 `raku -e ''` | 7.6 | 3.5 | 2.3 | 1.37G / 17.91G |
| W1 `nqp -e ''` | 9.2 | 4.2 | 2.8 | 0.28G / 3.04G |
| W2 the core setting build, all 78 processes | 2.9 | 1.3 | 0.8 | 26.56G / 915.6G |
| W2 CORE.c.setting compile alone (the dominant process) | 4.3 | 1.9 | 1.3 | 15.42G / 355.2G |
| W3 the spectest, all 2624 processes | 4.4 | 1.9 | 1.3 | 1352G / 31071G |
| W4 uni-bench (benchmark, not a workload) | 11.1 | 5.1 | 3.4 | 1.83G / 16.58G |

So the hash engine, as the survey build sees it, is 3 to 8 percent of the cycles of startup, the
setting build and the spectest, and by the overhead-adjusted bounds roughly 1 to 4 percent (0.8-4.2). The
whole-system gate of the plan (the 3 percent target of decision 8) is of the same order as the
hash share itself: a per-site layout change cannot move whole-system wall time by more than the
site's share of that, for instance s5's 81 percent of 4.4 is 3.5 percent of W3's cycles and at most
about 1.5 percent after the overhead adjustment. Iteration and copy cycles are not in the hash cycles
(see above): s5's 550M iterator steps in W3 at an assumed 40 cycles per step (an assumption, not measured) would add about 22G, 0.07 percent of
W3's cycles, and do not change the picture.

## The census's open questions

1. **Are the lexical-name tables mostly below 65 entries?** Yes, by table count. i2 builds with
   64 or fewer entries: **97.5 percent in W1** (19,700 of 20,200), **94.6 in W2** (4,458 of 4,713),
   **98.6 in W3** (1,588,111 of 1,610,755). Most are in the `<=16` bucket (87 percent in W1, 82 in W2,
   92 in W3). By lookups (Task 5b): 0.8-13.1 percent of fetches and 1.9-33.1 percent of fetch cycles are on tables above 64; the 1.4-5.4 percent
   of tables at 65 and up are the only ones where the scoreboard's layouts can win. Where nothing
   beat the default, the default stays: i2 is hot by volume (6.6-14.0 percent of hash cycles) but
   not by layout.
2. **How often do MVMHash tables grow past Small?** Rarely. Rung migrations over builds for s5:
   **4.1 percent in W1** (9,900 of 241,250), **0.14 in W2** (10,579 of 7.64M), **2.45 in W3**
   (979,329 of 39.9M). Of the tables the GC demolished with their maximum recorded, **0.19 percent in
   W2 and 0.23 in W3** ended on the second rung (W1 demolishes none: processes end before a table is
   freed). Every build is a hint-0 lazy build (`<=4`), so nearly all of s5's growth is within the Small
   rung: 187,747 grows in W2 and 16.7M in W3 (0.42 per build), which are 13 percent (W2) of s5's insert cycles (W3's 55 percent is contention-inflated; W1 26). Growing is where s5's insert cycles go, not the layout.
3. **Is the SC weak hash's per-GC iteration visible?** In counts, yes; in cycles, not measurably. s1
   (the `sc_weakhash`, iterated every GC to mark keys) shows 0 iterations in W1, 1,733 starts and 40.8K
   steps in W2, 12.6K starts and **3.27M steps in W3** (about 260 entries per iteration), 8 starts in
   W4. Iteration cycles are not counted; at an assumed 40 cycles per step (not measured) that is about 130M cycles, 0.0004
   percent of W3's total, against s1's counted 3.68G (0.3 percent of hash cycles). Its real cost is
   the mutexed insert, overwrite and fetch path: 2700 cycles per insert and overwrite in W3 against
   760 in W1 (lock contention and contention-inflated cycles), still 0.3 percent of hash cycles.
   s1 is cold.

## Sites, in census order

Per cell: count / cycles / cycles per op. Shares are of the workload's hash cycles and of its total cycles (W3's cycles are contention-inflated, see above). The lifetime class is derived from the counters: "no rung migration counted" does not mean the table is small (u1-u3 hold 4,380 to 52K entries and are never demolished; uni and index tables have no Small rung to leave). Bucket labels are the ladder: `<=4 <=16 <=32 <=64 <=65 <=128 <=256 <=1024 <=16384 more`; build size is the size hint requested, demolish is the maximum item count of a demolished table by set and rung (rung 0 = Small). No demolish row means no table of the site was freed by the GC before exit.

### s1 MVM_vm_create_instance (src/moar.c:203)

| op | W1 count / cycles / cycles per op | W2 count / cycles / cycles per op | W3 count / cycles / cycles per op | W4 count / cycles / cycles per op |
|---|---|---|---|---|
| build | 100 / 13.0K / 129.9 | 78 / 17.1K / 219.6 | 2624 / 446.5K / 170.2 | 2 / 555 / 277.5 |
| insert | 2150 / 1.63M / 756.1 | 1082 / 834.2K / 771.0 | 148.3K / 400.74M / 2701.4 | 26 / 19.5K / 748.5 |
| overwrite | 8250 / 6.29M / 762.9 | 7599 / 8.74M / 1150.6 | 728.3K / 1.97G / 2698.1 | 76 / 61.5K / 809.6 |
| fetch_hit | 14.6K / 8.74M / 598.7 | 5003 / 2.77M / 553.3 | 648.3K / 1.25G / 1934.0 | 102 / 58.0K / 568.8 |
| delete_hit | - | - | 52.8K / 62.38M / 1181.2 | - |
| iter_start | - | 1733 / 0 / 0.0 | 12.6K / 0 / 0.0 | 8 / 0 / 0.0 |
| iter_step | - | 40.8K / 0 / 0.0 | 3.27M / 0 / 0.0 | 104 / 0 / 0.0 |
| grow (inside insert) | 150 / 51.8K / 345.3 | 84 / 27.7K / 329.5 | 5845 / 65.67M / 11235.0 | 2 / 555 / 277.5 |
| migrate (inside insert) | - | - | 44 / 1.70M / 38733.1 | - |
| **site cycles** | 16.67M | 12.36M | 3.68G | 139.6K |
| **% of hash cycles** | 1.0 | 0.0 | 0.3 | 0.0 |
| **% of total cycles** | 0.1 | 0.0 | 0.0 | 0.0 |

- W1 build size: <=4=100
- W1 demolish: none recorded
- W2 build size: <=4=78
- W2 demolish: none recorded
- W3 build size: <=4=2624
- W3 demolish: none recorded
- W4 build size: <=4=2
- W4 demolish: none recorded

Lifetime class:
- W1: built-and-never-deleted; no rung migration counted
- W2: built-and-never-deleted; no rung migration counted
- W3: churning (52.8K deletes against 148.3K inserts); grew past the Small rung (44 migrations in 2624 builds, 1.68%)
- W4: built-and-never-deleted; no rung migration counted

### s2 [census: bytecode.c:777 debug locals (debug server only)]

Absent in all four workloads.

### s3 [census: HashAttrStore.c:33 copy_to]

Absent in all four workloads.

### s4 [census: HashAttrStore.c:96 bind_attribute]

Absent in all four workloads.

### s5 MVMHash_bind_key (src/6model/reprs/MVMHash.c:115)

| op | W1 count / cycles / cycles per op | W2 count / cycles / cycles per op | W3 count / cycles / cycles per op | W4 count / cycles / cycles per op |
|---|---|---|---|---|
| build | 241.2K / 12.89M / 53.4 | 7.64M / 434.68M / 56.9 | 39.91M / 13.29G / 333.0 | 45.5K / 2.22M / 48.8 |
| insert | 3.93M / 764.20M / 194.3 | 17.57M / 7.16G / 407.3 | 402.54M / 801.70G / 1991.6 | 92.9K / 20.27M / 218.1 |
| overwrite | 14.7K / 1.49M / 101.7 | 1.70M / 151.09M / 88.9 | 10.40M / 4.09G / 393.6 | 1028 / 70.4K / 68.5 |
| fetch_hit | 1.78M / 182.65M / 102.5 | 123.32M / 11.96G / 97.0 | 651.15M / 215.35G / 330.7 | 381.9K / 27.60M / 72.3 |
| fetch_miss | 944.8K / 81.18M / 85.9 | 21.97M / 1.90G / 86.6 | 289.15M / 63.34G / 219.1 | 85.4K / 5.08M / 59.5 |
| delete_hit | 300 / 111.9K / 373.0 | 916.5K / 97.53M / 106.4 | 1.75M / 702.72M / 401.3 | 3818 / 293.6K / 76.9 |
| delete_miss | 1150 / 226.4K / 196.9 | 5043 / 4.45M / 883.1 | 474.3K / 126.83M / 267.4 | - |
| iter_start | 12.7K / 0 / 0.0 | 14.94M / 0 / 0.0 | 39.84M / 0 / 0.0 | 10.1K / 0 / 0.0 |
| iter_step | 62.5K / 0 / 0.0 | 91.34M / 0 / 0.0 | 549.79M / 0 / 0.0 | 25.0K / 0 / 0.0 |
| copy | 1550 / 0 / 0.0 | 345.4K / 0 / 0.0 | 18.14M / 0 / 0.0 | 20 / 0 / 0.0 |
| grow (inside insert) | 174.8K / 196.07M / 1121.6 | 187.7K / 919.15M / 4895.7 | 16.67M / 443.04G / 26580.0 | 641 / 1.34M / 2089.9 |
| migrate (inside insert) | 9900 / 60.24M / 6084.4 | 10.6K / 74.67M / 7058.4 | 979.3K / 93.39G / 95366.2 | 42 / 171.5K / 4084.1 |
| demolish | - | 5.62M / 0 / 0.0 | 39.33M / 0 / 0.0 | 44.9K / 0 / 0.0 |
| **site cycles** | 1.04G | 21.71G | 1098.60G | 55.53M |
| **% of hash cycles** | 63.4 | 81.7 | 81.3 | 3.0 |
| **% of total cycles** | 5.0 | 2.4 | 3.5 | 0.3 |

- W1 build size: <=4=241250
- W1 demolish: none recorded
- W2 build size: <=4=7641481
- W2 demolish max items, set 0 rung 0: <=4=5183080 <=16=371249 <=32=50781 <=64=6271
- W2 demolish max items, set 0 rung 1: <=65=101 <=128=3250 <=256=4720 <=1024=2377 <=16384=29
- W3 build size: <=4=39905612
- W3 demolish max items, set 0 rung 0: <=4=21616652 <=16=17165683 <=32=360704 <=64=102193
- W3 demolish max items, set 0 rung 1: <=65=213 <=128=80532 <=256=4686 <=1024=3574 <=16384=6
- W4 build size: <=4=45478
- W4 demolish max items, set 0 rung 0: <=4=44257 <=16=589 <=32=24 <=64=14
- W4 demolish max items, set 0 rung 1: <=128=8 <=256=2

Lifetime class:
- W1: churning (1450 deletes against 3.93M inserts); grew past the Small rung (9900 migrations in 241.2K builds, 4.10%)
- W2: churning (921.6K deletes against 17.57M inserts); grew past the Small rung (10.6K migrations in 7.64M builds, 0.14%)
- W3: churning (2.23M deletes against 402.54M inserts); grew past the Small rung (979.3K migrations in 39.91M builds, 2.45%)
- W4: churning (3818 deletes against 92.9K inserts); grew past the Small rung (42 migrations in 45.5K builds, 0.09%)

### s6 deserialize (src/6model/reprs/MVMHash.c:192)

| op | W1 count / cycles / cycles per op | W2 count / cycles / cycles per op | W3 count / cycles / cycles per op | W4 count / cycles / cycles per op |
|---|---|---|---|---|
| build | 250 / 58.0K / 231.9 | 163 / 107.2K / 657.8 | 57.6K / 342.09M / 5938.6 | 2 / 555 / 277.5 |
| insert | 900 / 148.5K / 165.0 | 4608 / 1.17M / 253.4 | 643.0K / 210.35M / 327.2 | 6 / 2220 / 370.0 |
| overwrite | - | 242 / 67.9K / 280.6 | 6497 / 2.78M / 428.4 | - |
| fetch_hit | 1800 / 126.5K / 70.3 | 519.1K / 88.57M / 170.6 | 1.72M / 790.53M / 459.9 | 12 / 2812 / 234.3 |
| fetch_miss | 100 / 26.2K / 261.6 | 1.33M / 113.69M / 85.5 | 7.45M / 2.89G / 387.8 | - |
| iter_start | - | 525 / 0 / 0.0 | 11.8K / 0 / 0.0 | - |
| iter_step | - | 21.0K / 0 / 0.0 | 464.0K / 0 / 0.0 | - |
| grow (inside insert) | - | - | 108 / 37.2K / 344.6 | - |
| **site cycles** | 359.2K | 203.60M | 4.24G | 5587 |
| **% of hash cycles** | 0.0 | 0.8 | 0.3 | 0.0 |
| **% of total cycles** | 0.0 | 0.0 | 0.0 | 0.0 |

- W1 build size: <=4=200 <=16=50
- W1 demolish: none recorded
- W2 build size: <=4=64 <=16=70 <=32=11 <=64=3 <=256=15
- W2 demolish: none recorded
- W3 build size: <=4=23982 <=16=24335 <=32=5189 <=64=3246 <=256=850 <=16384=2
- W3 demolish: none recorded
- W4 build size: <=4=2
- W4 demolish: none recorded

Lifetime class:
- W1: built-and-never-deleted; no rung migration counted
- W2: built-and-never-deleted; no rung migration counted
- W3: built-and-never-deleted; no rung migration counted
- W4: built-and-never-deleted; no rung migration counted

### s7 [census: nativecall_libffi.c:85 callback cache]

Absent in all four workloads.

### s8 [census: nativecall_dyncall.c:91 callback cache]

Absent in all four workloads.

### s9 [census: MVMHash.c:40 copy_to (shallow copy)]

Absent in all four workloads.

### u1 generate_property_codes_by_names_aliases (src/strings/unicode_ops.c:915)

| op | W1 count / cycles / cycles per op | W2 count / cycles / cycles per op | W3 count / cycles / cycles per op | W4 count / cycles / cycles per op |
|---|---|---|---|---|
| build | 50 / 1.04M / 20774.8 | 3 / 714.2K / 238070.3 | 2615 / 13.15G / 5027229.2 | 2 / 38.2K / 19110.5 |
| insert | 219.0K / 20.83M / 95.1 | 13.1K / 1.33M / 101.2 | 11.45M / 2.19G / 191.0 | 8760 / 1.00M / 114.7 |
| fetch_hit | 100 / 30.4K / 304.1 | 534 / 126.7K / 237.3 | 15.4K / 25.79M / 1679.8 | 7.47M / 508.91M / 68.1 |
| fetch_miss | - | - | 20 / 11.6K / 580.9 | 3.36M / 190.23M / 56.7 |
| grow (inside insert) | 50 / 26.0K / 521.0 | 3 / 2035 / 678.3 | 2615 / 4.22M / 1612.5 | 2 / 3478 / 1739.0 |
| **site cycles** | 21.90M | 2.17M | 15.36G | 700.18M |
| **% of hash cycles** | 1.3 | 0.0 | 1.1 | 38.2 |
| **% of total cycles** | 0.1 | 0.0 | 0.0 | 4.2 |

- W1 build size: <=16384=50
- W1 demolish: none recorded
- W2 build size: <=16384=3
- W2 demolish: none recorded
- W3 build size: <=16384=2615
- W3 demolish: none recorded
- W4 build size: <=16384=2
- W4 demolish: none recorded

Lifetime class:
- W1: built-and-never-deleted; no rung migration counted
- W2: built-and-never-deleted; no rung migration counted
- W3: built-and-never-deleted; no rung migration counted
- W4: built-and-never-deleted; no rung migration counted

### u2 generate_property_codes_by_seq_names (src/strings/unicode_ops.c:930)

| op | W1 count / cycles / cycles per op | W2 count / cycles / cycles per op | W3 count / cycles / cycles per op | W4 count / cycles / cycles per op |
|---|---|---|---|---|
| build | - | - | 4 / 102.2K / 25557.8 | 2 / 9361 / 4680.5 |
| insert | - | - | 14.7K / 1.45M / 98.5 | 7360 / 622.7K / 84.6 |
| fetch_hit | - | - | 5 / 9694 / 1938.8 | 334.5K / 38.75M / 115.8 |
| fetch_miss | - | - | 12 / 4884 / 407.0 | - |
| **site cycles** | - | - | 1.57M | 39.38M |
| **% of hash cycles** | - | - | 0.0 | 2.1 |
| **% of total cycles** | - | - | 0.0 | 0.2 |

- W1 build size: (no builds)
- W1 demolish: none recorded
- W2 build size: (no builds)
- W2 demolish: none recorded
- W3 build size: <=16384=4
- W3 demolish: none recorded
- W4 build size: <=16384=2
- W4 demolish: none recorded

Lifetime class:
- W1: absent in this workload
- W2: absent in this workload
- W3: built-and-never-deleted; no rung migration counted
- W4: built-and-never-deleted; no rung migration counted

### u3 generate_codepoints_by_name (src/strings/unicode_db.c:129559)

| op | W1 count / cycles / cycles per op | W2 count / cycles / cycles per op | W3 count / cycles / cycles per op | W4 count / cycles / cycles per op |
|---|---|---|---|---|
| build | - | - | 36 / 62.2K / 1728.7 | 2 / 185 / 92.5 |
| insert | - | - | 1.87M / 2.54G / 1360.1 | 103.7K / 31.89M / 307.4 |
| fetch_hit | - | - | 1836 / 3.59M / 1955.0 | 3.15M / 319.99M / 101.6 |
| fetch_miss | - | - | 17 / 20.1K / 1184.0 | 4.25M / 273.41M / 64.3 |
| grow (inside insert) | - | - | 864 / 2.10G / 2431859.7 | 48 / 18.98M / 395335.0 |
| **site cycles** | - | - | 2.54G | 625.30M |
| **% of hash cycles** | - | - | 0.2 | 34.1 |
| **% of total cycles** | - | - | 0.0 | 3.8 |

- W1 build size: (no builds)
- W1 demolish: none recorded
- W2 build size: (no builds)
- W2 demolish: none recorded
- W3 build size: <=4=36
- W3 demolish: none recorded
- W4 build size: <=4=2
- W4 demolish: none recorded

Lifetime class:
- W1: absent in this workload
- W2: absent in this workload
- W3: built-and-never-deleted; no rung migration counted
- W4: built-and-never-deleted; no rung migration counted

### u4 MVM_unicode_init (src/strings/unicode_ops.c:959)

| op | W1 count / cycles / cycles per op | W2 count / cycles / cycles per op | W3 count / cycles / cycles per op | W4 count / cycles / cycles per op |
|---|---|---|---|---|
| build | 11.5K / 430.5K / 37.4 | 8970 / 350.5K / 39.1 | 301.8K / 27.38M / 90.7 | 230 / 9086 / 39.5 |
| insert | 505.8K / 146.38M / 289.4 | 394.5K / 116.51M / 295.3 | 13.27M / 47.83G / 3604.1 | 10.1K / 2.76M / 272.9 |
| overwrite | 26.6K / 2.65M / 99.6 | 20.7K / 2.12M / 102.3 | 698.0K / 134.07M / 192.1 | 532 / 52.2K / 98.1 |
| fetch_hit | - | 524 / 167.9K / 320.5 | 9644 / 10.26M / 1064.2 | 3.14M / 231.79M / 73.7 |
| fetch_miss | - | - | 66 / 28.6K / 433.9 | 3.14M / 163.24M / 51.9 |
| grow (inside insert) | 14.4K / 91.73M / 6370.5 | 11.2K / 71.77M / 6390.1 | 377.9K / 45.19G / 119596.7 | 288 / 1.63M / 5645.9 |
| **site cycles** | 149.46M | 119.15M | 48.01G | 397.85M |
| **% of hash cycles** | 9.1 | 0.4 | 3.6 | 21.7 |
| **% of total cycles** | 0.7 | 0.0 | 0.2 | 2.4 |

- W1 build size: <=4=11500
- W1 demolish: none recorded
- W2 build size: <=4=8970
- W2 demolish: none recorded
- W3 build size: <=4=301760
- W3 demolish: none recorded
- W4 build size: <=4=230
- W4 demolish: none recorded

Lifetime class:
- W1: never looked up; built-and-never-deleted; no rung migration counted
- W2: built-and-never-deleted; no rung migration counted
- W3: built-and-never-deleted; no rung migration counted
- W4: built-and-never-deleted; no rung migration counted

### f1 MVM_vm_create_instance (src/moar.c:186)

| op | W1 count / cycles / cycles per op | W2 count / cycles / cycles per op | W3 count / cycles / cycles per op | W4 count / cycles / cycles per op |
|---|---|---|---|---|
| build | 100 / 67.0K / 670.4 | 78 / 53.3K / 683.1 | 2624 / 60.25M / 22960.7 | 2 / 1295 / 647.5 |
| insert | 150 / 47.0K / 313.5 | 88 / 34.7K / 394.0 | 5240 / 6.31M / 1204.0 | 2 / 962 / 481.0 |
| overwrite | 251.2K / 21.02M / 83.7 | 56.8K / 8.77M / 154.3 | 15.08M / 6.56G / 435.3 | 276 / 45.0K / 163.1 |
| **site cycles** | 21.14M | 8.85M | 6.63G | 47.3K |
| **% of hash cycles** | 1.3 | 0.0 | 0.5 | 0.0 |
| **% of total cycles** | 0.1 | 0.0 | 0.0 | 0.0 |

- W1 build size: <=4=100
- W1 demolish: none recorded
- W2 build size: <=4=78
- W2 demolish: none recorded
- W3 build size: <=4=2624
- W3 demolish: none recorded
- W4 build size: <=4=2
- W4 demolish: none recorded

Lifetime class:
- W1: never looked up; built-and-never-deleted; no rung migration counted
- W2: never looked up; built-and-never-deleted; no rung migration counted
- W3: never looked up; built-and-never-deleted; no rung migration counted
- W4: never looked up; built-and-never-deleted; no rung migration counted

### f2 MVM_vm_create_instance (src/moar.c:187)

| op | W1 count / cycles / cycles per op | W2 count / cycles / cycles per op | W3 count / cycles / cycles per op | W4 count / cycles / cycles per op |
|---|---|---|---|---|
| build | 100 / 3449 / 34.5 | 78 / 2599 / 33.3 | 2624 / 119.7K / 45.6 | 2 / 74 / 37.0 |
| **site cycles** | 3449 | 2599 | 119.7K | 74 |
| **% of hash cycles** | 0.0 | 0.0 | 0.0 | 0.0 |
| **% of total cycles** | 0.0 | 0.0 | 0.0 | 0.0 |

- W1 build size: <=4=100
- W1 demolish: none recorded
- W2 build size: <=4=78
- W2 demolish: none recorded
- W3 build size: <=4=2624
- W3 demolish: none recorded
- W4 build size: <=4=2
- W4 demolish: none recorded

Lifetime class:
- W1: never looked up; built-and-never-deleted
- W2: never looked up; built-and-never-deleted
- W3: never looked up; built-and-never-deleted
- W4: never looked up; built-and-never-deleted

### f3 MVM_vm_create_instance (src/moar.c:191)

| op | W1 count / cycles / cycles per op | W2 count / cycles / cycles per op | W3 count / cycles / cycles per op | W4 count / cycles / cycles per op |
|---|---|---|---|---|
| build | 100 / 3304 / 33.0 | 78 / 2346 / 30.1 | 2624 / 133.6K / 50.9 | 2 / 74 / 37.0 |
| insert | 50 / 16.9K / 338.9 | 4 / 1369 / 342.2 | 2624 / 2.08M / 793.9 | - |
| fetch_hit | 17.9K / 1.85M / 103.4 | 62.2K / 18.15M / 291.7 | 1.76M / 751.27M / 427.4 | - |
| fetch_miss | 50 / 25.2K / 503.2 | 4 / 2035 / 508.8 | 2624 / 3.96M / 1509.0 | - |
| **site cycles** | 1.90M | 18.16M | 757.44M | 74 |
| **% of hash cycles** | 0.1 | 0.1 | 0.1 | 0.0 |
| **% of total cycles** | 0.0 | 0.0 | 0.0 | 0.0 |

- W1 build size: <=4=100
- W1 demolish: none recorded
- W2 build size: <=4=78
- W2 demolish: none recorded
- W3 build size: <=4=2624
- W3 demolish: none recorded
- W4 build size: <=4=2
- W4 demolish: none recorded

Lifetime class:
- W1: built-and-never-deleted; no rung migration counted
- W2: built-and-never-deleted; no rung migration counted
- W3: built-and-never-deleted; no rung migration counted
- W4: never looked up; built-and-never-deleted

### f4 MVM_vm_create_instance (src/moar.c:195)

| op | W1 count / cycles / cycles per op | W2 count / cycles / cycles per op | W3 count / cycles / cycles per op | W4 count / cycles / cycles per op |
|---|---|---|---|---|
| build | 100 / 3451 / 34.5 | 78 / 2490 / 31.9 | 2624 / 238.3K / 90.8 | 2 / 74 / 37.0 |
| insert | 50 / 4107 / 82.1 | 4 / 333 / 83.2 | 2624 / 671.3K / 255.8 | - |
| fetch_hit | 17.9K / 20.88M / 1169.8 | 62.2K / 109.89M / 1766.0 | 1.76M / 4.27G / 2435.6 | - |
| fetch_miss | 50 / 56.0K / 1120.4 | 4 / 4773 / 1193.2 | 2624 / 4.92M / 1873.3 | - |
| **site cycles** | 20.95M | 109.90M | 4.28G | 74 |
| **% of hash cycles** | 1.3 | 0.4 | 0.3 | 0.0 |
| **% of total cycles** | 0.1 | 0.0 | 0.0 | 0.0 |

- W1 build size: <=4=100
- W1 demolish: none recorded
- W2 build size: <=4=78
- W2 demolish: none recorded
- W3 build size: <=4=2624
- W3 demolish: none recorded
- W4 build size: <=4=2
- W4 demolish: none recorded

Lifetime class:
- W1: built-and-never-deleted; no rung migration counted
- W2: built-and-never-deleted; no rung migration counted
- W3: built-and-never-deleted; no rung migration counted
- W4: never looked up; built-and-never-deleted

### f5 MVM_vm_create_instance (src/moar.c:199)

| op | W1 count / cycles / cycles per op | W2 count / cycles / cycles per op | W3 count / cycles / cycles per op | W4 count / cycles / cycles per op |
|---|---|---|---|---|
| build | 100 / 3860 / 38.6 | 78 / 3453 / 44.3 | 2624 / 217.7K / 83.0 | 2 / 38 / 19.0 |
| insert | 500 / 82.8K / 165.5 | 40 / 7917 / 197.9 | 26.2K / 9.28M / 353.5 | - |
| fetch_hit | 150 / 270.6K / 1804.1 | 9 / 16.1K / 1788.3 | 7985 / 78.88M / 9878.0 | - |
| fetch_miss | 500 / 103.2K / 206.4 | 40 / 8066 / 201.7 | 26.2K / 9.41M / 358.5 | - |
| grow (inside insert) | 50 / 29.2K / 583.1 | 4 / 3552 / 888.0 | 2625 / 4.48M / 1706.0 | - |
| **site cycles** | 460.4K | 35.5K | 97.78M | 38 |
| **% of hash cycles** | 0.0 | 0.0 | 0.0 | 0.0 |
| **% of total cycles** | 0.0 | 0.0 | 0.0 | 0.0 |

- W1 build size: <=4=100
- W1 demolish: none recorded
- W2 build size: <=4=78
- W2 demolish: none recorded
- W3 build size: <=4=2624
- W3 demolish: none recorded
- W4 build size: <=4=2
- W4 demolish: none recorded

Lifetime class:
- W1: built-and-never-deleted; no rung migration counted
- W2: built-and-never-deleted; no rung migration counted
- W3: built-and-never-deleted; no rung migration counted
- W4: never looked up; built-and-never-deleted

### f6 MVM_vm_create_instance (src/moar.c:207)

| op | W1 count / cycles / cycles per op | W2 count / cycles / cycles per op | W3 count / cycles / cycles per op | W4 count / cycles / cycles per op |
|---|---|---|---|---|
| build | 100 / 3197 / 32.0 | 78 / 2635 / 33.8 | 2624 / 160.4K / 61.1 | 2 / 74 / 37.0 |
| insert | 1850 / 861.5K / 465.7 | 873 / 315.2K / 361.1 | 71.0K / 215.61M / 3036.8 | 20 / 5994 / 299.7 |
| fetch_hit | 200 / 463.2K / 2316.2 | 4 / 9879 / 2469.8 | 12.6K / 88.59M / 7035.7 | - |
| fetch_miss | 1850 / 2.15M / 1162.4 | 873 / 952.3K / 1090.9 | 71.0K / 149.50M / 2105.6 | 20 / 22.1K / 1106.3 |
| grow (inside insert) | 202 / 425.6K / 2107.0 | 89 / 124.0K / 1393.5 | 7909 / 129.44M / 16365.9 | 2 / 1850 / 925.0 |
| **site cycles** | 3.48M | 1.28M | 453.86M | 28.2K |
| **% of hash cycles** | 0.2 | 0.0 | 0.0 | 0.0 |
| **% of total cycles** | 0.0 | 0.0 | 0.0 | 0.0 |

- W1 build size: <=4=100
- W1 demolish: none recorded
- W2 build size: <=4=78
- W2 demolish: none recorded
- W3 build size: <=4=2624
- W3 demolish: none recorded
- W4 build size: <=4=2
- W4 demolish: none recorded

Lifetime class:
- W1: built-and-never-deleted; no rung migration counted
- W2: built-and-never-deleted; no rung migration counted
- W3: built-and-never-deleted; no rung migration counted
- W4: built-and-never-deleted; no rung migration counted

### f7 MVM_vm_create_instance (src/moar.c:210)

| op | W1 count / cycles / cycles per op | W2 count / cycles / cycles per op | W3 count / cycles / cycles per op | W4 count / cycles / cycles per op |
|---|---|---|---|---|
| build | 100 / 3486 / 34.9 | 78 / 2856 / 36.6 | 2624 / 230.1K / 87.7 | 2 / 74 / 37.0 |
| insert | 300 / 90.7K / 302.4 | 234 / 97.3K / 416.0 | 7872 / 6.98M / 886.4 | 6 / 2331 / 388.5 |
| fetch_hit | 1600 / 543.3K / 339.6 | 102 / 44.7K / 437.8 | 83.7K / 97.45M / 1164.5 | - |
| **site cycles** | 637.6K | 144.9K | 104.66M | 2405 |
| **% of hash cycles** | 0.0 | 0.0 | 0.0 | 0.0 |
| **% of total cycles** | 0.0 | 0.0 | 0.0 | 0.0 |

- W1 build size: <=4=100
- W1 demolish: none recorded
- W2 build size: <=4=78
- W2 demolish: none recorded
- W3 build size: <=4=2624
- W3 demolish: none recorded
- W4 build size: <=4=2
- W4 demolish: none recorded

Lifetime class:
- W1: built-and-never-deleted; no rung migration counted
- W2: built-and-never-deleted; no rung migration counted
- W3: built-and-never-deleted; no rung migration counted
- W4: never looked up; built-and-never-deleted; no rung migration counted

### f8 MVM_disp_syscall_setup (src/disp/syscall.c:1671)

| op | W1 count / cycles / cycles per op | W2 count / cycles / cycles per op | W3 count / cycles / cycles per op | W4 count / cycles / cycles per op |
|---|---|---|---|---|
| build | 100 / 4523 / 45.2 | 78 / 3483 / 44.7 | 2624 / 635.9K / 242.3 | 2 / 38 / 19.0 |
| insert | 8400 / 4.00M / 476.4 | 6552 / 3.22M / 490.7 | 220.4K / 181.11M / 821.7 | 168 / 79.4K / 472.9 |
| fetch_hit | 116.2K / 52.49M / 451.6 | 41.7K / 23.14M / 555.5 | 8.51M / 11.85G / 1391.5 | 1020 / 572.8K / 561.5 |
| grow (inside insert) | 431 / 485.6K / 1126.6 | 330 / 401.6K / 1217.0 | 11.1K / 72.89M / 6592.8 | 9 / 9805 / 1089.4 |
| **site cycles** | 56.50M | 26.36M | 12.03G | 652.2K |
| **% of hash cycles** | 3.4 | 0.1 | 0.9 | 0.0 |
| **% of total cycles** | 0.3 | 0.0 | 0.0 | 0.0 |

- W1 build size: <=4=100
- W1 demolish: none recorded
- W2 build size: <=4=78
- W2 demolish: none recorded
- W3 build size: <=4=2624
- W3 demolish: none recorded
- W4 build size: <=4=2
- W4 demolish: none recorded

Lifetime class:
- W1: built-and-never-deleted; no rung migration counted
- W2: built-and-never-deleted; no rung migration counted
- W3: built-and-never-deleted; no rung migration counted
- W4: built-and-never-deleted; no rung migration counted

### i1 MVM_vm_create_instance (src/moar.c:182)

| op | W1 count / cycles / cycles per op | W2 count / cycles / cycles per op | W3 count / cycles / cycles per op | W4 count / cycles / cycles per op |
|---|---|---|---|---|
| build | 100 / 64.60M / 645989.7 | 78 / 51.98M / 666445.4 | 2624 / 38.49G / 14667680.9 | 2 / 1.13M / 562770.0 |
| insert | 4700 / 2.28M / 485.0 | 3666 / 1.92M / 523.3 | 123.3K / 98.15M / 795.8 | 94 / 50.5K / 537.7 |
| fetch_hit | 264.1K / 92.76M / 351.3 | 42.5K / 21.36M / 502.9 | 13.97M / 10.45G / 748.5 | 550 / 254.7K / 463.0 |
| grow (inside insert) | 11 / 1480 / 134.5 | 4 / 777 / 194.2 | 200 / 162.7K / 813.3 | - |
| **site cycles** | 159.64M | 75.26M | 49.04G | 1.43M |
| **% of hash cycles** | 9.7 | 0.3 | 3.6 | 0.1 |
| **% of total cycles** | 0.8 | 0.0 | 0.2 | 0.0 |

- W1 build size: <=64=100
- W1 demolish: none recorded
- W2 build size: <=64=78
- W2 demolish: none recorded
- W3 build size: <=64=2624
- W3 demolish: none recorded
- W4 build size: <=64=2
- W4 demolish: none recorded

Lifetime class:
- W1: built-and-never-deleted; no rung migration counted
- W2: built-and-never-deleted; no rung migration counted
- W3: built-and-never-deleted; no rung migration counted
- W4: built-and-never-deleted; no rung migration counted

### i2 MVM_bytecode_finish_frame (src/core/bytecode.c:667)

| op | W1 count / cycles / cycles per op | W2 count / cycles / cycles per op | W3 count / cycles / cycles per op | W4 count / cycles / cycles per op |
|---|---|---|---|---|
| build | 20.2K / 4.04M / 200.1 | 4713 / 1.22M / 259.9 | 1.61M / 8.01G / 4972.9 | 80 / 18.3K / 228.5 |
| insert | 288.3K / 53.15M / 184.4 | 73.9K / 17.37M / 235.0 | 19.46M / 9.13G / 469.1 | 1130 / 270.7K / 239.5 |
| fetch_hit | 1.12M / 76.69M / 68.6 | 39.35M / 2.22G / 56.4 | 273.84M / 52.74G / 192.6 | 78.7K / 6.24M / 79.3 |
| fetch_miss | 24.4K / 3.41M / 139.8 | 23.46M / 1.49G / 63.5 | 122.96M / 19.23G / 156.4 | 55.1K / 3.47M / 62.9 |
| grow (inside insert) | 21 / 3626 / 172.7 | 8 / 1406 / 175.8 | 1043 / 849.9K / 814.9 | - |
| demolish | - | - | 52.8K / 0 / 0.0 | - |
| **site cycles** | 137.29M | 3.73G | 89.11G | 10.00M |
| **% of hash cycles** | 8.3 | 14.0 | 6.6 | 0.5 |
| **% of total cycles** | 0.7 | 0.4 | 0.3 | 0.1 |

- W1 build size: <=16=17650 <=32=1650 <=64=400 <=128=400 <=256=50 <=1024=50
- W1 demolish: none recorded
- W2 build size: <=16=3847 <=32=563 <=64=48 <=128=242 <=256=5 <=1024=8
- W2 demolish: none recorded
- W3 build size: <=16=1477426 <=32=88179 <=64=22506 <=65=7 <=128=17405 <=256=2616 <=1024=2615 <=16384=1
- W3 demolish max items, set 0 rung 0: <=16=52814
- W4 build size: <=16=62 <=32=14 <=128=4
- W4 demolish: none recorded

Lifetime class:
- W1: built-and-never-deleted; no rung migration counted
- W2: built-and-never-deleted; no rung migration counted
- W3: built-and-never-deleted; no rung migration counted
- W4: built-and-never-deleted; no rung migration counted

### i3 [census: MVMStaticFrame.c:73 copy_to (shallow copy)]

Absent in all four workloads.

### p1 MVM_gc_object_id (src/gc/objectid.c:28)

| op | W1 count / cycles / cycles per op | W2 count / cycles / cycles per op | W3 count / cycles / cycles per op | W4 count / cycles / cycles per op |
|---|---|---|---|---|
| build | 100 / 10.9K / 109.2 | 53 / 6216 / 117.3 | 2603 / 1.04M / 398.5 | 2 / 148 / 74.0 |
| insert | 1400 / 461.7K / 329.8 | 217.7K / 30.91M / 142.0 | 6.45M / 3.77G / 584.1 | 10 / 5142 / 514.2 |
| fetch_hit | 2950 / 287.0K / 97.3 | 357.0K / 34.26M / 96.0 | 11.05M / 1.81G / 163.7 | 12 / 2146 / 178.8 |
| delete_hit | - | 216.7K / 8.38M / 38.6 | 5.98M / 1.34G / 224.7 | 10 / 627 / 62.7 |
| grow (inside insert) | 150 / 162.4K / 1082.4 | 93 / 489.0K / 5258.0 | 17.3K / 1.12G / 64913.2 | - |
| **site cycles** | 759.7K | 73.56M | 6.92G | 8063 |
| **% of hash cycles** | 0.0 | 0.3 | 0.5 | 0.0 |
| **% of total cycles** | 0.0 | 0.0 | 0.0 | 0.0 |

- W1 build size: <=4=100
- W1 demolish: none recorded
- W2 build size: <=4=53
- W2 demolish: none recorded
- W3 build size: <=4=2603
- W3 demolish: none recorded
- W4 build size: <=4=2
- W4 demolish: none recorded

Lifetime class:
- W1: built-and-never-deleted; no rung migration counted
- W2: churning (216.7K deletes against 217.7K inserts); no rung migration counted
- W3: churning (5.98M deletes against 6.45M inserts); no rung migration counted
- W4: churning (10 deletes against 10 inserts); no rung migration counted

### p2 [census: heapsnapshot.c:746 seen set]

Absent in all four workloads.

### other (site 255)

| op | W1 count / cycles / cycles per op | W2 count / cycles / cycles per op | W3 count / cycles / cycles per op | W4 count / cycles / cycles per op |
|---|---|---|---|---|
| fetch_miss | 249.8K / 10.70M / 42.8 | 12.14M / 468.59M / 38.6 | 78.84M / 9.82G / 124.6 | 39.4K / 1.46M / 37.0 |
| delete_miss | - | 1581 / 134.9K / 85.4 | 840 / 117.0K / 139.3 | - |
| iter_start | 5350 / 0 / 0.0 | 769.1K / 0 / 0.0 | 5.99M / 0 / 0.0 | 766 / 0 / 0.0 |
| **site cycles** | 10.70M | 468.73M | 9.82G | 1.46M |
| **% of hash cycles** | 0.7 | 1.8 | 0.7 | 0.1 |
| **% of total cycles** | 0.1 | 0.1 | 0.0 | 0.0 |

- W1 build size: (no builds)
- W1 demolish: none recorded
- W2 build size: (no builds)
- W2 demolish: none recorded
- W3 build size: (no builds)
- W3 demolish: none recorded
- W4 build size: (no builds)
- W4 demolish: none recorded

Lifetime class:
- W1: built-and-never-deleted; no rung migration counted
- W2: churning (1581 deletes against 0 inserts); no rung migration counted
- W3: churning (840 deletes against 0 inserts); no rung migration counted
- W4: built-and-never-deleted; no rung migration counted


## Open leads

- Fetch misses on Swiss already win at 63-64 entries (0.87, 0.88); the survey's "stay on default below 65" rulings rest on hits and inserts. A miss-heavy site below 65 (i2 is 31-37 percent misses) is a candidate for a re-look with the binned re-measurement.
- Lookups binned by table size: done, `internals-survey-binned.md` (section "Lookups by table size").
