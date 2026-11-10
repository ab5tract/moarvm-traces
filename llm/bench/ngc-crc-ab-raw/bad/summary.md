# GC A/B: crc-getter --volume=100000 --runs=5 --bad-packages

7 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.93 [7.89-7.97] | 344624 [341156-350536] | 7.95 7.93 7.92 7.93 7.89 7.95 7.97 | 345000 349128 341976 343308 341156 344624 350536 |
| head | 8.19 [8.16-8.27] | 338692 [336584-343640] | 8.17 8.20 8.16 8.19 8.27 8.18 8.21 | 338692 340808 343640 336584 343268 337396 338316 |
| head2 | 8.01 [7.97-8.29] | 350492 [340864-353664] | 8.00 8.29 8.02 8.01 7.97 7.99 8.01 | 348760 351028 349120 350492 351004 340864 353664 |

Ratio head/base (medians of round medians): wall 1.033, RSS 0.983
Ratio head2/base (medians of round medians): wall 1.010, RSS 1.017
