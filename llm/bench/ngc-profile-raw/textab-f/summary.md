# GC A/B: crc-getter --volume=100000 --runs=5

3 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.66 [7.63-7.72] | 338808 [336860-342928] | 7.63 7.66 7.72 | 336860 338808 342928 |
| head | 7.68 [7.65-7.80] | 336828 [336768-344548] | 7.80 7.68 7.65 | 336828 336768 344548 |

Ratio head/base (medians of round medians): wall 1.003, RSS 0.994
