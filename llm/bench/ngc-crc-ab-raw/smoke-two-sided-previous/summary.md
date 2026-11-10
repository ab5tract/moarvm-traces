# GC A/B: crc-getter --volume=1000 --runs=5

1 rounds, 1 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 0.51 [0.51-0.51] | 338784 [338784-338784] | 0.51 | 338784 |
| head | 0.54 [0.54-0.54] | 334252 [334252-334252] | 0.54 | 334252 |

Ratio head/base (medians of round medians): wall 1.059, RSS 0.987
