# ngc Task 9: profile after; the native/C cycle gap is 1.90 % plain, 2.20 % bad, unresolvable at this volume on both; the fence stall and the out-of-line temp-root push are gone

```
ngc profile record, after (Task 9, step 6; spec 7)
Date:          2026-11-10, builds 18:33-18:35, profile 20:53:46-21:02:31, .text A/B 21:02:31-21:10:06 CET
MoarVM:        zig-native-gc at 1a70642f9 (src/zig identical to b0b3a48d6); version line 2026.09-291-g1a70642f9 (the
               same length as the -base prefixes' 2026.09-289-gb0b3a48d6); traces 1b65cba before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8; perf 7.2.9, perf_event_paranoid 2 (every event :u)
Pair:          ng-c-syms (Task 2's build, -Dzig-gc=false -Dstrip=false, not rebuilt) against ng-n-syms (native, -Dstrip=false,
               built at Task 9); attribution pass ng-c-nlto (Task 2's) / ng-n-nlto (-Dlto=false -Dstrip=false, Task 9);
               otherwise defaults; 2850 exported names in all
Builds:        ngc-profile-after-raw/build2.sh (ngc-profile-raw/build4.sh's recipe: rm -f src/gen/config.{h,c,o}, zig build
               install --prefix ..., load < 2.0, MemoryMax=8G); builds.tsv: ng-n-syms exit 0 68 s load 0.35, ng-n-nlto
               exit 0 24 s load 1.13
Runner:        rakudo-m as in ngc-profile.md; RAKULIB tools/bench/gc/lib plus the rakudo lib/
Program:       tools/bench/gc/crc-getter.raku --volume=100000 --runs=5 [--bad-packages], spesh and precompilation on
Commands:      ngc-profile-after-driver.sh (ngc-profile-driver.sh with n in place of f; last stage of
               ngc-acceptance-master.sh): per setting the rounds c n / n c / c n of tools/bench/gc/profile.sh
               --stat-runs=5 (--record in round 1); then --stat-runs=0 --record on ng-c-nlto, ng-n-nlto (plain); then
               ab.sh --rounds=3 --runs=5 --volume=100000 of each -syms against its -base
Load:          1-minute load before every run: profile 1.12-1.62, .text A/B 1.04-1.62; nothing else ran on the machine
               (the master script's earlier stages had finished; the machine was otherwise idle)
Analysis:      Task 2's ngc-profile-raw/analyze.pl, run unchanged over a view of the raw directory in which n-r<k> is
               linked as f-r<k> (so its "f" columns are the native side); full output ngc-profile-after-raw/analysis-output.md
Raw:           ngc-profile-after-raw/: {plain,bad}/{c,n}-r{1,2,3}/ (stat-<n>.csv, stat.tsv, load.log; report.txt in r1),
               nlto/{c,n}/, textab-{c,n}/ (summary.md, load.log), driver.log, analysis-output.md, hot-spots.txt (fences,
               sizes, perf annotate excerpts), annot-*.txt (full perf annotate of the three functions read below).
               perf.data not kept. All 60 counted, 6 sampled and 2 nlto runs printed "RUN 5".
```

## The .text of -syms against -base (spec 7): different, as at Task 2; both sides labelled "a different binary"

`objcopy -O binary --only-section=.text` and `cmp`: both pairs differ at byte 4. ng-n-base .text 2393445 bytes,
ng-n-syms 2658613 (+265168; ng-c +265200), the same std.debug machinery as Task 2 found; of the 2850 `nm -D -S` sizes
the same two (`MVM_index_hash_build`, `s_mp_toom_mul`) differ by 4 bytes, the rest are equal.

Spec 7's fallback A/B (textab-{c,n}/summary.md, three rounds, quiet machine):

| pair | -base wall s | -syms wall s | ratio wall | ratio RSS | within spread |
|---|---:|---:|---:|---:|---|
| ng-c | 7.50 [7.49-7.56] | 7.44 [7.41-7.44] | 0.992 | 1.001 | **no**: the ranges do not overlap; ng-c-syms 0.8 % faster (Task 2: 1.5 %) |
| ng-n | 7.50 [7.49-7.55] | 7.67 [7.62-7.68] | 1.023 | 0.982 | **no**: the ranges do not overlap; ng-n-syms 2.3 % slower |

