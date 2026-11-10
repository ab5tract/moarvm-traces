# GC A/B: crc-getter --volume=100000 --runs=5

3 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.54 [7.53-7.60] | 342408 [341036-342860] | 7.53 7.60 7.54 | 342860 342408 341036 |
| head | 7.58 [7.56-7.59] | 343016 [336748-344848] | 7.59 7.56 7.58 | 343016 336748 344848 |

Ratio head/base (medians of round medians): wall 1.005, RSS 1.002
