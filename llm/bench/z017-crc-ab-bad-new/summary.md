# GC A/B: crc-getter --volume=100000 --runs=5 --bad-packages

7 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.81 [7.78-7.84] | 342868 [338880-352832] | 7.81 7.84 7.82 7.80 7.81 7.80 7.78 | 342868 352832 338880 348680 340716 340772 347068 |
| head | 8.02 [7.99-8.11] | 343060 [340144-348812] | 8.03 8.07 8.11 8.00 8.01 8.02 7.99 | 343060 344836 340144 342748 348812 340416 347204 |

Ratio head/base (medians of round medians): wall 1.027, RSS 1.001
