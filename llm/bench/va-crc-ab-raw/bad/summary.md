# GC A/B: crc-getter --volume=100000 --runs=5 --bad-packages

7 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.90 [7.87-7.97] | 343048 [338636-346640] | 7.88 7.88 7.90 7.90 7.97 7.90 7.87 | 344812 344460 343048 342896 346640 338636 341100 |
| head | 7.89 [7.81-8.31] | 348584 [340752-352720] | 7.87 7.89 7.81 8.31 7.82 7.91 8.01 | 352720 350576 347068 350872 348524 340752 348584 |

Ratio head/base (medians of round medians): wall 0.999, RSS 1.016
