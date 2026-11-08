# GC proving-ground A/B, final: crc-getter, C collector against Zig collector (Task 10, Step 2)

```
GC final crc-getter A/B record (Task 10, step 2)
Date:          2026-11-08, 13:04-13:26 CET (plain 13:04:09-13:14:43, --bad-packages 13:14:43-13:25:57)
MoarVM:        zig-gc-port at 338211de6 (the last port commit is 8513443e6)
Traces:        f5b1132 (before this record)
Prefixes:      base = /tmp/claude-1000/gc-c-base (96d049123, the C collector with the Zig hash engine; zig build install,
               default options: LTO, ReleaseFast, x86-64-v3, -Dgc-debug=0, nursery 16 MiB)
               head = /tmp/claude-1000/gc-z-base (338211de6, the Zig collector; zig build install, default options;
               rebuilt by this task from HEAD, 56 s)
Runner:        /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m (rakudo zig-build-spec at 042608fb82;
               execs /tmp/claude-1000/tune-zig-prefix/bin/moar, libmoar from LD_LIBRARY_PATH);
               nqp zig-hash-strategies at 41e7210ba
CPU:           AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Program:       tools/bench/gc/crc-getter.raku (the user's program, verbatim), spesh and precompilation on
Commands:      tools/bench/gc/ab.sh --base=/tmp/claude-1000/gc-c-base/lib --head=/tmp/claude-1000/gc-z-base/lib \
                   --rounds=7 --runs=5 --volume=100000 --out=/tmp/claude-1000/gc-t10-ab-plain
               tools/bench/gc/ab.sh ... (the same) --bad-packages --out=/tmp/claude-1000/gc-t10-ab-bad
               (each run: timev.py <time> rakudo-m tools/bench/gc/crc-getter.raku --volume=100000 --runs=5 [--bad-packages];
               one untimed warm-up per side at --volume=1; side order rotated per round; load < 2.0 before every run)
Load:          1-minute load before each run: plain 0.62-1.31, --bad-packages 1.00-1.27 (load.log)
Raw:           gc-final-crc-ab-plain/ and gc-final-crc-ab-bad/: <side>-r<round>-<run>.time (timev.py), .out (the
               program's output), load.log, summary.md (written by ab.sh). All 140 runs exit 0.
```

Sizes: volume 100 000 only (the 1 000 000 A/B unit and the 10 000 000 single run were struck on 2026-11-08 by the user's ruling). Rule (plan Task 10 Step 2, spec section 6): head within the round spread of base, or a median ratio of at most 1.00, for wall and for peak RSS; a win beyond the spread is reported and investigated.

## Result

Cells: median of the 7 round medians [min-max of the round medians]; each round median over 5 runs.

| setting | side | wall s | peak RSS kB |
|---|---|---:|---:|
| plain | base (C) | 8.95 [8.91-9.02] | 341808 [338576-345088] |
| plain | head (Zig) | 9.05 [9.01-9.12] | 347020 [338668-351436] |
| --bad-packages | base (C) | 9.55 [9.51-9.58] | 345056 [342544-352848] |
| --bad-packages | head (Zig) | 9.58 [9.54-9.63] | 346836 [339232-352924] |

| setting | wall head/base | RSS head/base | wall verdict | RSS verdict |
|---|---:|---:|---|---|
| plain | 1.011 | 1.015 | FAIL: 9.05 is above base's spread (max 9.02) and the ratio is above 1.00 | FAIL: 347020 is above base's spread (max 345088) and the ratio is above 1.00 |
| --bad-packages | 1.003 | 1.005 | pass: 9.58 is within base's spread (9.51-9.58) | pass: 346836 is within base's spread (342544-352848) |

Round medians (from summary.md), plain wall: base 9.02 8.95 8.98 8.98 8.95 8.94 8.91, head 9.01 9.02 9.12 9.05 9.06 9.10 9.05; plain RSS: base 338852 341808 342772 344160 345088 340604 338576, head 342452 344728 347020 351436 338668 347256 347112.

Verdict: the plain setting fails this rule narrowly on both wall (+1.1 percent) and RSS (+1.5 percent); the spreads overlap (head's lowest round median is within base's range on both measures) but head's median is outside it. The --bad-packages setting passes on both. No win beyond the spread, so nothing to investigate as a behaviour change; the oracle (`gc-final-oracle.md`) shows identical collection decisions. Not rerun and not tuned (Task 10 brief). The spectest A/B (`gc-final-spectest.txt`) is the primary performance gate at this size.
