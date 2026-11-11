# cb Task 3: after-profile; gate PASS: allocator row 1.63 % against C 1.59 % (bound 1.69) plain, 1.54 % against 1.61 % bad; collector total 4.08 % against C 3.93 % (+0.15 points, bound 0.30) plain, 3.90 % against 4.02 % bad (-0.12)

## The gate (spec 7)

| setting | allocator row: cb (allocateObject + export) | C (MVM_gc_allocate_object) | bound C + 0.10 | margin | collector total: cb | C | cb - C | bound | verdict |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| plain | 1.63 % (1.53 + 0.10) | 1.59 % | 1.69 % | 0.06 | 4.08 % | 3.93 % | +0.15 | 0.30 | **pass** |
| --bad-packages | 1.54 % (1.41 + 0.13) | 1.61 % | 1.71 % | 0.17 | 3.90 % | 4.02 % | -0.12 | 0.30 | **pass** |

**Gate: pass on both settings, on both numbers.** No number lands within 0.05 points of its bound, so the two extra
`--record` passes per side were not taken: the closest is plain's allocator row, 0.06 below its bound at perf
report's two decimals, and 0.0607 at full precision (alloc-precise.txt: cb 1.6299 %, C 1.5906 %, bound 1.6906 %).
Against Campaign 6's after-profile on the same C binary (ngc-profile-after.md, plain: C allocator 1.56 %, native
1.87 %; collector total C 3.89 %, native 4.22 %) the allocator row moved from +0.31 points above the C to +0.04, and
the collector total from +0.33 points to +0.15. One sampled run per side and setting, as Campaign 6.

```
cb profile record (Task 3, step 2; spec 7)
Date:          2026-11-11, profile 19:32:01-19:40:27, .text A/B 19:40:27-19:44:14 CET (driver.log)
MoarVM:        gc-call-boundary at 11a2e2e84; cb-n-syms built at c5aebb78a's src (cb-prefixes.md; its version line reads
               2026.09-299-g782a56faa, the working tree's HEAD at build time), not rebuilt; traces e4758f9 before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8; perf 7.2.9, perf_event_paranoid 2 (every event :u)
Pair:          ng-c-syms (Campaign 6 Task 2's build, -Dzig-gc=false -Dstrip=false, not rebuilt) against cb-n-syms
               (-Dstrip=false, Task 1 of this campaign); otherwise defaults, LTO; 2850 exported names in both
Runner:        rakudo-m as in ngc-profile.md; RAKULIB tools/bench/gc/lib plus the rakudo lib/
Program:       tools/bench/gc/crc-getter.raku --volume=100000 --runs=5 [--bad-packages], spesh and precompilation on
Commands:      sh traces/llm/bench/cb-profile-driver.sh (ngc-profile-after-driver.sh with n = cb-n-syms, the nlto pass
               dropped, the .text fallback A/B for the cb-n pair only): per setting the rounds c n / n c / c n of
               systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/profile.sh --stat-runs=5 (--record in
               round 1); then ab.sh --base=cb-n-base --head=cb-n-syms --rounds=3 --runs=5 --volume=100000
Load:          1-minute load before every run: profile 0.76-1.66, .text A/B 1.07-1.36; nothing else ran on the machine
Analysis:      ngc-profile-raw/analyze.pl, unchanged, over a view of the raw directory in which n-r<k> is linked as
               f-r<k> (its "f" columns are cb-n-syms); it exits 2 at the end, looking for the nlto pass this campaign
               does not run, after printing both settings (analysis-note.txt); output cb-profile-raw/analysis-output.md.
               The allocator row at full precision: perf report -F period,dso,sym of each r1 perf.data
               (report-period.txt, alloc-precise.txt)
Raw:           cb-profile-raw/: {plain,bad}/{c,n}-r{1,2,3}/ (stat-<n>.csv, stat.tsv, load.log; report.txt and
               report-period.txt in r1), textab-n/ (summary.md, load.log), driver.log, driver.out, analysis-output.md,
               analysis-note.txt, alloc-precise.txt, text-compare.txt. perf.data not kept. All 60 counted and 4
               sampled runs printed "RUN 5"; driver.log: 12 profile.sh exits 0 (six per setting) and the A/B's 0.
```

## The .text of cb-n-syms against cb-n-base (spec 7): different, as at Campaign 6; the profiled n side is "a different binary"

