# cb acceptance crc-getter A/B, three-sided: cb/C 1.001 / 0.984 plain, 1.010 / 0.983 bad; same-day ng-n/C 0.999 / 0.984 plain, 1.001 / 0.985 bad; tripwire pass on all four (bad wall on the bound; bad re-run cb/C 1.010 against ng-n/C 1.011, pass), aim 3 of 4 (bad wall miss on both runs)

```
cb crc-getter acceptance record (Task 3, step 1; spec 7)
Date:          2026-11-11, 19:04:15-19:31:40 CET (plain 19:04:15-19:17:30, --bad-packages 19:17:30-19:31:40)
MoarVM:        gc-call-boundary at 11a2e2e84; cb-n-base built at 6cfbe7e3f (src/ as at c5aebb78a, cb-prefixes.md), not
               rebuilt; traces e4758f9 before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Sides:         base ng-c-base (C collector + Zig hash engine, -Dzig-gc=false, Campaign 6 Task 1), head ng-n-base
               (Campaign 6's native collector, b0b3a48d6, the binary ngc-crc-ab.md measured), head2 cb-n-base (this
               branch: the six noinline definitions and the two imports); defaults (LTO, ReleaseFast, x86-64-v3,
               -Dgc-debug=0, nursery 16 MiB); 2850 exported names on all three (cb-oracle.md, cb-audit.md)
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (execs /tmp/claude-1000/tune-zig-prefix/bin/moar,
               libmoar from LD_LIBRARY_PATH); nqp 41e7210ba
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Program:       tools/bench/gc/crc-getter.raku, spesh and precompilation on
Commands:      sh traces/llm/bench/cb-crc-ab-driver.sh /tmp/claude-1000/cb/crc:
               first tools/bench/gc/call-boundary.sh /tmp/claude-1000/cb-n-syms/lib (exit 0, all 18 rows; the driver
               refuses to start otherwise), then
               systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/ab.sh --base=/tmp/claude-1000/ng-c-base/lib
                   --head=/tmp/claude-1000/ng-n-base/lib --head2=/tmp/claude-1000/cb-n-base/lib --rounds=7 --runs=5
                   --volume=100000 [--bad-packages] --out=...
               plain, then --bad-packages; one untimed warm-up per side; side order rotated over three per round;
               load < 2.0 before every run (ab.sh); nothing else ran on the machine
Load:          1-minute load logged before each run (load.log): plain 0.21-1.42, --bad-packages 1.06-1.41
Raw:           cb-crc-ab-raw/{plain,bad}/ (<side>-r<round>-<run>.time, .out, load.log, summary.md), {plain,bad}.stderr,
               runs.log (exit column is ab.sh's status through the scope: 0 and 0; call-boundary exit 0),
               call-boundary.out, driver.out. All 210 timed runs exit 0 and print "RUN 5" (recounted from the .time
               and .out files).
```

## Result