So, per spec 7, **both sides of this profile are taken on a different binary**, and in opposite directions: the
profiled pair's wall gap n-syms/c-syms is about 7.67 / 7.44 = 1.031, against 1.004 for the shipped -base pair
(ngc-crc-ab.md). The keeping of std.debug's 265 KB moves code placement on both sides; on the native side it costs
2.3 %, more than the whole shipped native/C gap. Every number below describes the -syms pair, not the shipped one.

## Counters (perf stat, medians)

Cells: median of the three round medians [min-max of the round medians]; 15 runs per side and setting.

### plain

| event | c (ng-c-syms) | n (ng-n-syms) | n/c | before f/c (ngc-profile.md) |
|---|---:|---:|---:|---:|
| cycles:u | 35897495068 [35809744758-36032590477] | 36577889225 [36467805575-36848937764] | 1.0190 | 1.0419 |
| instructions:u | 68926715602 [68909987956-68928901449] | 69201143624 [69194034391-69210781987] | 1.0040 | 1.0101 |
| branch-misses:u | 48817191 [48608185-49284281] | 49584603 [49375801-49585390] | 1.0157 | 1.0067 |
| cache-misses:u | 122382349 [122329185-127573780] | 123393245 [120194850-129565505] | 1.0083 | 0.9906 |
| L1-dcache-load-misses:u | 1127725233 [1120603805-1138872202] | 1107630364 [1084533080-1118198456] | 0.9822 | 1.0053 |

### --bad-packages

| event | c (ng-c-syms) | n (ng-n-syms) | n/c | before f/c |
|---|---:|---:|---:|---:|
| cycles:u | 38109076084 [37916942060-38139115515] | 38948294955 [38939649559-38955857374] | 1.0220 | 1.0480 |
| instructions:u | 70920952897 [70916948383-70922337834] | 71212585707 [71157380647-71235699344] | 1.0041 | 1.0096 |
| branch-misses:u | 51570988 [50753070-51658027] | 53665115 [52722838-54061912] | 1.0406 | 0.9965 |
| cache-misses:u | 147171976 [144966598-151057848] | 146190368 [144419404-156751323] | 0.9933 | 0.9959 |
| L1-dcache-load-misses:u | 1241278644 [1230561150-1257760309] | 1198263756 [1194147701-1228253203] | 0.9653 | 0.9983 |

The native side executes 0.4 % more instructions than the C control (the faithful side 1.0 %) and the cycle gap of the
profiled pair has more than halved, 4.19 % to 1.90 % plain and 4.80 % to 2.20 % bad, on the same ng-c-syms binary
(its own medians moved by 1.0 % and 0.8 % between the two days).

## Collector share and the unresolvable rule (spec 7)

| | plain | --bad-packages |
|---|---:|---:|
| total cycles:u c / n | 35897495068 / 36577889225 | 38109076084 / 38948294955 |
| difference n - c | 680394157 (1.90 % of c) | 839218871 (2.20 % of c) |
| spread of round medians c / n | 222845719 / 381132189 | 222173455 / 16207815 |
| run-to-run spread (max - min of 15 runs) c / n | 857929705 / 964649422 | 3066515449 / 1891512310 |
| collector samples c / n | 3.89 % / 4.22 % | 4.07 % / 4.10 % |
| collector cycles c / n | 1396412558 / 1543586925 | 1551039397 / 1596880093 |
| collector difference n - c | 147174367 | 45840697 |
| collector share (computed) | 147174367 / 680394157 = 0.216 | 45840697 / 839218871 = 0.055 |

**Unresolvable on both settings.** Plain, the total-cycle difference (6.80e8) is larger than either side's
round-median spread (2.2e8, 3.8e8) but smaller than both sides' run-to-run spread over 15 runs (8.6e8, 9.6e8);
--bad-packages, the difference (8.39e8) is smaller than both run-to-run spreads (3.07e9, 1.89e9). Under spec 7's rule
("smaller than either side's run-to-run spread") **the native/C gap of the profiled pair is not resolvable at volume
100 000**, so its collector shares, 0.216 and 0.055, are computed and carry no weight. Task 2's plain gap (1.49e9) was
resolvable; the rewrite brought it below the run-to-run noise of this volume.

