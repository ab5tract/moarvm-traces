# Bake-off final: default ladder against the C engine (HEAD c4df263dc, 2026-11-03)

Recipe of `tuning-lto-default-nqp.md`: two builds of the branch head, zig-lto (`zig build install --prefix <p>`, the default build) and c-lto (`-Dzig-impl=false`), each prefix's own `bin/moar` with nqp's stage0 (tune-zig-prefix's share/nqp/lib), `hash-bench.nqp --engine=<v> --sizes=4,16,32,63,64,65,128,256,1024,16384 --runs=5 --nth=all` and `--sizes=49,97`, 9 rounds, the variant order rotated per round, no `--strategy` (the default ladder, set 0). Cells: median of the 9 round medians, ratio [zig-lto min-max / c-lto min-max of the round medians] ns, from `hash-compare.pl`. Verdict rule as that record's: ratio <= 1.05 or overlapping spreads; the 4-size cells are warm-up and not read; insert_nth 65 is the migration cell (judged by the 97th, see the resize rows). Two complete runs (run 1 rounds 1-9, run 2 rounds 2-10 of the rotation), the machine idle (1-min load 0.7-1.25 at the round starts). The tables give the spread of the round medians; to reproduce the exact spreads by re-running `hash-compare.pl` on the raw TSVs, drop the round column and use only the harness's column 4 (the round median) as the ns column. Raw: `bakeoff-final-nqp-r<run>-<variant>.tsv` (variant, round, then the harness's columns; the resize file's rows appended), load logs `bakeoff-final-nqp-r<run>-load.log`.

New since the tuning record: the harness also emits overwrite, clone and iterate_delete; the six original ops are judged here (53 cells, the record's count), the three new ops go in their own informational table.

## Verdict

51/53 under the x86-64-v3 default, in both runs: insert_nth 128 and 256 fail the rule with disjoint spreads, annotated "pre-existing shortfall (tuning record lines 136/205), unchanged by this branch per the base-vs-HEAD A/B". The CPU default was tested as the mover and is not (check 1); the cells are the tuning campaign's pre-existing Robin Hood insert_nth shortfall. No other cell of the six original ops fails.

## Run 1: zig-lto / c-lto, the six original ops

| op | size | ratio [zig-lto min-max / c-lto min-max] ns | verdict |
|---|---:|---|---|
| delete | 4 | 0.83 [10.99-15.19 / 12.95-25.84] | warm-up, not read |
| delete | 16 | 0.72 [10.1-10.29 / 13.9-14.26] | pass (<1.0) |
| delete | 32 | 0.82 [11.33-12.28 / 13.85-14.28] | pass (<1.0) |
| delete | 49 | 1.15 [11.85-17.42 / 13.05-13.72] | resize cell, not judged (reported) |
| delete | 63 | 0.88 [11.81-12.66 / 13.69-14.18] | pass (<1.0) |
| delete | 64 | 0.89 [11.69-12.88 / 13.82-14.1] | pass (<1.0) |
| delete | 65 | 0.97 [13.25-13.45 / 13.66-14.05] | pass (<1.0) |
| delete | 97 | 0.97 [12.37-12.98 / 13.04-13.4] | resize cell, not judged (reported) |
| delete | 128 | 0.97 [13.17-13.66 / 13.58-13.89] | pass (<1.0) |
| delete | 256 | 0.96 [13.2-13.71 / 13.7-14.1] | pass (<1.0) |
| delete | 1024 | 0.97 [13.39-14.45 / 13.99-14.26] | pass (<1.0) |
| delete | 16384 | 0.96 [14.88-16.84 / 15.46-16.31] | pass (<1.0) |
| insert | 4 | 0.86 [24.2-55.91 / 25.51-51.97] | warm-up, not read |
| insert | 16 | 0.42 [21.1-21.52 / 47.94-51.47] | pass (<1.0) |
| insert | 32 | 0.40 [20.6-21.57 / 52.33-53.36] | pass (<1.0) |
| insert | 49 | 0.34 [18.94-22.8 / 61.98-90.78] | resize cell, not judged (reported) |
| insert | 63 | 0.43 [21.25-24.98 / 52.6-54.14] | pass (<1.0) |
| insert | 64 | 0.40 [21.07-22.41 / 52.79-53.52] | pass (<1.0) |
| insert | 65 | 0.65 [34.36-38.08 / 54.83-56.0] | pass (<1.0) |
| insert | 97 | 0.89 [53.78-57.26 / 62.02-62.93] | resize cell, not judged (reported) |
| insert | 128 | 0.86 [45.45-47.64 / 53.22-54.66] | pass (<1.0) |
| insert | 256 | 0.97 [47.83-50.61 / 50.09-51.84] | pass (<1.0) |
| insert | 1024 | 1.00 [49.18-50.76 / 49.48-50.79] | pass |
| insert | 16384 | 0.96 [51.93-55.94 / 52.49-57.11] | pass (<1.0) |
| insert_nth | 4 | 0.48 [14.42-15.18 / 21.96-39.53] | warm-up, not read |
| insert_nth | 16 | 0.63 [14.05-15.18 / 21.57-28.3] | pass (<1.0) |
| insert_nth | 32 | 0.51 [14.31-19.84 / 25.22-65.99] | pass (<1.0) |
| insert_nth | 49 | 0.02 [17.45-35.57 / 888.06-1069.89] | resize/migration cell, not judged |
| insert_nth | 63 | 0.69 [15.89-31.54 / 25.79-30.18] | pass (<1.0) |
| insert_nth | 64 | 0.30 [20.63-48.17 / 88.58-94.69] | pass (<1.0) |
| insert_nth | 65 | 34.80 [1022.3-1057.91 / 28.96-32.91] | migration: see 97th |
| insert_nth | 97 | 0.84 [1552.34-1655.9 / 1848.61-1909.46] | resize/migration cell, not judged |
| insert_nth | 128 | 1.07 [30.43-31.97 / 27.53-30.33] | FAIL: pre-existing shortfall (see conclusion) |
| insert_nth | 256 | 1.11 [31.98-34.4 / 29.12-31.16] | FAIL: pre-existing shortfall (see conclusion) |
| insert_nth | 1024 | 1.09 [35.38-37.88 / 31.63-36.63] | pass (overlap) |
| insert_nth | 16384 | 1.05 [52.75-92.75 / 47.75-112.75] | pass |
| iterate | 4 | 0.83 [14.1-17.49 / 18.99-22.8] | warm-up, not read |
| iterate | 16 | 0.65 [10.93-11.11 / 16.45-18.9] | pass (<1.0) |
| iterate | 32 | 0.57 [10.09-13.1 / 17.22-18.31] | pass (<1.0) |
| iterate | 49 | 0.88 [13.08-39.19 / 16.61-20.25] | resize cell, not judged (reported) |
| iterate | 63 | 0.69 [10.94-11.19 / 14.89-16.65] | pass (<1.0) |
| iterate | 64 | 0.69 [9.8-11.07 / 14.89-16.51] | pass (<1.0) |
| iterate | 65 | 1.03 [14.97-15.32 / 14.68-15.11] | pass |
| iterate | 97 | 1.02 [16.34-16.99 / 15.94-16.43] | resize cell, not judged (reported) |
| iterate | 128 | 1.02 [14.78-15.38 / 14.51-14.79] | pass |
| iterate | 256 | 1.02 [14.76-14.98 / 14.43-14.86] | pass |
| iterate | 1024 | 1.02 [14.59-14.82 / 14.27-14.56] | pass |
| iterate | 16384 | 1.02 [14.48-15.08 / 14.22-14.79] | pass |
| lookup_hit | 4 | 0.85 [10.97-14.61 / 12.47-15.71] | warm-up, not read |
| lookup_hit | 16 | 0.75 [10.34-11.0 / 13.82-14.3] | pass (<1.0) |
| lookup_hit | 32 | 0.77 [9.88-11.86 / 13.87-14.19] | pass (<1.0) |
| lookup_hit | 49 | 2.34 [11.05-49.75 / 16.89-42.47] | resize cell, not judged (reported) |
| lookup_hit | 63 | 0.84 [10.41-12.51 / 13.69-14.05] | pass (<1.0) |
| lookup_hit | 64 | 0.84 [10.55-12.39 / 13.78-14.1] | pass (<1.0) |
| lookup_hit | 65 | 0.97 [13.13-14.22 / 13.83-14.47] | pass (<1.0) |
| lookup_hit | 97 | 0.97 [12.12-13.18 / 12.68-40.86] | resize cell, not judged (reported) |
| lookup_hit | 128 | 0.95 [13.01-13.46 / 13.74-14.16] | pass (<1.0) |
| lookup_hit | 256 | 0.94 [13.04-13.5 / 13.88-14.36] | pass (<1.0) |
| lookup_hit | 1024 | 0.93 [13.3-14.46 / 14.13-14.52] | pass (<1.0) |
| lookup_hit | 16384 | 0.93 [14.55-16.3 / 15.54-16.64] | pass (<1.0) |
| lookup_miss | 4 | 1.01 [10.39-18.37 / 13.47-34.22] | warm-up, not read |
| lookup_miss | 16 | 0.71 [9.71-9.91 / 13.7-30.78] | pass (<1.0) |
| lookup_miss | 32 | 0.78 [9.78-11.88 / 13.67-30.95] | pass (<1.0) |
| lookup_miss | 49 | 3.08 [15.15-49.96 / 12.38-18.36] | resize cell, not judged (reported) |
| lookup_miss | 63 | 0.91 [11.64-13.67 / 13.44-30.54] | pass (<1.0) |
| lookup_miss | 64 | 0.89 [11.55-13.22 / 13.52-30.66] | pass (<1.0) |
| lookup_miss | 65 | 0.96 [13.03-13.63 / 13.65-30.68] | pass (<1.0) |
| lookup_miss | 97 | 0.96 [11.41-11.95 / 11.97-12.21] | resize cell, not judged (reported) |
| lookup_miss | 128 | 0.95 [12.86-13.19 / 13.49-30.8] | pass (<1.0) |
| lookup_miss | 256 | 0.95 [12.93-13.3 / 13.58-30.76] | pass (<1.0) |
| lookup_miss | 1024 | 0.96 [12.86-13.42 / 13.56-31.32] | pass (<1.0) |
| lookup_miss | 16384 | 0.95 [13.89-15.06 / 14.62-33.31] | pass (<1.0) |
## Run 2: zig-lto / c-lto, the six original ops

| op | size | ratio [zig-lto min-max / c-lto min-max] ns | verdict |
|---|---:|---|---|
| delete | 4 | 0.82 [10.86-12.32 / 12.77-13.95] | warm-up, not read |
| delete | 16 | 0.72 [10.05-10.33 / 14.03-14.45] | pass (<1.0) |
| delete | 32 | 0.81 [11.11-12.16 / 13.86-14.24] | pass (<1.0) |
| delete | 49 | 1.13 [12.03-21.77 / 13.25-41.91] | resize cell, not judged (reported) |
| delete | 63 | 0.86 [11.58-12.96 / 13.67-14.21] | pass (<1.0) |
| delete | 64 | 0.87 [11.55-12.57 / 13.79-14.08] | pass (<1.0) |
| delete | 65 | 0.97 [13.24-13.68 / 13.68-14.05] | pass (<1.0) |
| delete | 97 | 0.95 [12.41-12.79 / 13.17-13.45] | resize cell, not judged (reported) |
| delete | 128 | 0.97 [13.22-13.46 / 13.68-15.54] | pass (<1.0) |
| delete | 256 | 0.96 [13.22-13.52 / 13.72-14.77] | pass (<1.0) |
| delete | 1024 | 0.95 [13.43-13.79 / 13.92-14.48] | pass (<1.0) |
| delete | 16384 | 0.96 [14.91-15.25 / 15.47-15.85] | pass (<1.0) |
| insert | 4 | 0.88 [24.1-27.62 / 26.82-30.49] | warm-up, not read |
| insert | 16 | 0.43 [21.29-22.25 / 48.86-51.92] | pass (<1.0) |
| insert | 32 | 0.40 [21.07-22.59 / 52.57-54.1] | pass (<1.0) |
| insert | 49 | 0.31 [19.13-41.47 / 62.79-101.41] | resize cell, not judged (reported) |
| insert | 63 | 0.42 [21.71-25.55 / 52.97-53.71] | pass (<1.0) |
| insert | 64 | 0.42 [20.88-23.08 / 52.81-53.55] | pass (<1.0) |
| insert | 65 | 0.66 [34.99-36.93 / 54.82-55.55] | pass (<1.0) |
| insert | 97 | 0.89 [54.61-56.01 / 62.37-64.54] | resize cell, not judged (reported) |
| insert | 128 | 0.88 [45.21-48.33 / 51.03-56.23] | pass (<1.0) |
| insert | 256 | 0.98 [48.16-51.2 / 51.26-52.06] | pass (<1.0) |
| insert | 1024 | 1.02 [50.02-53.64 / 48.41-51.72] | pass |
| insert | 16384 | 1.00 [52.11-55.38 / 52.69-56.07] | pass |
| insert_nth | 4 | 0.48 [14.8-19.03 / 22.89-37.04] | warm-up, not read |
| insert_nth | 16 | 0.55 [14.09-14.78 / 21.83-28.14] | pass (<1.0) |
| insert_nth | 32 | 0.50 [14.29-19.3 / 27.97-60.9] | pass (<1.0) |
| insert_nth | 49 | 0.03 [16.31-40.58 / 870.93-1031.64] | resize/migration cell, not judged |
| insert_nth | 63 | 0.63 [15.99-25.47 / 25.61-28.96] | pass (<1.0) |
| insert_nth | 64 | 0.28 [22.21-31.47 / 84.8-91.73] | pass (<1.0) |
| insert_nth | 65 | 35.34 [1012.5-1064.4 / 28.92-30.59] | migration: see 97th |
| insert_nth | 97 | 0.83 [1534.3-1583.49 / 1755.35-1900.81] | resize/migration cell, not judged |
| insert_nth | 128 | 1.10 [30.72-32.58 / 27.67-30.13] | FAIL: pre-existing shortfall (see conclusion) |
| insert_nth | 256 | 1.12 [32.52-35.5 / 28.61-31.93] | FAIL: pre-existing shortfall (see conclusion) |
| insert_nth | 1024 | 1.05 [33.34-40.84 / 31.94-37.27] | pass |
| insert_nth | 16384 | 1.14 [47.75-97.75 / 45.0-112.75] | pass (overlap) |
| iterate | 4 | 0.74 [14.18-17.63 / 19.27-19.87] | warm-up, not read |
| iterate | 16 | 0.67 [10.89-13.27 / 16.42-17.75] | pass (<1.0) |
| iterate | 32 | 0.57 [10.11-13.28 / 17.67-18.22] | pass (<1.0) |
| iterate | 49 | 1.78 [10.62-40.14 / 16.52-45.84] | resize cell, not judged (reported) |
| iterate | 63 | 0.71 [9.82-11.26 / 14.86-16.33] | pass (<1.0) |
| iterate | 64 | 0.61 [9.71-11.13 / 14.81-16.39] | pass (<1.0) |
| iterate | 65 | 1.04 [14.97-15.52 / 14.6-14.77] | pass |
| iterate | 97 | 1.01 [16.32-16.9 / 16.09-17.01] | resize cell, not judged (reported) |
| iterate | 128 | 1.02 [14.87-15.34 / 14.46-14.93] | pass |
| iterate | 256 | 1.03 [14.76-15.13 / 14.37-14.55] | pass |
| iterate | 1024 | 1.02 [14.58-15.11 / 14.32-14.51] | pass |
| iterate | 16384 | 1.03 [14.52-14.96 / 14.16-14.37] | pass |
| lookup_hit | 4 | 0.86 [10.81-13.66 / 12.54-14.15] | warm-up, not read |
| lookup_hit | 16 | 0.75 [10.36-10.76 / 13.83-14.15] | pass (<1.0) |
| lookup_hit | 32 | 0.76 [10.07-11.17 / 13.8-15.23] | pass (<1.0) |
| lookup_hit | 49 | 2.61 [14.58-49.36 / 17.39-48.39] | resize cell, not judged (reported) |
| lookup_hit | 63 | 0.85 [11.04-12.73 / 13.67-13.78] | pass (<1.0) |
| lookup_hit | 64 | 0.84 [10.94-12.6 / 13.72-13.97] | pass (<1.0) |
| lookup_hit | 65 | 0.96 [13.13-13.87 / 13.77-14.12] | pass (<1.0) |
| lookup_hit | 97 | 0.95 [11.95-12.58 / 12.69-14.81] | resize cell, not judged (reported) |
| lookup_hit | 128 | 0.95 [12.92-13.36 / 13.71-14.73] | pass (<1.0) |
| lookup_hit | 256 | 0.95 [13.03-13.44 / 13.83-14.3] | pass (<1.0) |
| lookup_hit | 1024 | 0.94 [13.32-13.64 / 14.16-14.89] | pass (<1.0) |
| lookup_hit | 16384 | 0.94 [14.59-14.83 / 15.55-15.87] | pass (<1.0) |
| lookup_miss | 4 | 0.75 [10.35-14.1 / 13.59-35.25] | warm-up, not read |
| lookup_miss | 16 | 0.72 [9.71-10.66 / 13.77-32.2] | pass (<1.0) |
| lookup_miss | 32 | 0.75 [9.64-12.07 / 13.65-31.6] | pass (<1.0) |
| lookup_miss | 49 | 2.73 [13.94-50.89 / 12.29-45.99] | resize cell, not judged (reported) |
| lookup_miss | 63 | 0.90 [11.03-13.28 / 13.39-31.78] | pass (<1.0) |
| lookup_miss | 64 | 0.89 [11.05-12.99 / 13.51-31.88] | pass (<1.0) |
| lookup_miss | 65 | 0.97 [12.91-13.42 / 13.56-31.91] | pass (<1.0) |
| lookup_miss | 97 | 0.95 [11.36-11.78 / 11.97-14.46] | resize cell, not judged (reported) |
| lookup_miss | 128 | 0.95 [12.81-13.15 / 13.49-31.4] | pass (<1.0) |
| lookup_miss | 256 | 0.96 [12.87-13.23 / 13.56-31.59] | pass (<1.0) |
| lookup_miss | 1024 | 0.95 [12.88-13.18 / 13.54-31.56] | pass (<1.0) |
| lookup_miss | 16384 | 0.95 [13.92-14.22 / 14.63-33.88] | pass (<1.0) |
## Ops without a prior baseline (informational, not part of the 53)

overwrite, clone, iterate_delete have no tuning-record baseline. The same rule applied for information: in both runs 20 of 27 cells pass; overwrite at 65-16384 and clone at 65 and 128 are above the rule.

### Run 1

| op | size | ratio [zig-lto min-max / c-lto min-max] ns | verdict |
|---|---:|---|---|
| clone | 4 | 0.58 [10.93-12.64 / 20.17-24.05] | warm-up, not read |
| clone | 16 | 0.41 [4.58-6.95 / 16.62-17.3] | pass (<1.0) |
| clone | 32 | 0.40 [3.51-6.41 / 15.56-16.18] | pass (<1.0) |
| clone | 49 | 0.23 [3.65-4.25 / 15.85-19.08] | resize cell, not judged (reported) |
| clone | 63 | 0.21 [3.23-6.55 / 14.89-15.69] | pass (<1.0) |
| clone | 64 | 0.40 [5.68-6.64 / 14.96-15.33] | pass (<1.0) |
| clone | 65 | 1.13 [11.8-14.3 / 11.13-11.48] | FAIL |
| clone | 97 | 1.00 [17.88-20.04 / 17.01-20.01] | resize cell, not judged (reported) |
| clone | 128 | 1.21 [14.84-15.26 / 11.6-14.2] | FAIL |
| clone | 256 | 1.04 [13.45-14.49 / 13.14-13.83] | pass |
| clone | 1024 | 1.02 [10.56-13.17 / 10.29-11.49] | pass |
| clone | 16384 | 1.04 [10.42-10.81 / 9.91-10.24] | pass |
| iterate_delete | 4 | 0.76 [25.34-28.27 / 33.3-36.97] | warm-up, not read |
| iterate_delete | 16 | 0.59 [20.6-22.91 / 32.06-36.93] | pass (<1.0) |
| iterate_delete | 32 | 0.74 [20.77-23.07 / 29.05-31.74] | pass (<1.0) |
| iterate_delete | 49 | 0.79 [21.18-25.92 / 28.3-38.78] | resize cell, not judged (reported) |
| iterate_delete | 63 | 0.81 [20.27-22.94 / 26.14-28.46] | pass (<1.0) |
| iterate_delete | 64 | 0.81 [20.16-22.9 / 26.24-28.48] | pass (<1.0) |
| iterate_delete | 65 | 1.04 [26.79-27.48 / 25.87-28.45] | pass |
| iterate_delete | 97 | 1.03 [27.11-28.91 / 26.52-27.09] | resize cell, not judged (reported) |
| iterate_delete | 128 | 1.04 [26.48-27.3 / 25.47-27.41] | pass |
| iterate_delete | 256 | 1.04 [26.29-26.86 / 25.32-26.93] | pass |
| iterate_delete | 1024 | 1.02 [26.62-28.01 / 25.99-26.86] | pass |
| iterate_delete | 16384 | 0.99 [31.66-32.73 / 31.77-33.43] | pass (<1.0) |
| overwrite | 4 | 1.03 [16.33-19.1 / 15.99-18.76] | warm-up, not read |
| overwrite | 16 | 0.91 [15.6-16.39 / 17.18-17.52] | pass (<1.0) |
| overwrite | 32 | 0.93 [15.56-18.12 / 17.24-17.49] | pass (<1.0) |
| overwrite | 49 | 1.11 [20.19-52.04 / 16.24-27.9] | resize cell, not judged (reported) |
| overwrite | 63 | 1.04 [16.58-18.99 / 17.08-17.55] | pass |
| overwrite | 64 | 1.03 [16.63-19.32 / 17.2-17.59] | pass |
| overwrite | 65 | 1.20 [20.57-21.03 / 17.21-17.82] | FAIL |
| overwrite | 97 | 1.21 [19.36-19.99 / 16.19-16.41] | resize cell, not judged (reported) |
| overwrite | 128 | 1.20 [20.33-21.45 / 17.14-17.48] | FAIL |
| overwrite | 256 | 1.19 [20.44-21.13 / 17.26-17.61] | FAIL |
| overwrite | 1024 | 1.18 [20.78-21.32 / 17.64-17.89] | FAIL |
| overwrite | 16384 | 1.15 [22.31-23.01 / 19.15-20.63] | FAIL |

### Run 2

| op | size | ratio [zig-lto min-max / c-lto min-max] ns | verdict |
|---|---:|---|---|
| clone | 4 | 0.60 [11.76-16.16 / 19.28-21.59] | warm-up, not read |
| clone | 16 | 0.41 [4.42-6.99 / 16.53-17.16] | pass (<1.0) |
| clone | 32 | 0.39 [3.55-6.56 / 15.73-16.28] | pass (<1.0) |
| clone | 49 | 0.21 [3.7-4.18 / 13.87-20.39] | resize cell, not judged (reported) |
| clone | 63 | 0.40 [3.19-6.43 / 15.17-15.48] | pass (<1.0) |
| clone | 64 | 0.41 [5.95-6.41 / 14.77-15.54] | pass (<1.0) |
| clone | 65 | 1.13 [12.09-13.14 / 11.07-11.25] | FAIL |
| clone | 97 | 0.97 [17.37-20.29 / 16.76-20.13] | resize cell, not judged (reported) |
| clone | 128 | 1.15 [14.03-15.22 / 11.77-13.77] | FAIL |
| clone | 256 | 1.04 [12.03-14.41 / 12.56-13.89] | pass |
| clone | 1024 | 1.03 [10.65-11.08 / 10.15-12.99] | pass |
| clone | 16384 | 1.03 [10.42-10.69 / 9.98-10.26] | pass |
| iterate_delete | 4 | 0.77 [25.37-26.37 / 33.21-35.52] | warm-up, not read |
| iterate_delete | 16 | 0.61 [20.67-22.17 / 29.33-35.01] | pass (<1.0) |
| iterate_delete | 32 | 0.73 [21.31-22.99 / 28.97-30.46] | pass (<1.0) |
| iterate_delete | 49 | 0.76 [20.73-24.2 / 28.42-34.59] | resize cell, not judged (reported) |
| iterate_delete | 63 | 0.82 [20.49-23.04 / 26.16-26.55] | pass (<1.0) |
| iterate_delete | 64 | 0.84 [20.81-22.76 / 25.98-26.68] | pass (<1.0) |
| iterate_delete | 65 | 1.04 [26.82-27.5 / 25.87-26.28] | pass |
| iterate_delete | 97 | 1.03 [27.45-28.32 / 26.55-27.22] | resize cell, not judged (reported) |
| iterate_delete | 128 | 1.04 [26.44-27.07 / 25.48-26.03] | pass |
| iterate_delete | 256 | 1.04 [26.24-26.96 / 25.26-25.66] | pass |
| iterate_delete | 1024 | 1.03 [26.65-27.18 / 25.95-26.45] | pass |
| iterate_delete | 16384 | 0.99 [31.67-32.34 / 31.72-32.35] | pass (<1.0) |
| overwrite | 4 | 1.03 [16.41-17.45 / 16.1-16.53] | warm-up, not read |
| overwrite | 16 | 0.91 [15.53-17.92 / 17.15-17.68] | pass (<1.0) |
| overwrite | 32 | 0.96 [15.8-16.97 / 17.18-17.53] | pass (<1.0) |
| overwrite | 49 | 1.23 [17.25-51.89 / 16.38-50.66] | resize cell, not judged (reported) |
| overwrite | 63 | 1.08 [17.02-19.11 / 17.05-17.41] | pass (overlap) |
| overwrite | 64 | 1.08 [16.86-18.96 / 17.12-17.53] | pass (overlap) |
| overwrite | 65 | 1.18 [20.38-20.89 / 17.15-17.57] | FAIL |
| overwrite | 97 | 1.20 [19.36-19.9 / 16.14-16.61] | resize cell, not judged (reported) |
| overwrite | 128 | 1.19 [20.31-20.96 / 17.11-18.07] | FAIL |
| overwrite | 256 | 1.19 [20.37-20.93 / 17.18-17.62] | FAIL |
| overwrite | 1024 | 1.17 [20.74-21.29 / 17.66-17.95] | FAIL |
| overwrite | 16384 | 1.16 [22.36-22.63 / 19.24-19.52] | FAIL |

## Open leads for the next tuning round

- overwrite 65-16384 at 1.15-1.20 against C (zig about 20.4-22.4 ns vs c 17.1-19.2): the lvalue fetch of a present key. Pre-existing: set 0 is unchanged against the campaign's start (the 8b A/B, scoreboard "Default ladder A/B after the fix", overwrite 1.01-1.03 versus 4e37cbbbc).
- clone 65/128 at 1.13-1.21 against C. Pre-existing per the same A/B.

## Attribution check 1: baseline CPU pair (negative)

The coordinator's first hypothesis was that the x86-64-v3 CPU default (commit 2d43de657) tightened the C side and exposed the cells. Both engines were rebuilt with `-Dcpu=baseline` (zig-base, c-base), 9 interleaved rounds, twice, sizes 64,65,128,256, load 1.6-1.85. insert_nth, ratio [zig-base / c-base]:

| size | run A | run B |
|---:|---|---|
| 128 | 1.10 [31.82-35.65 / 27.83-32.48] | 1.10 [31.17-37.94 / 28.41-31.76] |
| 256 | 1.12 [32.41-34.64 / 28.57-31.27] | 1.11 [32.41-34.91 / 28.96-31.66] |

Stated plainly: at the baseline CPU level the 256 cell fails with disjoint spreads at the same 1.11-1.12 ratio and the 128 cell passes only by a hair of overlap. The CPU default is not the cause.

## Attribution check 2: branch base 09bf93ed7 against HEAD (the deciding A/B)

zig-lto built from the branch base 09bf93ed7 (git worktree, `-Dcpu=x86_64_v3` to match HEAD's default CPU) and the HEAD zig-lto prefix, 9 interleaved rounds (order rotated, `bakeoff-final-nqp-ab-load.log`, load 0.8-1.0), sizes 64,65,128,256, `--runs=5 --nth=all`, no strategy. Both ran the same harness copy with the `nqp::hashstrategy(nqp::hash(), ...)` call replaced by `nqp::hash()` (the base moar has no such op; strategy 0 is the plain hash) under nqp's original stage0. `hash-compare.pl`, HEAD over base:

### insert

| size | il-head / base |
|---:|---:|
| 64 | 0.99 [19.14-44.09 / 18.94-51.23] |
| 65 | 1.03 [36.25-39.99 / 36.32-40.30] |
| 128 | 1.02 [46.47-49.79 / 46.50-49.05] |
| 256 | 1.01 [50.13-52.43 / 49.70-50.96] |

### insert_nth

| size | il-head / base |
|---:|---:|
| 64 | 1.01 [21.98-50.25 / 17.08-38.98] |
| 65 | 1.03 [1003.36-1173.09 / 994.64-1080.57] |
| 128 | 1.00 [31.15-32.76 / 30.72-31.94] |
| 256 | 0.98 [31.82-34.09 / 31.46-37.42] |

### lookup_hit

| size | il-head / base |
|---:|---:|
| 64 | 2.47 [12.26-48.46 / 11.74-48.09] |
| 65 | 1.00 [13.08-13.90 / 13.27-13.99] |
| 128 | 0.97 [13.19-14.11 / 13.25-14.60] |
| 256 | 1.00 [13.09-13.41 / 13.16-13.49] |

### overwrite

| size | il-head / base |
|---:|---:|
| 64 | 1.16 [21.53-51.89 / 19.48-50.92] |
| 65 | 1.00 [20.62-22.48 / 20.63-39.56] |
| 128 | 1.01 [20.45-22.38 / 20.42-39.47] |
| 256 | 1.00 [20.43-22.26 / 20.41-39.67] |

### iterate

| size | il-head / base |
|---:|---:|
| 64 | 1.20 [12.32-37.94 / 10.10-35.51] |
| 65 | 1.01 [15.12-15.38 / 14.83-15.69] |
| 128 | 1.00 [14.84-15.10 / 14.76-15.46] |
| 256 | 1.00 [14.65-14.92 / 14.57-15.18] |

### lookup_miss

| size | il-head / base |
|---:|---:|
| 64 | 2.68 [14.34-50.54 / 12.45-48.99] |
| 65 | 0.99 [13.00-13.39 / 13.09-13.66] |
| 128 | 0.99 [12.86-13.16 / 12.90-13.73] |
| 256 | 1.00 [12.87-13.13 / 12.92-13.42] |

### delete

| size | il-head / base |
|---:|---:|
| 64 | 1.08 [11.86-20.70 / 12.16-40.19] |
| 65 | 1.01 [13.39-14.06 / 13.08-14.11] |
| 128 | 1.01 [13.22-14.20 / 13.08-13.67] |
| 256 | 1.01 [13.18-13.87 / 13.07-13.26] |

### iterate_delete

| size | il-head / base |
|---:|---:|
| 64 | 1.02 [21.82-26.05 / 20.62-49.46] |
| 65 | 1.01 [27.07-27.59 / 26.62-27.15] |
| 128 | 1.02 [26.42-26.87 / 25.89-26.84] |
| 256 | 1.02 [26.36-26.92 / 25.85-32.29] |

### clone

| size | il-head / base |
|---:|---:|
| 64 | 0.96 [3.35-4.31 / 3.53-6.08] |
| 65 | 1.02 [15.12-15.67 / 14.53-15.37] |
| 128 | 0.99 [14.68-15.18 / 14.59-16.24] |
| 256 | 1.02 [12.37-14.39 / 11.45-14.29] |


## Conclusion

51/53 cells pass under v3. insert_nth 128 and 256 are the tuning campaign's pre-existing shortfall (`tuning-lto-default-nqp.md` listed insert_nth 128 as FAIL in two of its three tables, lines 136 and 205, and 256 at 1.05-1.06; the tuning plan's Task 8 recorded 1.13 at 128 and 1.11 at 256). They are unchanged by this branch: the base-vs-HEAD A/B has insert_nth 128 at 1.00 [31.15-32.76 / 30.72-31.94] and 256 at 0.98 [31.82-34.09 / 31.46-37.42], and the Zig timings equal the tuning record's (31-33 ns then and now). They now read as disjoint only because the C side's spreads are tighter on this quiet machine than in the post-LTO record, which passed them on that run's wider C spreads; the CPU default is not the cause (check 1). The branch does not touch the C engine's hash code. Criterion 6 is met as no-regression, with two pre-existing shortfall cells annotated.
