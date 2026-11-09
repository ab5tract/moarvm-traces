# GC A/B: crc-getter --volume=100000 --runs=5

3 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.47 [7.42-7.48] | 344940 [338360-346880] | 7.48 7.47 7.42 | 346880 338360 344940 |
| head | 7.36 [7.35-7.41] | 340312 [338952-346096] | 7.41 7.35 7.36 | 346096 340312 338952 |

Ratio head/base (medians of round medians): wall 0.985, RSS 0.987