`objcopy -O binary --only-section=.text` and `cmp` (text-compare.txt): the two differ at byte 4. cb-n-base .text
2380325 bytes, cb-n-syms 2645493 (+265168, exactly Campaign 6's ng-n difference); of the 2850 `nm -D -S` sizes the
same two (`MVM_index_hash_build`, `s_mp_toom_mul`) differ by 4 bytes, the rest are equal.

Spec 7's fallback A/B (textab-n/summary.md, three rounds) for the cb-n pair; the C pair is cited from Campaign 6
(ngc-profile-after.md), not re-run:

| pair | -base wall s | -syms wall s | ratio wall | ratio RSS | within spread |
|---|---:|---:|---:|---:|---|
| cb-n (2026-11-11) | 7.58 [7.57-7.59] | 7.50 [7.44-7.50] | 0.989 | 0.981 | **no**: the ranges do not overlap; cb-n-syms 1.1 % faster |
| ng-c (Campaign 6, cited) | 7.50 [7.49-7.56] | 7.44 [7.41-7.44] | 0.992 | 1.001 | **no**: ng-c-syms 0.8 % faster |

So, per spec 7, **both sides of this profile are taken on a different binary**, now in the same direction and by
about the same amount (Campaign 6's ng-n-syms was 2.3 % slower than its base). The profiled pair is closer to the
shipped pair than Campaign 6's was, but every number below describes the -syms pair.

## Counters (perf stat, medians)

Cells: median of the three round medians [min-max of the round medians]; 15 runs per side and setting.

### plain

| event | c (ng-c-syms) | cb (cb-n-syms) | cb/c | Campaign 6 n/c (ngc-profile-after.md) |
|---|---:|---:|---:|---:|
| cycles:u | 35993466595 [35610714012-36195853010] | 36129682828 [35915205514-36167961163] | 1.0038 | 1.0190 |
| instructions:u | 68909118467 [68902279867-68934522940] | 68786479769 [68774659735-68796982887] | 0.9982 | 1.0040 |
| branch-misses:u | 48602113 [48279928-49275266] | 50074393 [49644876-50373324] | 1.0303 | 1.0157 |
| cache-misses:u | 126175431 [125675929-129482388] | 130769217 [127428658-130984512] | 1.0364 | 1.0083 |
| L1-dcache-load-misses:u | 1106632781 [1094929064-1139515987] | 1103091508 [1093363753-1111892771] | 0.9968 | 0.9822 |

### --bad-packages

| event | c (ng-c-syms) | cb (cb-n-syms) | cb/c | Campaign 6 n/c |
|---|---:|---:|---:|---:|
| cycles:u | 38379754264 [38062136278-38552042153] | 38470716341 [38287403091-38514170057] | 1.0024 | 1.0220 |
| instructions:u | 70916160495 [70877140317-70943506239] | 70808189292 [70785873912-70818520716] | 0.9985 | 1.0041 |
| branch-misses:u | 51985911 [51296869-52257654] | 52943406 [52285329-53745200] | 1.0184 | 1.0406 |
| cache-misses:u | 151248125 [146805900-156409416] | 153680197 [152054625-154517456] | 1.0161 | 0.9933 |
| L1-dcache-load-misses:u | 1218731733 [1212215696-1238932917] | 1211200618 [1206872772-1216672007] | 0.9938 | 0.9653 |

The cb side now executes 0.15-0.18 % fewer instructions than the C control (Campaign 6's native side 0.4 % more), and
the profiled cycle gap fell from 1.90 % to 0.38 % plain and from 2.20 % to 0.24 % bad.

## Collector share and the unresolvable rule (spec 7)

| | plain | --bad-packages |
|---|---:|---:|
| total cycles:u c / cb | 35993466595 / 36129682828 | 38379754264 / 38470716341 |
| difference cb - c | 136216233 (0.38 % of c) | 90962077 (0.24 % of c) |
| spread of round medians c / cb | 585138998 / 252755649 | 489905875 / 226766966 |
| run-to-run spread (max - min of 15 runs) c / cb | 1171019464 / 588490003 | 15341585428 / 1013452476 |
| collector samples c / cb | 3.93 % / 4.08 % | 4.02 % / 3.90 % |
| collector cycles c / cb | 1414543237 / 1474091059 | 1542866121 / 1500357937 |
| collector difference cb - c | +59547822 | -42508184 |
| collector share (computed) | 59547822 / 136216233 = 0.437 | -42508184 / 90962077 = -0.467 |

**Unresolvable on both settings.** The total-cycle difference (1.36e8 plain, 9.1e7 bad) is smaller than either side's
round-median spread and smaller than both sides' run-to-run spread over 15 runs (one C bad run reads 5.3e10, an
outlier that only widens the C run-to-run spread; the round medians are unaffected). Under spec 7's rule the cb/C gap
of the profiled pair is not resolvable at volume 100 000, so the shares 0.437 and -0.467 are computed and carry no
weight.

## Before and after, per symbol (LTO, plain)

Collector symbols, aligned by the C function as ngc-profile-after.md aligns them; cycles = share of samples x the
side's median total cycles:u. "after ngc" is Campaign 6's after-profile (c = ng-c-syms, n = ng-n-syms, 2026-11-10);
"after cb" is this record (c = the same ng-c-syms, measured again today, cb = cb-n-syms). One sampled run per side
and setting (round 1).

| C function | after ngc c % | after ngc n % | after ngc n - c cycles | after cb c % | after cb cb % (Zig names) | after cb cb - c cycles |
|---|---:|---:|---:|---:|---|---:|
| process_worklist | 0.08 | 0.11 | +1.1e7 | 0.05 | 0.11 (gc.collect.processWorklist) | +2.2e7 |
| MVM_gc_root_temp_push (roots.h inline) | 0 (inlined) | 0 (inlined) | 0 | 0 (inlined) | 0 (inlined, `moar.root`; no `moar.*` or `moar_c.*` row sampled) | 0 |
| MVM_gc_allocate_object | 1.56 | 1.87 (1.77 + export 0.10) | +1.24e8 | 1.59 | 1.63 (gc.allocation.allocateObject 1.53 + the export 0.10) | +1.7e7 |
| MVM_gc_collect_free_nursery_uncopied | 1.71 | 1.77 | +3.4e7 | 1.71 | 1.83 (gc.collect.freeNurseryUncopied; export 0.00) | +4.6e7 |
| MVM_gc_allocate_nursery | 0.26 | 0.25 | -1.9e6 | 0.35 | 0.24 | -3.9e7 |
| frame roots and registers | 0.09 | 0.11 | +7.9e6 | 0.11 (MVM_gc_root_add_frame_roots_to_worklist) | 0.14 (gc.roots.addFrameRootsToWorklist 0.08 + addFrameRegistersToWorklist 0.06) | +1.1e7 |
| **collector total** | 3.89 | 4.22 | **+1.47e8** | 3.93 | 4.08 | **+5.95e7** |

The listed after-cb rows sum to about +5.7e7; the rest of the +5.95e7 is the unlisted collector rows, each under
0.05 % (gc.collect.markCollectable 0.04 against MVM_gc_mark_collectable 0.03, gc.orchestrate.markThreadUnblocked
0.03, gc.gen2.allocate 0.02 against 0.03). The allocator's delta fell from +1.24e8 to +1.7e7 cycles, and processWorklist,
which Risk 4 of the spec named, stays at 0.11 % (it did not grow with gen2Add out of line). The C side's own allocator
share moved 1.56 to 1.59 % and allocate_nursery 0.26 to 0.35 % between the two days, the order of one sampled run's
noise. --bad-packages has the same picture (analysis-output.md): allocator cb 1.54 % (1.41 + 0.13) against C 1.61 %
(-2.6e7), freeNurseryUncopied 1.73 % against 1.75 % (-6.1e6), processWorklist 0.07 % on both, the collector total
-4.3e7.

As at Campaign 6, analysis-output.md keys the Zig internals by their snake-case names, so `allocate_object` and
`MVM_gc_allocate_object` (+5.53e8 and -5.36e8 plain), and `free_nursery_uncopied` and
`MVM_gc_collect_free_nursery_uncopied` (+6.61e8, -6.16e8), appear as separate rows; the table above sums each pair.

Outside the collector (plain, the analyzer's top rows): JIT code +3.87e8, unsymbolised libc -2.61e8, REPR
`initialize` +1.31e8, `MVM_frame_dispatch` -1.18e8, `MVM_callstack_unwind_frame` +8.8e7, `fastMemset` -8.4e7,
`MVM_interp_run` +8.3e7, then a scatter below 7.5e7 both ways; --bad-packages: `mp_clear` +2.59e8, `fastMemset`
+2.36e8, then below 1e8 both ways.

## Finding

With gen2Add, addToQueue and the four worklist and finalize definitions kept out of line as the C keeps them, the
allocator row is at parity with the C's (1.63 % against 1.59 % plain, 1.54 % against 1.61 % bad; allocateObject 369
bytes against the C's 384, cb-audit.md) and the collector total is within 0.15 points of the C's on both settings:
the gate passes. The profiled cycle gap fell from 1.90 % to 0.38 % plain and from 2.20 % to 0.24 % bad, and the cb
side executes fewer instructions than the C control. What remains is **not resolvable at volume 100 000** under spec
7's rule on either setting: the gap is below both sides' run-to-run spread, so no share of it is assigned to the
collector (0.437 plain and -0.467 bad are computed only; the collector difference is +6.0e7 plain and -4.3e7 bad,
the same order as one sampled run's noise). The crc-getter's remaining --bad-packages wall miss (cb-crc-ab.md, 1.010)
is therefore not located in the collector by this profile: the remaining wall gap is outside the collector as far as
this profile resolves, as the spike's profile (spec section 4) said.
