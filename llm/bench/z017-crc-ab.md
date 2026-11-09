# zig-017 crc-getter A/B (Task 5, Step 3): Z17/C17 1.022 / 0.994 plain, 1.027 / 1.001 bad; C17/C16 0.829 / 0.995 plain, 0.827 / 1.014 bad

```
zig-017 crc-getter A/B record (Task 5, step 3)
Date:          2026-11-09, 00:43-01:21 CET (new plain 00:43:08-00:52:23, new bad -01:01:41, tool plain -01:11:13,
               tool bad -01:21:23)
MoarVM:        zig-017 at b1bbb9dd4; traces 175921d before this record
Pairs:         new  = base g7-c-base (0.17, C collector + Zig hash engine), head g7-z-base (0.17, Zig collector)
               tool = base gc-c-base (0.16, C collector + Zig hash engine, 96d049123), head g7-c-base (0.17, the same
                      configuration at b1bbb9dd4)
               (z017-prefixes.md; default options: LTO, ReleaseFast, x86-64-v3, -Dgc-debug=0, nursery 16 MiB)
Toolchains:    0.16 = Zig 0.16.0 (zig cc clang 21); 0.17 = Zig 0.17.1 (zig cc clang 22.1.8)
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (rakudo zig-build-spec 042608fb82; execs
               /tmp/claude-1000/tune-zig-prefix/bin/moar, libmoar from LD_LIBRARY_PATH); nqp 41e7210ba
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Program:       tools/bench/gc/crc-getter.raku, spesh and precompilation on
Commands:      sh z017-crc-ab-driver.sh /tmp/claude-1000/z017/t5/crc new tool, which per pair and setting runs
               systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/ab.sh --base=/tmp/claude-1000/<B>/lib \
                   --head=/tmp/claude-1000/<H>/lib --rounds=7 --runs=5 --volume=100000 [--bad-packages] --out=...
               (one untimed warm-up per side at --volume=1; side order rotated per round; ab.sh waits for load < 2.0
               before every run)
Load:          1-minute load logged before each run (load.log): new plain 1.08-2.03 (one reading of 2.03 before
               round 1 head run 2: ab.sh's check passed under 2.0 and the logged re-read a moment later was 2.03),
               new bad 1.01-1.45, tool plain 1.03-1.36, tool bad 1.06-1.45. No moar or rakudo process before each
               ab.sh invocation (z017-crc-ab-runs.log; ab.sh itself has no per-round process check).
Raw:           z017-crc-ab-{plain,bad}-{new,tool}/: <side>-r<round>-<run>.time (timev.py), .out, load.log, summary.md
               (ab.sh), ab.stderr; z017-crc-ab-runs.log. All 280 timed runs exit 0.
```

## Result

Cells: median of the 7 round medians [min-max of the round medians]; each round median over 5 runs.

| pair | setting | base | base wall s | base RSS kB | head | head wall s | head RSS kB |
|---|---|---|---:|---:|---|---:|---:|
| new | plain | C17 | 7.38 [7.37-7.48] | 342720 [336844-349052] | Z17 | 7.54 [7.51-7.58] | 340568 [336456-349048] |
| new | --bad-packages | C17 | 7.81 [7.78-7.84] | 342868 [338880-352832] | Z17 | 8.02 [7.99-8.11] | 343060 [340144-348812] |
| tool | plain | C16 | 8.88 [8.86-8.92] | 344344 [336636-346700] | C17 | 7.36 [7.33-7.38] | 342600 [340472-347052] |
| tool | --bad-packages | C16 | 9.46 [9.44-9.55] | 344332 [341028-352976] | C17 | 7.82 [7.78-7.85] | 349096 [343100-350764] |

| ratio (head/base, medians of round medians) | wall | RSS | Campaign 4 (Z16/C16, gc-final-crc-ab.md) |
|---|---:|---:|---|
| Z17/C17 plain | 1.022 | 0.994 | 1.011 / 1.015 |
| Z17/C17 --bad-packages | 1.027 | 1.001 | 1.003 / 1.005 |
| C17/C16 plain | 0.829 | 0.995 | (n/a) |
| C17/C16 --bad-packages | 0.827 | 1.014 | (n/a) |

Round medians, Z17/C17 plain wall: C17 7.48 7.39 7.37 7.45 7.37 7.37 7.38, Z17 7.54 7.51 7.58 7.55 7.53 7.55 7.54;
--bad-packages wall: C17 7.81 7.84 7.82 7.80 7.81 7.80 7.78, Z17 8.03 8.07 8.11 8.00 8.01 8.02 7.99.

## Reading (recorded, not gated)

- The toolchain: the same C-collector configuration runs the crc-getter about 17 percent faster in wall time
  built by Zig 0.17.1 / clang 22.1.8 than by Zig 0.16.0 (8.88 -> 7.36 s plain, 9.46 -> 7.82 s bad), with RSS
  unchanged within the spreads (the bad-packages RSS ratio 1.014 is within the overlap of the two spreads). The
  0.16 base here (8.88 / 9.46 s) reproduces Campaign 4's base (8.95 / 9.55 s) within 1 percent, so the machine
  is comparable across the two sessions. Besides the compiler, the two sides differ in commit (96d049123 vs
  b1bbb9dd4): src/gc/orchestrate.c and src/gc/roots.c carry the six interlude bug fixes (93 insertions, 35
  deletions), and src/zig/core/hash has 0.17 spelling changes (54/54 lines, Task 3); no other C source under
  src/ changed. Those fixes are on the collector's coordination paths, not the allocation hot path, so most of
  the gain is plausibly the compiler, but this record does not split it further.
- The port on the new toolchain: the Zig collector is 2.2 percent (plain) and 2.7 percent (bad) slower than the
  C collector in wall time, against 1.1 and 0.3 percent on 0.16; RSS is equal within the spreads. Both wall
  ratios are under the plan's 1.03 stop-and-report threshold; Z17's whole round-median range is above C17's on
  both settings. Clang 22 gained more on the C collector than Zig 0.17's LLVM gained on the Zig port; this is the
  starting point for the Zig-native GC campaign.
