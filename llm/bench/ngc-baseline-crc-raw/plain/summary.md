# GC A/B: crc-getter --volume=100000 --runs=5

7 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.42 [7.40-7.43] | 342064 [334688-346936] | 7.40 7.42 7.43 7.42 7.41 7.42 7.41 | 340376 339832 346324 342064 342632 346936 334688 |
| head | 7.63 [7.59-7.71] | 338896 [334780-345140] | 7.71 7.63 7.65 7.63 7.59 7.59 7.61 | 338440 344936 340512 345140 338896 334780 338796 |

Ratio head/base (medians of round medians): wall 1.028, RSS 0.991
