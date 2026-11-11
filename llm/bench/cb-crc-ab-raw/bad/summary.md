# GC A/B: crc-getter --volume=100000 --runs=5 --bad-packages

7 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.98 [7.92-7.99] | 350388 [346816-352764] | 7.99 7.92 7.96 7.99 7.98 7.99 7.97 | 348936 351216 352764 350408 348488 346816 350388 |
| head | 7.99 [7.97-8.02] | 345016 [340384-349304] | 7.99 7.99 7.99 8.01 8.02 7.97 7.99 | 349304 340384 345016 344676 342740 346940 347396 |
| head2 | 8.06 [8.02-8.17] | 344388 [336860-352972] | 8.08 8.02 8.07 8.06 8.06 8.17 8.03 | 343036 352972 350672 336860 349084 342456 344388 |

Ratio head/base (medians of round medians): wall 1.001, RSS 0.985
Ratio head2/base (medians of round medians): wall 1.010, RSS 0.983
