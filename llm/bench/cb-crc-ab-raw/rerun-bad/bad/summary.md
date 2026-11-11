# GC A/B: crc-getter --volume=100000 --runs=5 --bad-packages

7 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.95 [7.93-8.00] | 349092 [336140-350732] | 7.94 8.00 7.97 7.98 7.93 7.95 7.94 | 350732 350444 339320 349140 342964 349092 336140 |
| head | 8.04 [7.92-8.13] | 347556 [342816-353544] | 7.97 8.10 7.92 8.13 7.97 8.04 8.07 | 342816 347556 353544 347028 350768 344780 351244 |
| head2 | 8.03 [7.99-8.11] | 350272 [342128-354600] | 8.03 7.99 8.03 8.11 8.01 8.06 7.99 | 354600 350860 342128 350908 344624 349196 350272 |

Ratio head/base (medians of round medians): wall 1.011, RSS 0.996
Ratio head2/base (medians of round medians): wall 1.010, RSS 1.003
