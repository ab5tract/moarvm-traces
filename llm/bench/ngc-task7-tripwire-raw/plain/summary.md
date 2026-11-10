# GC A/B: crc-getter --volume=100000 --runs=5

3 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.49 [7.47-7.52] | 341008 [338944-348360] | 7.47 7.52 7.49 | 348360 341008 338944 |
| head | 7.63 [7.63-7.63] | 343128 [342704-344792] | 7.63 7.63 7.63 | 342704 344792 343128 |

Ratio head/base (medians of round medians): wall 1.019, RSS 1.006