Cells: median of the 7 round medians [min-max of the round medians]; each round median over 5 runs. Spread = (max -
min of the round medians) / their median. Ratios recomputed from the .time files (they equal summary.md's).

| setting | side | wall s | wall spread | peak RSS kB | RSS spread |
|---|---|---:|---:|---:|---:|
| plain | C ng-c-base | 7.53 [7.47-7.54] | 0.0093 | 346396 [340460-348640] | 0.0236 |
| plain | native ng-n-base (head) | 7.52 [7.47-7.55] | 0.0106 | 340916 [336464-346116] | 0.0283 |
| plain | cb cb-n-base (head2) | 7.54 [7.51-7.59] | 0.0106 | 340792 [336492-349036] | 0.0368 |
| --bad-packages | C ng-c-base | 7.98 [7.92-7.99] | 0.0088 | 350388 [346816-352764] | 0.0170 |
| --bad-packages | native ng-n-base (head) | 7.99 [7.97-8.02] | 0.0063 | 345016 [340384-349304] | 0.0259 |
| --bad-packages | cb cb-n-base (head2) | 8.06 [8.02-8.17] | 0.0186 | 344388 [336860-352972] | 0.0468 |

| setting | measure | head/C | head2/C | C spread | head2/C - head/C | tripwire | aim |
|---|---|---:|---:|---:|---:|---|---|
| plain | wall | 0.999 | 1.001 | 0.0093 | +0.0027 | pass | pass (inside the spread) |
| plain | RSS | 0.984 | 0.984 | 0.0236 | -0.0004 | pass | pass (at most 1.00) |
| --bad-packages | wall | 1.001 | 1.010 | 0.0088 | +0.0088 | pass (on the bound) | **miss** |
| --bad-packages | RSS | 0.985 | 0.983 | 0.0170 | -0.0018 | pass | pass (at most 1.00) |

Round medians, wall s: plain C 7.49 7.52 7.47 7.54 7.54 7.53 7.53; head 7.53 7.52 7.50 7.49 7.47 7.55 7.55; head2
7.59 7.54 7.54 7.59 7.51 7.52 7.58. --bad-packages C 7.99 7.92 7.96 7.99 7.98 7.99 7.97; head 7.99 7.99 7.99 8.01
8.02 7.97 7.99; head2 8.08 8.02 8.07 8.06 8.06 8.17 8.03.

## The tripwire (spec 7): "no new/C ratio above the same-day native/C ratio by more than the C spread"

Pass on all four measures. --bad-packages wall sits exactly on the bound: head2 - head is 8.06 - 7.99 = 0.07 s and
the C spread is 7.99 - 7.92 = 0.07 s, both over the same C median 7.98, so 0.0088 against 0.0088 at timev's 0.01 s
resolution; the ratio is not above the bound, so it is not a crossing. The controller nevertheless ruled the one
seven-round re-run of the Global Constraints (section "Re-run" below; it reads -0.0013, a pass). It is not a margin either: the head2 round medians (8.02-8.17) and the head's (7.97-8.02) touch only at 8.02,
and six of the seven head2 rounds are above every head round. On this day the change reads as up to about 0.9 % slower
than Campaign 6's native build on --bad-packages wall, by an amount equal to the C control's own spread; on plain wall
it is +0.27 points (inside every spread), and RSS is unchanged on both settings.

## The aim (spec 7): "new/C within the C control's spread on wall and RSS, both settings" (4 of 4)

- plain wall: 1.001, inside the C spread (0.0093; the cb median 7.54 s is the C's top round median). **pass**
- plain RSS: 0.984, at most 1.00 (and inside the spread). **pass**
- --bad-packages wall: 1.010 (8.06 / 7.98) against a C spread of 0.0088; the cb median is above the C's highest round
  median (7.99) and the ratio is above 1.00. **miss**
- --bad-packages RSS: 0.983, at most 1.00. **pass**

Aim: **3 of 4, --bad-packages wall missed** (1.010 against 0.0088). Campaign 6's binary, measured the same hour, reads
1.001 there (inside the spread; it read 1.010 at Campaign 6, ngc-crc-ab.md), so the day's noise against the C does
not explain the miss: it is head2's, against the head's 1.001 on the same base. Per spec 7 and section 13 the aim is
reported, not gated; the profile gate (cb-profile.md: pass) decides inclusion, and that record finds the remaining
gap not resolvable in the collector at this volume: the remaining wall gap is outside the collector as far as the
profile resolves.

## Re-run, --bad-packages only (controller ruling, 2026-11-11)

The first run's bad-wall reading sat exactly on the tripwire bound with six of seven cb rounds above every ng-n round;
the controller ruled that too thin to carry the inclusion decision and asked for the one seven-round re-run the
Global Constraints allow, same sides and parameters, --bad-packages only.

```
Date:          2026-11-11, 19:50:46-20:04:56 CET
Command:       (from the MoarVM checkout; the driver runs both settings, so ab.sh directly)
               systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/ab.sh --base=/tmp/claude-1000/ng-c-base/lib
                   --head=/tmp/claude-1000/ng-n-base/lib --head2=/tmp/claude-1000/cb-n-base/lib --rounds=7 --runs=5
                   --volume=100000 --bad-packages --out=/tmp/claude-1000/cb/crc-rerun/bad
Load:          start 0.18 (no moar or rakudo process running); per run 0.18-1.42 (load.log)
Raw:           cb-crc-ab-raw/rerun-bad/ (bad/ as the first run's layout, bad.stderr, runs.log: exit 0). All 105 timed runs
               exit 0 and print "RUN 5".
```

| side | wall s | wall spread | peak RSS kB | RSS spread |
|---|---:|---:|---:|---:|
| C ng-c-base | 7.95 [7.93-8.00] | 0.0088 | 349092 [336140-350732] | 0.0418 |
| native ng-n-base (head) | 8.04 [7.92-8.13] | 0.0261 | 347556 [342816-353544] | 0.0309 |
| cb cb-n-base (head2) | 8.03 [7.99-8.11] | 0.0149 | 350272 [342128-354600] | 0.0356 |

| measure | head/C | head2/C | C spread | head2/C - head/C | tripwire | aim |
|---|---:|---:|---:|---:|---|---|
| wall | 1.011 | 1.010 | 0.0088 | -0.0013 | pass | **miss** |
| RSS | 0.996 | 1.003 | 0.0418 | +0.0078 | pass | pass (inside the spread) |

Round medians, wall s: C 7.94 8.00 7.97 7.98 7.93 7.95 7.94; head 7.97 8.10 7.92 8.13 7.97 8.04 8.07; head2 8.03 7.99
8.03 8.11 8.01 8.06 7.99. Ordering: **0 of 7** cb round medians lie above every ng-n round median (the ng-n top is
8.13; the first run had 6 of 7 above 8.02). The two native builds' ranges overlap almost entirely (7.92-8.13 and
7.99-8.11); on this run cb reads 0.1 % faster than ng-n on bad wall, where the first run read 0.9 % slower. The
first run's ordering is not reproduced, so it reads as round-to-round noise of the head sides, which is wider than
the C control's spread (the head's own spread here is 0.0261).

The aim on this run: bad wall 1.010 against a C spread of 0.0088 (8.03 s above the C's top round median 8.00):
**miss**, the same ratio as the first run; bad RSS 1.003, inside the spread: **pass**.

**Combined verdict.** Tripwire: **pass** (neither run crosses: first run bad wall +0.0088 on its bound of 0.0088,
re-run -0.0013 against 0.0088; RSS -0.0018 and +0.0078 against 0.0170 and 0.0418; plain from the first run only,
+0.0027 and -0.0004). Aim: bad wall missed on both runs (1.010, 1.010), bad RSS passed on both (0.983, 1.003); over the
original four measures **3 of 4**, --bad-packages wall missed. The same-day native/C bad wall moved 1.001 to 1.011
between the two runs while cb/C stayed 1.010: the miss is of the order of the native builds' own spread, and the
profile (cb-profile.md) finds no resolvable gap in the collector.
