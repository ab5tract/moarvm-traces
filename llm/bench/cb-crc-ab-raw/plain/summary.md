# GC A/B: crc-getter --volume=100000 --runs=5

7 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.53 [7.47-7.54] | 346396 [340460-348640] | 7.49 7.52 7.47 7.54 7.54 7.53 7.53 | 346396 346736 348640 346192 340460 344604 347032 |
| head | 7.52 [7.47-7.55] | 340916 [336464-346116] | 7.53 7.52 7.50 7.49 7.47 7.55 7.55 | 340584 341080 336464 345024 340172 346116 340916 |
| head2 | 7.54 [7.51-7.59] | 340792 [336492-349036] | 7.59 7.54 7.54 7.59 7.51 7.52 7.58 | 349036 340792 338588 336492 344792 347004 340500 |

Ratio head/base (medians of round medians): wall 0.999, RSS 0.984
Ratio head2/base (medians of round medians): wall 1.001, RSS 0.984
