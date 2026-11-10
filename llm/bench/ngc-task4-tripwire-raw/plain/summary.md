# GC A/B: crc-getter --volume=100000 --runs=5

3 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.60 [7.59-7.61] | 341980 [338100-343948] | 7.61 7.59 7.60 | 343948 338100 341980 |
| head | 7.64 [7.60-7.69] | 346692 [336684-346952] | 7.69 7.64 7.60 | 346952 336684 346692 |

Ratio head/base (medians of round medians): wall 1.005, RSS 1.014
