# va crc-getter A/B: Zig/C wall 0.993 / RSS 1.000 plain; --bad-packages wall 0.999, RSS 1.016 (outside), re-run 0.995 / 1.011 (inside)

```
va crc-getter record (Task 8, Step 5; spec 8)
Date:          2026-11-17, plain 14:58:57-15:10:03, --bad-packages 15:10:03-15:19:21, --bad-packages re-run
               15:19:52-15:29:15 CET
MoarVM:        zig-vmarray at bea13d101; both prefixes built at 472cf7e92 (va-prefixes.md, Task 8)
Sides:         base va-c-base (C array, -Dzig-reprs=false), head va-n-base (Zig array); defaults otherwise (LTO,
               ReleaseFast, x86-64-v3, -Dgc-debug=0, nursery 16 MiB); 2,850 exports each, the same list
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (execs /tmp/claude-1000/tune-zig-prefix/bin/moar,
               libmoar from LD_LIBRARY_PATH)
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap; an editor's cpptools process held one core throughout
               (not ours; va-prefixes.md)
Program:       tools/bench/gc/crc-getter.raku, spesh and precompilation on
Commands:      sh traces/llm/bench/va-crc-ab-driver.sh /tmp/claude-1000/va/t8/ev/crc-ab (seventh stage of
               va-evidence-master.sh), then the one allowed re-run of the setting that read outside the spread:
               sh traces/llm/bench/va-crc-ab-driver.sh /tmp/claude-1000/va/t8/ev/crc-ab-rerun bad; each is
               systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/ab.sh --base=/tmp/claude-1000/va-c-base/lib
                   --head=/tmp/claude-1000/va-n-base/lib --rounds=7 --runs=5 --volume=100000 [--bad-packages] --out=...
               one untimed warm-up per side; side order rotated per round; load < 2.0 before every run
Load:          1-minute load before each run (load.log): plain 1.10-1.86, --bad-packages 1.02-1.25, re-run 0.65-1.74
               (the stage started after the spectest's 24 jobs, at 13.03, and waited)
Raw:           va-crc-ab-raw/{plain,bad}/ and va-crc-ab-raw/rerun/bad/ (<side>-r<round>-<run>.time, .out, load.log,
               summary.md), {plain,bad}.stderr, runs.log (ab.sh's exit: 0, 0, 0). All 210 timed runs exit 0 and print
               "RUN 5".
```

## Result

Cells: median of the 7 round medians [min-max of the round medians]; each round median over 5 runs. Spread = (max -
min of the round medians) / their median. "Within the spread" is read as in ngc-crc-ab.md: the head's median of round
medians lies inside the control's min-max of round medians.

| setting | side | wall s | peak RSS kB |
|---|---|---:|---:|
| plain | C va-c-base | 7.48 [7.43-7.65] | 343092 [338596-347284] |
| plain | Zig va-n-base | 7.43 [7.33-7.56] | 343028 [336996-346492] |
| --bad-packages | C va-c-base | 7.90 [7.87-7.97] | 343048 [338636-346640] |
| --bad-packages | Zig va-n-base | 7.89 [7.81-8.31] | 348584 [340752-352720] |
| --bad-packages, re-run | C va-c-base | 7.94 [7.83-8.16] | 340928 [340308-353120] |
| --bad-packages, re-run | Zig va-n-base | 7.90 [7.80-8.06] | 344664 [340200-350668] |

| setting | Zig/C wall | C wall spread | in range | Zig/C RSS | C RSS spread | in range |
|---|---:|---:|---|---:|---:|---|
| plain | 0.993 | 0.0294 | yes (7.43 at the C's lowest round, 7.43) | 1.000 | 0.0253 | yes |
| --bad-packages | 0.999 | 0.0127 | yes | **1.016** | 0.0233 | **no**: 348584 above the C's highest round, 346640 |
| --bad-packages, re-run | 0.995 | 0.0416 | yes | 1.011 | 0.0376 | yes (344664 in 340308-353120) |

## Gate (spec 8: "head/control wall and RSS within the control's spread"; one re-run of an affected setting allowed, both reported)

- plain wall 0.993 and plain RSS 1.000: **within the spread, pass**.
- --bad-packages wall 0.999 (first run) and 0.995 (re-run): **within the spread, pass**.
- --bad-packages RSS: the first reading, 1.016, is **outside** the C's range (the Zig median 348,584 kB lies 1,944 kB
  above the C's highest round median, though the ratio's distance from 1, 0.016, is under the C's own spread,
  0.023); per the rule the setting was re-run once: 1.011, the Zig median 344,664 kB **inside** the C's range
  (340,308-353,120 kB). **Pass after the one re-run**; both readings are reported here.

Nothing is claimed inside the spreads: the Zig array's crc-getter wall time and peak RSS are not distinguishable from
the C array's at this resolution. Across the two --bad-packages runs the Zig side's RSS medians (348,584 and
344,664 kB) sit above the C side's (343,048 and 340,928 kB) by 1.1-1.6 %; the plain setting shows no such offset
(1.000). That is within the C's own round-to-round spread both times and is recorded, not read as a cost; ruling 4's
named suspect (the defensive NULL test in `kinds.slots` on every element access) would show as wall time, not RSS,
and wall is at or below 1.00 in all three settings.
