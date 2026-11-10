# GC A/B: crc-getter --volume=100000 --runs=5

3 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.50 [7.49-7.55] | 344908 [338628-348340] | 7.50 7.55 7.49 | 348340 338628 344908 |
| head | 7.67 [7.62-7.68] | 338560 [336456-346744] | 7.62 7.67 7.68 | 338560 336456 346744 |

Ratio head/base (medians of round medians): wall 1.023, RSS 0.982
