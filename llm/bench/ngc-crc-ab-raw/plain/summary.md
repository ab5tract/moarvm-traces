# GC A/B: crc-getter --volume=100000 --runs=5

7 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.48 [7.41-7.51] | 342364 [338340-347060] | 7.51 7.41 7.48 7.42 7.50 7.51 7.46 | 340000 344672 342512 338380 347060 342364 338340 |
| head | 7.68 [7.65-7.74] | 338912 [334388-340916] | 7.74 7.66 7.68 7.71 7.71 7.68 7.65 | 340512 334388 338912 340424 340916 338796 336536 |
| head2 | 7.51 [7.43-7.55] | 343132 [336684-346976] | 7.51 7.55 7.51 7.48 7.43 7.52 7.47 | 343864 343132 344368 346976 341028 336684 336832 |

Ratio head/base (medians of round medians): wall 1.027, RSS 0.990
Ratio head2/base (medians of round medians): wall 1.004, RSS 1.002
