# ngc acceptance crc-getter A/B, three-sided: n/c 1.004 / 1.002 plain, 1.010 / 1.017 bad; f/c 1.027 / 0.990 plain, 1.033 / 0.983 bad

```
ngc crc-getter acceptance record (Task 9, step 3; spec 6)
Date:          2026-11-10, 19:24:00-19:51:29 CET (plain 19:24:00-19:37:17, --bad-packages 19:37:17-19:51:29)
MoarVM:        zig-native-gc at 1a70642f9 (src/zig identical to b0b3a48d6, where ng-n-base was built; not rebuilt);
               traces 1b65cba before this record
Toolchain:     Zig 0.17.1, zig cc = clang 22.1.8
Sides:         base ng-c-base (C collector + Zig hash engine, -Dzig-gc=false, Task 1), head ng-f-base (faithful port,
               frozen at f0582f365), head2 ng-n-base (native collector, b0b3a48d6); defaults (LTO, ReleaseFast,
               x86-64-v3, -Dgc-debug=0, nursery 16 MiB); 2850 exported names on all three, ng-n-base's set equal to
               ng-c-base's (nm -D, checked at Task 9)
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (rakudo zig-build-spec 042608fb82; execs
               /tmp/claude-1000/tune-zig-prefix/bin/moar, libmoar from LD_LIBRARY_PATH); nqp 41e7210ba
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Program:       tools/bench/gc/crc-getter.raku, spesh and precompilation on
Commands:      sh ngc-crc-ab-driver.sh /tmp/claude-1000/ngc/acc/crc (second stage of ngc-acceptance-master.sh):
               systemd-run --user --scope -q -p MemoryMax=8G sh tools/bench/gc/ab.sh --base=/tmp/claude-1000/ng-c-base/lib
                   --head=/tmp/claude-1000/ng-f-base/lib --head2=/tmp/claude-1000/ng-n-base/lib --rounds=7 --runs=5
                   --volume=100000 [--bad-packages] --out=...
               plain, then --bad-packages; one untimed warm-up per side; side order rotated over three per round
               (base head head2, head head2 base, head2 base head, ...); load < 2.0 before every run
Load:          1-minute load logged before each run (load.log): 1.02-1.55 over both settings
Raw:           ngc-crc-ab-raw/{plain,bad}/ (<side>-r<round>-<run>.time, .out, load.log, summary.md), {plain,bad}.stderr,
               runs.log (exit column is ab.sh's status: 0 and 0); smoke-* (the Step 1 smokes of ab.sh). All 210 timed
               runs exit 0 and print "RUN 5".
```

## Result

Cells: median of the 7 round medians [min-max of the round medians]; each round median over 5 runs. Spread = (max -
min of the round medians) / their median.

| setting | side | wall s | wall spread | peak RSS kB | RSS spread |
|---|---|---:|---:|---:|---:|
| plain | C ng-c-base | 7.48 [7.41-7.51] | 0.0134 | 342364 [338340-347060] | 0.0255 |
| plain | faithful ng-f-base | 7.68 [7.65-7.74] | 0.0117 | 338912 [334388-340916] | 0.0193 |
| plain | native ng-n-base | 7.51 [7.43-7.55] | 0.0160 | 343132 [336684-346976] | 0.0300 |
| --bad-packages | C ng-c-base | 7.93 [7.89-7.97] | 0.0101 | 344624 [341156-350536] | 0.0272 |
| --bad-packages | faithful ng-f-base | 8.19 [8.16-8.27] | 0.0134 | 338692 [336584-343640] | 0.0208 |
| --bad-packages | native ng-n-base | 8.01 [7.97-8.29] | 0.0400 | 350492 [340864-353664] | 0.0365 |

| setting | f/c wall | f/c RSS | n/c wall | n/c RSS | C spread wall / RSS |
|---|---:|---:|---:|---:|---:|
| plain | 1.027 | 0.990 | 1.004 | 1.002 | 0.0134 / 0.0255 |
| --bad-packages | 1.033 | 0.983 | 1.010 | 1.017 | 0.0101 / 0.0272 |

The faithful side reproduces Task 1's fixed baseline (ngc-baseline-crc.md: f/c 1.028 / 0.991 plain, 1.033 / 0.993
bad) on the same day as the native side, so the two ratios share their base.

## The aim (spec 6): "native/C within the C control's spread or at most 1.00 on both measures, both settings"

- plain wall: n/c 1.004, inside the C spread (0.004 against 0.0134; the native median 7.51 s lies in the C's round-
  median range 7.41-7.51, at its top). **Met, within spread**: the native collector is not shown to be faster or
  slower than the C control, and 1.004 is not read as a cost.
- plain RSS: n/c 1.002, inside the C spread (0.0255; 343132 kB lies in 338340-347060). **Met, within spread.**
- --bad-packages wall: n/c 1.010 (8.01 / 7.93); the C spread is 0.0101 (0.08 / 7.93), so the ratio sits exactly on
  the edge of the spread at the 0.01 s resolution of timev, and the native median (8.01 s) is above the C's highest
  round median (7.97 s). **Not met**: not within the spread by the range reading and not at most 1.00. The native
  side's own spread here is 0.040 (one round at 8.29 s, the rest 7.97-8.02); the other six round medians are 0.5-1.1 %
  above the C median.
- --bad-packages RSS: n/c 1.017, inside the C spread (0.0272; 350492 kB lies in 341156-350536, near its top).
  **Met, within spread.**

Verdict: the aim holds on three of four measures, each within the C control's spread (none at or below 1.00 beyond
it); --bad-packages wall misses it by the width of its own resolution (1.010 against a 0.0101 spread). Nothing here
is claimed inside a spread.

## Native against faithful (read off the shared base, not a gate)

Wall: plain 7.51 against 7.68 s (n/f 0.978; the ranges 7.43-7.55 and 7.65-7.74 do not overlap), --bad-packages 8.01
against 8.19 s (n/f 0.978; the ranges 7.97-8.29 and 8.16-8.27 overlap through the native side's one slow round). So
the rewrite recovers about 2.2 points of the faithful port's 2.7 (plain) and 3.3 (bad) point wall gap. RSS moves the
other way, n/f 1.012 plain (ranges overlap) and 1.035 bad (ranges 340864-353664 and 336584-343640 overlap): the
faithful side's RSS is below the C control's (0.990, 0.983) and the native side's is back at the C control's level,
inside its spread; no RSS change of the native side against the C control is claimed.
