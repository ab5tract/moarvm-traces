# GC A/B: crc-getter --volume=100000 --runs=5

3 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.56 [7.55-7.60] | 340800 [336672-344664] | 7.56 7.55 7.60 | 336672 340800 344664 |
| head | 7.57 [7.57-7.59] | 336652 [336504-348760] | 7.57 7.57 7.59 | 348760 336504 336652 |

Ratio head/base (medians of round medians): wall 1.001, RSS 0.988
