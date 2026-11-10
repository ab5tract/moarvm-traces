# GC A/B: crc-getter --volume=100000 --runs=5

3 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.58 [7.54-7.64] | 342656 [342288-344404] | 7.58 7.54 7.64 | 344404 342288 342656 |
| head | 7.64 [7.64-7.71] | 344360 [340704-344968] | 7.64 7.71 7.64 | 344968 344360 340704 |

Ratio head/base (medians of round medians): wall 1.008, RSS 1.005
