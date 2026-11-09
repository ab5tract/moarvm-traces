# GC A/B: crc-getter --volume=100000 --runs=5 --bad-packages

7 rounds, 5 runs per side per round, side order rotated per round.
Cells: median of the round medians [min-max of the round medians].

| side | wall s | peak RSS kB | round medians (wall s) | round medians (RSS kB) |
|---|---:|---:|---|---|
| base | 7.86 [7.84-7.95] | 345232 [338836-351072] | 7.87 7.86 7.95 7.87 7.85 7.85 7.84 | 350612 345232 347160 343260 351072 338836 340520 |
| head | 8.12 [8.03-8.23] | 342896 [337220-347236] | 8.08 8.17 8.12 8.12 8.06 8.23 8.03 | 339028 337220 340528 342896 344480 347236 344676 |

Ratio head/base (medians of round medians): wall 1.033, RSS 0.993
