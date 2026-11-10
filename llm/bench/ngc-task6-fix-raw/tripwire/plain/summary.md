# GC A/B: crc-getter --volume=100000 --runs=5

3 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.50 [7.44-7.51] | 342696 [342188-346356] | 7.51 7.44 7.50 | 346356 342696 342188 |
| head | 7.62 [7.61-7.63] | 343876 [337004-345876] | 7.62 7.61 7.63 | 337004 343876 345876 |

Ratio head/base (medians of round medians): wall 1.016, RSS 1.003
