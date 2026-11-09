# GC A/B: crc-getter --volume=100000 --runs=5

7 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 8.88 [8.86-8.92] | 344344 [336636-346700] | 8.88 8.88 8.86 8.89 8.90 8.92 8.88 | 346544 340584 339056 346700 346328 344344 336636 |
| head | 7.36 [7.33-7.38] | 342600 [340472-347052] | 7.36 7.33 7.36 7.33 7.38 7.38 7.38 | 347052 342524 342600 344232 344628 340472 342588 |

Ratio head/base (medians of round medians): wall 0.829, RSS 0.995
