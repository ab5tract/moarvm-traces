# GC A/B: crc-getter --volume=1000 --runs=5

3 rounds, 1 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 0.52 [0.51-0.52] | 334484 [332492-336228] | 0.52 0.51 0.52 | 336228 332492 334484 |
| head | 0.53 [0.52-0.57] | 326444 [325624-336660] | 0.52 0.57 0.53 | 326444 325624 336660 |
| head2 | 0.52 [0.52-0.52] | 332688 [330416-334684] | 0.52 0.52 0.52 | 330416 334684 332688 |

Ratio head/base (medians of round medians): wall 1.019, RSS 0.976
Ratio head2/base (medians of round medians): wall 1.000, RSS 0.995