## Before and after, per symbol (LTO, plain)

Collector symbols, aligned by the C function; cycles = share of samples x the side's median total cycles:u. Before:
ngc-profile.md (c = ng-c-syms, f = ng-f-syms); after: this record (c = the same ng-c-syms, n = ng-n-syms). Shares
rest on one sampled run per side and setting (round 1), as at Task 2.

| C function | before c % | before f % (Zig names) | before f - c cycles | after c % | after n % (Zig names) | after n - c cycles |
|---|---:|---|---:|---:|---|---:|
| process_worklist | 0.05 | 0.74 (gc.collect.processWorklist) | +2.56e8 | 0.08 | 0.11 (gc.collect.processWorklist) | +1.1e7 |
| MVM_gc_root_temp_push (roots.h inline) | 0 (inlined) | 0.48 (moar_c.MVM_gc_root_temp_push) | +1.78e8 | 0 (inlined) | 0 (inlined, `moar.root`) | 0 |
| MVM_gc_allocate_object | 1.56 | 1.41 (the export) | -3.2e7 | 1.56 | 1.87 (gc.allocation.allocateObject 1.77 + the export 0.10) | +1.24e8 |
| MVM_gc_collect_free_nursery_uncopied | 1.94 | 1.66 (the export) | -7.5e7 | 1.71 | 1.77 (gc.collect.freeNurseryUncopied; export 0.00) | +3.4e7 |
| MVM_gc_allocate_nursery | 0.32 | 0.32 | +4.8e6 | 0.26 | 0.25 | -1.9e6 |
| frame roots and registers | (Task 2: -2.0e7 / +1.9e7) | | | 0.09 (MVM_gc_root_add_frame_roots_to_worklist) | 0.11 (gc.roots.addFrameRootsToWorklist 0.06 + addFrameRegistersToWorklist 0.05) | +7.9e6 |
| **collector total** | 4.15 | 4.84 | **+3.17e8** | 3.89 | 4.22 | **+1.47e8** |

The listed after rows sum to about +1.75e8; the stated total +1.47e8 also includes the collector symbols not listed,
whose deltas are net negative (about -2.8e7), the two largest `MVM_gc_collect` (0.04 % to none counted on the native side, about -1.4e7)
and `MVM_gc_mark_collectable` (0.04 % to 0.02 % as gc.collect.markCollectable, about -7.0e6). The profiled pair's
wall gap (n-syms/c-syms 1.031) exceeds its cycle gap (cycles:u 1.019), consistent with the -syms builds being
different binaries from -base.

The analyzer's aligned delta keys a Zig internal by its snake-case name, so in analysis-output.md the native
`gc.allocation.allocateObject` (`allocate_object`) and the export `MVM_gc_allocate_object` appear as two rows
(+6.47e8 and -5.23e8), likewise `free_nursery_uncopied` and `MVM_gc_collect_free_nursery_uncopied` (+6.47e8,
-6.14e8); the table above sums each pair, which is the comparison spec 7 asks for (the export is a 5-byte
`jmp` to the Zig function, hot-spots.txt).

