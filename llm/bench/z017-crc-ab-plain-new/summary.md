# GC A/B: crc-getter --volume=100000 --runs=5

7 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.38 [7.37-7.48] | 342720 [336844-349052] | 7.48 7.39 7.37 7.45 7.37 7.37 7.38 | 342720 345164 344740 349052 340884 342680 336844 |
| head | 7.54 [7.51-7.58] | 340568 [336456-349048] | 7.54 7.51 7.58 7.55 7.53 7.55 7.54 | 343804 336456 336652 341316 338404 349048 340568 |

Ratio head/base (medians of round medians): wall 1.022, RSS 0.994
