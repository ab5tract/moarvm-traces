# GC A/B: crc-getter --volume=100000 --runs=5

7 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 8.95 [8.91-9.02] | 341808 [338576-345088] | 9.02 8.95 8.98 8.98 8.95 8.94 8.91 | 338852 341808 342772 344160 345088 340604 338576 |
| head | 9.05 [9.01-9.12] | 347020 [338668-351436] | 9.01 9.02 9.12 9.05 9.06 9.10 9.05 | 342452 344728 347020 351436 338668 347256 347112 |

Ratio head/base (medians of round medians): wall 1.011, RSS 1.015
