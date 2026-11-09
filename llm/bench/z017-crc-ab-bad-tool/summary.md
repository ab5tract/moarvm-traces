# GC A/B: crc-getter --volume=100000 --runs=5 --bad-packages

7 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 9.46 [9.44-9.55] | 344332 [341028-352976] | 9.53 9.44 9.51 9.46 9.45 9.55 9.46 | 347340 346948 341028 344332 342472 343572 352976 |
| head | 7.82 [7.78-7.85] | 349096 [343100-350764] | 7.84 7.82 7.80 7.79 7.82 7.85 7.78 | 345356 349320 344572 350196 349096 343100 350764 |

Ratio head/base (medians of round medians): wall 0.827, RSS 1.014
