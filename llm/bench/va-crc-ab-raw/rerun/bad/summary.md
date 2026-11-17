# GC A/B: crc-getter --volume=100000 --runs=5 --bad-packages

7 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.94 [7.83-8.16] | 340928 [340308-353120] | 7.93 7.94 7.99 7.88 7.83 8.16 8.04 | 340528 340308 340928 340628 346708 341116 353120 |
| head | 7.90 [7.80-8.06] | 344664 [340200-350668] | 7.82 7.80 7.81 7.90 8.06 8.05 8.02 | 344588 345024 350668 344888 340200 344524 344664 |

Ratio head/base (medians of round medians): wall 0.995, RSS 1.011
