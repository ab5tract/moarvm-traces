# GC A/B: crc-getter --volume=100000 --runs=5

3 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.48 [7.44-7.49] | 342920 [340844-344772] | 7.48 7.49 7.44 | 344772 340844 342920 |
| head | 7.50 [7.49-7.50] | 347224 [346528-349056] | 7.50 7.49 7.50 | 346528 349056 347224 |

Ratio head/base (medians of round medians): wall 1.003, RSS 1.013
