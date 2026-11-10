# GC A/B: crc-getter --volume=100000 --runs=5

3 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.50 [7.49-7.56] | 344000 [340432-345172] | 7.49 7.50 7.56 | 340432 344000 345172 |
| head | 7.44 [7.41-7.44] | 344400 [344008-347048] | 7.41 7.44 7.44 | 344008 347048 344400 |

Ratio head/base (medians of round medians): wall 0.992, RSS 1.001
