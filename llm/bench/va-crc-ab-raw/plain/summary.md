# GC A/B: crc-getter --volume=100000 --runs=5

7 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.48 [7.43-7.65] | 343092 [338596-347284] | 7.65 7.47 7.43 7.48 7.45 7.48 7.53 | 344568 347284 342788 344056 342908 343092 338596 |
| head | 7.43 [7.33-7.56] | 343028 [336996-346492] | 7.56 7.54 7.41 7.47 7.40 7.33 7.43 | 344856 342876 346492 342964 343028 336996 344224 |

Ratio head/base (medians of round medians): wall 0.993, RSS 1.000