Outside the collector (plain, the analyzer's top rows): REPR `initialize` +1.76e8, `MVM_frame_dispatch` +1.52e8,
`MVM_spesh_arg_guard_run` -1.54e8, JIT code +1.44e8, `gc_free` (REPR) +1.40e8, unsymbolised libc +1.35e8, `mp_xor`
+8.9e7, then a scatter below 7e7 both ways. --bad-packages has the same collector picture, smaller (allocateObject and its export
+6.23e8 - 5.94e8 = +2.97e7, freeNurseryUncopied and its export +7.01e8 - 6.40e8 = +6.09e7), and outside it `MVM_spesh_inline` -2.39e8, libc +2.37e8, JIT +2.34e8, REPR `gc_free`
+2.07e8, `MVM_frame_dispatch` +1.92e8.

## The fence and the inlining

- **Fence (Ruling R5).** ng-n-syms and ng-n-base contain 0 `mfence` (ng-f-syms had 3, all in processWorklist) and 37
  `lock orl $0x0,-0x40(%rsp)`, as many as the C builds. The forwarder-publishing site is now `lock orl` then
  `orb $0x10,0xd(%r13)` (flags2 |= FORWARDER_VALID) at both copies the compiler makes (0x7a43cb, 0x7a468a). Task 2
  found 79.1 % of processWorklist's samples on the instruction after the `mfence`; now the two post-fence instructions
  hold 14.4 % (8.56 + 5.87) of a function at 0.11 %, and the hottest instruction is the `test $0x2,%al` of the
  `second_gen` check (29.0 %), as in C's process_worklist (`test $0x2,%al` 30.0 %). processWorklist's delta fell from
  +2.56e8 to +1.1e7 cycles: the fence was the largest single item of Task 2's collector gap and is gone.
- **Temp-root push (Rulings R6/R1).** No `moar_c.MVM_gc_root_temp_push` symbol is sampled (or called on the collector
  path) in either the LTO or the non-LTO native build: `moar.root` inlines the push into allocateObject as the C
  inlines roots.h's. Task 2's +1.78e8 for the out-of-line copy is gone.
- **What remains in the collector: the object allocator.** allocateObject plus its export is +1.24e8 against
  MVM_gc_allocate_object, about the same as the faithful port's allocator + temp-root call (+1.45e8 for the two
  together), so inlining the push removed the call but not the cost. The native function is 786 bytes against the C's
  384 (nm -S); its hottest instructions (annot-n-alloc.txt) are the in-memory `incl 0x60(%rbx)` (num_temproots++,
  14.0 %), loads of the thread context and the STable flags, and a 5-register `push`/`pop` prologue and epilogue
  (10.5 % each at `push %rax` and `pop %r13`), where the C's (annot-c-alloc.txt) keeps num_temproots in a register and
  stores it (`mov %eax,0x60(%rbx)`, 11.5 %) and spends its top sample on a branch (22.0 %). One sampled run per side:
  this is where the remaining collector cycles sit, not a measured cost of one instruction. The next shape to look at
  is the allocator's code layout (the temp-root increment and the register pressure of the inlined slow paths), not a
  decision.
- **freeNurseryUncopied** +3.4e7 (+0.06 points): within what one sampled run resolves.
- **Non-LTO (attribution only, a different binary).** Collector samples c 3.87 %, n 4.35 % (+0.48 points), against
  c 3.59 %, f 5.25 % (+1.66 points) at Task 2; the native rows: allocateObject +1.36 against the export's -1.45 (net
  -0.09), freeNurseryUncopied +1.74 against -1.62 (net +0.12), MVM_gc_allocate_nursery +0.39 (still reached through
  the PLT from C, as at Task 2), gc.gen2.allocate +0.15. So without LTO most of Task 2's +1.66 points are gone too; what
  is left is the PLT-reached nursery allocator, which is a C caller's call and not something the Zig side can inline.

## Finding

The native rewrite more than halved the profiled cycle gap to the C control, 4.19 % to 1.90 % plain (4.80 % to 2.20 %
bad), and the remainder is **not resolvable at volume 100 000** under spec 7's rule on either setting (the gap is below
both sides' run-to-run spread), so no collector share is claimed for it (0.216 plain and 0.055 bad are computed only).
Of what Task 2 found in the collector, the `mfence` stall in processWorklist (+2.56e8) is gone with the R5 fence
(processWorklist +1.1e7 now, the same hot instruction as C's), and the out-of-line translate-c temp-root push (+1.78e8)
is gone with `moar.root`; the collector difference fell from +3.17e8 to +1.47e8 cycles, most of it now in the object
allocator, whose native body is twice the C's size and keeps `num_temproots` in memory (+1.24e8, one sampled run).
Outside the collector the rest of the profiled gap is the same scatter as Task 2 found (REPR `initialize` and
`gc_free`, frame dispatch, JIT code, libc), moving both ways and consistent with code placement: the -syms builds
themselves sit 0.8 % (C) and 2.3 % (native) away from their shipped siblings, so the profiled pair is not the shipped
one, whose wall ratio is 1.004 plain (ngc-crc-ab.md).
