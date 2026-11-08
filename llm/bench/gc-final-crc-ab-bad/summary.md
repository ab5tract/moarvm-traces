# GC A/B: crc-getter --volume=100000 --runs=5 --bad-packages

7 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 9.55 [9.51-9.58] | 345056 [342544-352848] | 9.58 9.51 9.56 9.54 9.55 9.57 9.53 | 346560 345056 342544 343292 343280 346668 352848 |
| head | 9.58 [9.54-9.63] | 346836 [339232-352924] | 9.54 9.58 9.63 9.58 9.55 9.60 9.61 | 349204 339232 352924 343020 349024 346836 345084 |

Ratio head/base (medians of round medians): wall 1.003, RSS 1.005
