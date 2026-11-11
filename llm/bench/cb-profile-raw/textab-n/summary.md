# GC A/B: crc-getter --volume=100000 --runs=5

3 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.58 [7.57-7.59] | 344468 [342576-344800] | 7.58 7.57 7.59 | 342576 344800 344468 |
| head | 7.50 [7.44-7.50] | 338064 [336492-338236] | 7.44 7.50 7.50 | 338236 336492 338064 |

Ratio head/base (medians of round medians): wall 0.989, RSS 0.981
