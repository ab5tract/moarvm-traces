# GC A/B: crc-getter --volume=100000 --runs=5

3 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.50 [7.47-7.50] | 342564 [342456-344020] | 7.47 7.50 7.50 | 342456 342564 344020 |
| head | 7.68 [7.58-7.70] | 344692 [344688-346900] | 7.68 7.58 7.70 | 344688 344692 346900 |

Ratio head/base (medians of round medians): wall 1.024, RSS 1.006
