# nqp-level ladder with LTO on by default (post-campaign, HEAD 4452f6f87, 2026-11-02)

Builds into four scratch prefixes, `zig build install --prefix <p>` from the same tree: zig-lto (`-Dzig-impl=true`, the default build, 58 s, text 10,208,239), c-lto (`-Dzig-impl=false`, the default C build, 54 s, text 9,946,279), zig (`-Dzig-impl=true -Dlto=false`, 19 s, text 9,498,532), c (`-Dzig-impl=false -Dlto=false`, 16 s, text 9,311,092). `check-lto-binding.sh` (dynamic / plt / defs / call sites of fetch_nocheck): zig-lto 22/0/1/5, c-lto 6/25/0/0, zig 22/119/1/3, c 6/27/0/0. Each prefix's own `bin/moar` with nqp's stage0, `hash-bench.nqp --engine=<v> --sizes=4,16,32,63,64,65,128,256,1024,16384 --runs=5 --nth=all` and `--sizes=49,97`, 9 rounds, the variant order rotated per round (`tuning-lto-default-load.log`). 1-min load 2.7-3.0 at the round starts, inherited from the four parallel builds that ended seconds before (the only CPU users during the rounds were idle editors; each run takes about a second). Cells: median of the 9 round medians, ratio [compared min-max / base min-max of the round medians] ns. Raw: `tuning-lto-default-nqp-<v>.tsv` (variant, round, then the harness's columns), aggregated `tuning-lto-default-il-nqp-<v>.tsv`. Verdict rule as Task 8's.

rounds per cell: [9]

## zig-lto / c-lto

| op | size | ratio [other min-max / base min-max] ns | verdict |
|---|---:|---|---|
| insert | 4 | 1.68 [28.87-60.47 / 29.93-60.70] | warm-up, not read |
| insert | 16 | 0.44 [21.70-23.82 / 48.76-52.09] | pass (<1.0) |
| insert | 32 | 0.41 [21.45-23.01 / 51.97-53.48] | pass (<1.0) |
| insert | 63 | 0.43 [21.30-23.27 / 52.62-53.82] | pass (<1.0) |
| insert | 64 | 0.36 [19.17-20.86 / 55.32-56.41] | pass (<1.0) |
| insert | 65 | 0.75 [37.82-40.59 / 52.00-52.83] | pass |
| insert | 128 | 0.92 [47.44-48.85 / 52.29-53.51] | pass |
| insert | 256 | 0.97 [48.32-51.80 / 50.94-52.23] | pass |
| insert | 1024 | 1.03 [50.56-51.24 / 48.11-51.24] | pass |
| insert | 16384 | 0.97 [52.41-55.74 / 51.91-58.63] | pass |
| lookup_hit | 4 | 1.13 [10.81-46.59 / 12.40-45.28] | warm-up, not read |
| lookup_hit | 16 | 0.75 [10.41-11.67 / 13.70-14.06] | pass |
| lookup_hit | 32 | 0.79 [10.26-11.51 / 13.80-14.20] | pass |
| lookup_hit | 63 | 0.92 [11.13-13.10 / 13.65-14.01] | pass |
| lookup_hit | 64 | 0.92 [11.60-13.03 / 13.67-14.05] | pass |
| lookup_hit | 65 | 1.03 [13.42-14.46 / 13.78-14.20] | pass |
| lookup_hit | 128 | 0.96 [13.08-13.55 / 13.67-13.90] | pass |
| lookup_hit | 256 | 0.95 [13.12-13.45 / 13.74-14.17] | pass |
| lookup_hit | 1024 | 0.96 [13.40-13.81 / 14.03-14.32] | pass |
| lookup_hit | 16384 | 0.95 [14.51-14.87 / 15.37-15.66] | pass |
| lookup_miss | 4 | 0.77 [10.36-45.79 / 13.26-45.99] | warm-up, not read |
| lookup_miss | 16 | 0.74 [9.84-10.52 / 13.58-13.76] | pass |
| lookup_miss | 32 | 0.76 [10.08-11.63 / 13.50-13.83] | pass |
| lookup_miss | 63 | 0.93 [11.38-13.41 / 13.22-13.52] | pass |
| lookup_miss | 64 | 0.90 [11.67-13.12 / 13.18-13.59] | pass |
| lookup_miss | 65 | 0.98 [12.92-13.27 / 13.31-13.68] | pass |
| lookup_miss | 128 | 0.97 [12.78-13.03 / 13.24-13.53] | pass |
| lookup_miss | 256 | 0.96 [12.83-13.11 / 13.33-13.65] | pass |
| lookup_miss | 1024 | 0.96 [12.81-13.16 / 13.33-13.54] | pass |
| lookup_miss | 16384 | 0.97 [13.89-14.17 / 14.32-14.54] | pass |
| delete | 4 | 1.06 [11.21-42.86 / 12.86-42.33] | warm-up, not read |
| delete | 16 | 0.74 [10.45-19.38 / 14.00-14.49] | pass |
| delete | 32 | 0.83 [11.36-19.70 / 13.89-14.53] | pass |
| delete | 63 | 0.92 [11.80-20.20 / 13.74-16.03] | pass |
| delete | 64 | 0.95 [12.52-20.52 / 13.64-15.99] | pass |
| delete | 65 | 0.97 [13.29-13.74 / 13.60-16.01] | pass |
| delete | 128 | 0.96 [13.02-13.91 / 13.73-14.06] | pass |
| delete | 256 | 0.95 [13.14-13.80 / 13.76-14.09] | pass |
| delete | 1024 | 0.95 [13.38-14.04 / 14.01-14.43] | pass |
| delete | 16384 | 0.95 [14.86-15.47 / 15.57-15.89] | pass |
| iterate | 4 | 0.87 [14.01-47.05 / 19.17-53.77] | warm-up, not read |
| iterate | 16 | 0.64 [10.69-10.90 / 16.50-17.53] | pass (<1.0) |
| iterate | 32 | 0.56 [9.85-13.10 / 16.98-18.21] | pass (<1.0) |
| iterate | 63 | 0.63 [9.43-11.03 / 14.67-15.24] | pass (<1.0) |
| iterate | 64 | 0.65 [9.43-9.70 / 14.50-15.09] | pass (<1.0) |
| iterate | 65 | 1.02 [15.19-16.36 / 15.14-16.14] | pass (<=1.10) |
| iterate | 128 | 1.04 [14.71-15.05 / 14.23-14.70] | pass (<=1.10) |
| iterate | 256 | 1.03 [14.59-14.87 / 14.12-14.46] | pass (<=1.10) |
| iterate | 1024 | 1.02 [14.43-14.72 / 14.00-14.56] | pass (<=1.10) |
| iterate | 16384 | 1.03 [14.35-14.56 / 13.93-14.41] | pass (<=1.10) |
| insert_nth | 4 | 0.46 [15.53-16.20 / 24.99-37.94] | warm-up, not read |
| insert_nth | 16 | 0.59 [15.41-18.88 / 22.13-29.49] | pass |
| insert_nth | 32 | 0.53 [15.30-20.14 / 24.38-37.09] | pass |
| insert_nth | 63 | 0.24 [21.39-27.77 / 89.05-101.40] | pass |
| insert_nth | 64 | 0.62 [17.47-19.87 / 29.11-37.93] | pass |
| insert_nth | 65 | 34.23 [1033.26-1097.25 / 29.60-37.01] | migration: see 97th |
| insert_nth | 128 | 1.11 [31.05-33.44 / 28.14-34.87] | pass (overlap) |
| insert_nth | 256 | 1.06 [31.74-33.27 / 29.31-35.22] | pass (overlap) |
| insert_nth | 1024 | 1.07 [34.28-38.03 / 31.63-37.58] | pass (overlap) |
| insert_nth | 16384 | 1.16 [50.00-65.25 / 40.25-52.75] | pass (overlap) |

migration: zig-lto 65th 1046 ns [1033-1097] vs c-lto 97th 1923 ns [1640-1956] = 0.54; zig-lto 97th 1976 ns

cells judged: 53, FAIL: 0 []

## zig-lto / c

| op | size | ratio [other min-max / base min-max] ns | verdict |
|---|---:|---|---|
| insert | 4 | 1.60 [28.87-60.47 / 34.52-37.74] | warm-up, not read |
| insert | 16 | 0.43 [21.70-23.82 / 50.04-53.56] | pass (<1.0) |
| insert | 32 | 0.40 [21.45-23.01 / 53.60-55.09] | pass (<1.0) |
| insert | 63 | 0.42 [21.30-23.27 / 53.85-55.28] | pass (<1.0) |
| insert | 64 | 0.36 [19.17-20.86 / 56.32-58.14] | pass (<1.0) |
| insert | 65 | 0.73 [37.82-40.59 / 53.60-55.52] | pass |
| insert | 128 | 0.91 [47.44-48.85 / 52.73-54.40] | pass |
| insert | 256 | 0.95 [48.32-51.80 / 50.33-53.40] | pass |
| insert | 1024 | 1.03 [50.56-51.24 / 48.74-49.68] | pass |
| insert | 16384 | 0.92 [52.41-55.74 / 53.33-58.68] | pass |
| lookup_hit | 4 | 1.02 [10.81-46.59 / 13.54-17.71] | warm-up, not read |
| lookup_hit | 16 | 0.71 [10.41-11.67 / 14.68-14.96] | pass |
| lookup_hit | 32 | 0.75 [10.26-11.51 / 14.51-14.87] | pass |
| lookup_hit | 63 | 0.87 [11.13-13.10 / 14.30-16.02] | pass |
| lookup_hit | 64 | 0.86 [11.60-13.03 / 14.30-16.05] | pass |
| lookup_hit | 65 | 0.97 [13.42-14.46 / 14.56-16.09] | pass |
| lookup_hit | 128 | 0.91 [13.08-13.55 / 14.39-15.17] | pass |
| lookup_hit | 256 | 0.90 [13.12-13.45 / 14.53-15.13] | pass |
| lookup_hit | 1024 | 0.91 [13.40-13.81 / 14.73-15.18] | pass |
| lookup_hit | 16384 | 0.90 [14.51-14.87 / 16.15-16.57] | pass |
| lookup_miss | 4 | 0.56 [10.36-45.79 / 14.62-20.30] | warm-up, not read |
| lookup_miss | 16 | 0.69 [9.84-10.52 / 14.58-14.72] | pass |
| lookup_miss | 32 | 0.72 [10.08-11.63 / 14.42-14.60] | pass |
| lookup_miss | 63 | 0.87 [11.38-13.41 / 14.07-14.71] | pass |
| lookup_miss | 64 | 0.85 [11.67-13.12 / 14.13-14.86] | pass |
| lookup_miss | 65 | 0.91 [12.92-13.27 / 14.20-14.90] | pass |
| lookup_miss | 128 | 0.91 [12.78-13.03 / 14.10-14.37] | pass |
| lookup_miss | 256 | 0.91 [12.83-13.11 / 14.13-14.40] | pass |
| lookup_miss | 1024 | 0.91 [12.81-13.16 / 14.10-14.43] | pass |
| lookup_miss | 16384 | 0.92 [13.89-14.17 / 15.17-15.67] | pass |
| delete | 4 | 0.98 [11.21-42.86 / 13.80-14.26] | warm-up, not read |
| delete | 16 | 0.70 [10.45-19.38 / 14.81-15.13] | pass |
| delete | 32 | 0.80 [11.36-19.70 / 14.64-14.97] | pass |
| delete | 63 | 0.88 [11.80-20.20 / 14.29-17.88] | pass |
| delete | 64 | 0.91 [12.52-20.52 / 14.26-17.83] | pass |
| delete | 65 | 0.93 [13.29-13.74 / 14.48-18.01] | pass |
| delete | 128 | 0.93 [13.02-13.91 / 14.30-16.06] | pass |
| delete | 256 | 0.91 [13.14-13.80 / 14.32-15.52] | pass |
| delete | 1024 | 0.91 [13.38-14.04 / 14.67-15.04] | pass |
| delete | 16384 | 0.91 [14.86-15.47 / 16.16-16.62] | pass |
| iterate | 4 | 0.72 [14.01-47.05 / 20.68-24.38] | warm-up, not read |
| iterate | 16 | 0.59 [10.69-10.90 / 16.94-19.16] | pass (<1.0) |
| iterate | 32 | 0.55 [9.85-13.10 / 17.36-18.83] | pass (<1.0) |
| iterate | 63 | 0.59 [9.43-11.03 / 15.35-17.12] | pass (<1.0) |
| iterate | 64 | 0.61 [9.43-9.70 / 15.27-15.67] | pass (<1.0) |
| iterate | 65 | 0.95 [15.19-16.36 / 15.66-17.10] | pass (<=1.10) |
| iterate | 128 | 0.98 [14.71-15.05 / 15.01-15.46] | pass (<=1.10) |
| iterate | 256 | 0.97 [14.59-14.87 / 14.95-15.28] | pass (<=1.10) |
| iterate | 1024 | 0.96 [14.43-14.72 / 14.65-15.24] | pass (<=1.10) |
| iterate | 16384 | 0.96 [14.35-14.56 / 14.77-15.10] | pass (<=1.10) |
| insert_nth | 4 | 0.48 [15.53-16.20 / 26.55-39.92] | warm-up, not read |
| insert_nth | 16 | 0.69 [15.41-18.88 / 22.23-30.86] | pass |
| insert_nth | 32 | 0.53 [15.30-20.14 / 25.27-36.73] | pass |
| insert_nth | 63 | 0.24 [21.39-27.77 / 28.98-95.94] | pass |
| insert_nth | 64 | 0.62 [17.47-19.87 / 29.11-31.30] | pass |
| insert_nth | 65 | 33.04 [1033.26-1097.25 / 30.27-33.51] | migration: see 97th |
| insert_nth | 128 | 1.07 [31.05-33.44 / 28.67-30.25] | FAIL |
| insert_nth | 256 | 1.05 [31.74-33.27 / 29.82-32.05] | pass |
| insert_nth | 1024 | 1.01 [34.28-38.03 / 32.41-36.64] | pass |
| insert_nth | 16384 | 1.00 [50.00-65.25 / 47.75-112.75] | pass |

migration: zig-lto 65th 1046 ns [1033-1097] vs c 97th 1839 ns [1681-1979] = 0.57; zig-lto 97th 1976 ns

cells judged: 53, FAIL: 1 ['insert_nth@128 1.07']

## zig / c

| op | size | ratio [other min-max / base min-max] ns | verdict |
|---|---:|---|---|
| insert | 4 | 1.70 [30.18-65.01 / 34.52-37.74] | warm-up, not read |
| insert | 16 | 0.46 [23.15-25.10 / 50.04-53.56] | pass (<1.0) |
| insert | 32 | 0.45 [23.57-24.50 / 53.60-55.09] | pass (<1.0) |
| insert | 63 | 0.45 [24.22-25.31 / 53.85-55.28] | pass (<1.0) |
| insert | 64 | 0.39 [21.81-22.62 / 56.32-58.14] | pass (<1.0) |
| insert | 65 | 0.77 [40.40-42.37 / 53.60-55.52] | pass |
| insert | 128 | 0.93 [49.52-50.51 / 52.73-54.40] | pass |
| insert | 256 | 0.98 [49.85-52.93 / 50.33-53.40] | pass |
| insert | 1024 | 1.05 [51.08-52.10 / 48.74-49.68] | FAIL |
| insert | 16384 | 0.94 [53.16-56.30 / 53.33-58.68] | pass |
| lookup_hit | 4 | 0.82 [12.46-52.87 / 13.54-17.71] | warm-up, not read |
| lookup_hit | 16 | 0.84 [12.06-13.49 / 14.68-14.96] | pass |
| lookup_hit | 32 | 0.95 [13.45-14.38 / 14.51-14.87] | pass |
| lookup_hit | 63 | 1.07 [14.77-16.09 / 14.30-16.02] | pass (overlap) |
| lookup_hit | 64 | 1.03 [15.05-15.71 / 14.30-16.05] | pass |
| lookup_hit | 65 | 1.08 [14.65-16.09 / 14.56-16.09] | pass (overlap) |
| lookup_hit | 128 | 1.00 [14.40-14.65 / 14.39-15.17] | pass |
| lookup_hit | 256 | 0.99 [14.50-14.89 / 14.53-15.13] | pass |
| lookup_hit | 1024 | 1.00 [14.69-14.98 / 14.73-15.18] | pass |
| lookup_hit | 16384 | 0.99 [15.94-16.38 / 16.15-16.57] | pass |
| lookup_miss | 4 | 0.94 [11.83-50.95 / 14.62-20.30] | warm-up, not read |
| lookup_miss | 16 | 0.78 [11.02-11.92 / 14.58-14.72] | pass |
| lookup_miss | 32 | 0.95 [13.22-14.58 / 14.42-14.60] | pass |
| lookup_miss | 63 | 1.10 [14.91-16.32 / 14.07-14.71] | FAIL |
| lookup_miss | 64 | 1.13 [15.03-16.90 / 14.13-14.86] | FAIL |
| lookup_miss | 65 | 1.03 [14.61-14.93 / 14.20-14.90] | pass |
| lookup_miss | 128 | 1.02 [14.47-14.63 / 14.10-14.37] | pass |
| lookup_miss | 256 | 1.02 [14.45-14.63 / 14.13-14.40] | pass |
| lookup_miss | 1024 | 1.03 [14.49-14.73 / 14.10-14.43] | pass |
| lookup_miss | 16384 | 1.02 [15.50-15.63 / 15.17-15.67] | pass |
| delete | 4 | 0.87 [12.00-45.86 / 13.80-14.26] | warm-up, not read |
| delete | 16 | 0.75 [11.05-11.84 / 14.81-15.13] | pass |
| delete | 32 | 0.91 [13.08-13.85 / 14.64-14.97] | pass |
| delete | 63 | 0.99 [14.13-14.95 / 14.29-17.88] | pass |
| delete | 64 | 1.05 [14.45-15.69 / 14.26-17.83] | pass (overlap) |
| delete | 65 | 0.99 [14.11-14.65 / 14.48-18.01] | pass |
| delete | 128 | 0.99 [14.04-14.26 / 14.30-16.06] | pass |
| delete | 256 | 0.98 [14.14-14.47 / 14.32-15.52] | pass |
| delete | 1024 | 0.98 [14.26-14.70 / 14.67-15.04] | pass |
| delete | 16384 | 0.97 [15.67-16.01 / 16.16-16.62] | pass |
| iterate | 4 | 0.90 [16.06-50.22 / 20.68-24.38] | warm-up, not read |
| iterate | 16 | 0.70 [11.84-13.35 / 16.94-19.16] | pass (<1.0) |
| iterate | 32 | 0.64 [10.88-13.37 / 17.36-18.83] | pass (<1.0) |
| iterate | 63 | 0.70 [10.46-12.42 / 15.35-17.12] | pass (<1.0) |
| iterate | 64 | 0.72 [10.45-12.14 / 15.27-15.67] | pass (<1.0) |
| iterate | 65 | 1.03 [16.54-17.66 / 15.66-17.10] | pass (<=1.10) |
| iterate | 128 | 1.06 [15.69-16.72 / 15.01-15.46] | pass (<=1.10) |
| iterate | 256 | 1.05 [15.43-16.46 / 14.95-15.28] | pass (<=1.10) |
| iterate | 1024 | 1.07 [15.65-16.26 / 14.65-15.24] | pass (<=1.10) |
| iterate | 16384 | 1.05 [15.64-16.38 / 14.77-15.10] | pass (<=1.10) |
| insert_nth | 4 | 0.48 [15.58-17.00 / 26.55-39.92] | warm-up, not read |
| insert_nth | 16 | 0.69 [15.25-21.35 / 22.23-30.86] | pass |
| insert_nth | 32 | 0.60 [17.35-23.22 / 25.27-36.73] | pass |
| insert_nth | 63 | 0.26 [18.25-30.13 / 28.98-95.94] | pass |
| insert_nth | 64 | 0.70 [19.56-29.85 / 29.11-31.30] | pass |
| insert_nth | 65 | 33.60 [1009.84-1082.78 / 30.27-33.51] | migration: see 97th |
| insert_nth | 128 | 1.10 [31.70-32.94 / 28.67-30.25] | FAIL |
| insert_nth | 256 | 1.09 [32.76-35.34 / 29.82-32.05] | FAIL |
| insert_nth | 1024 | 1.08 [35.84-38.36 / 32.41-36.64] | pass (overlap) |
| insert_nth | 16384 | 1.00 [52.50-67.75 / 47.75-112.75] | pass |

migration: zig 65th 1063 ns [1010-1083] vs c 97th 1839 ns [1681-1979] = 0.58; zig 97th 1969 ns

cells judged: 53, FAIL: 5 ['insert@1024 1.05', 'lookup_miss@63 1.10', 'lookup_miss@64 1.13', 'insert_nth@128 1.10', 'insert_nth@256 1.09']

## c-lto / c

| op | size | ratio [other min-max / base min-max] ns | verdict |
|---|---:|---|---|
| insert | 4 | 0.95 [29.93-60.70 / 34.52-37.74] | warm-up, not read |
| insert | 16 | 0.99 [48.76-52.09 / 50.04-53.56] | pass (<1.0) |
| insert | 32 | 0.98 [51.97-53.48 / 53.60-55.09] | pass (<1.0) |
| insert | 63 | 0.98 [52.62-53.82 / 53.85-55.28] | pass (<1.0) |
| insert | 64 | 0.99 [55.32-56.41 / 56.32-58.14] | pass (<1.0) |
| insert | 65 | 0.98 [52.00-52.83 / 53.60-55.52] | pass |
| insert | 128 | 0.98 [52.29-53.51 / 52.73-54.40] | pass |
| insert | 256 | 0.98 [50.94-52.23 / 50.33-53.40] | pass |
| insert | 1024 | 1.00 [48.11-51.24 / 48.74-49.68] | pass |
| insert | 16384 | 0.95 [51.91-58.63 / 53.33-58.68] | pass |
| lookup_hit | 4 | 0.90 [12.40-45.28 / 13.54-17.71] | warm-up, not read |
| lookup_hit | 16 | 0.94 [13.70-14.06 / 14.68-14.96] | pass |
| lookup_hit | 32 | 0.95 [13.80-14.20 / 14.51-14.87] | pass |
| lookup_hit | 63 | 0.95 [13.65-14.01 / 14.30-16.02] | pass |
| lookup_hit | 64 | 0.94 [13.67-14.05 / 14.30-16.05] | pass |
| lookup_hit | 65 | 0.95 [13.78-14.20 / 14.56-16.09] | pass |
| lookup_hit | 128 | 0.95 [13.67-13.90 / 14.39-15.17] | pass |
| lookup_hit | 256 | 0.95 [13.74-14.17 / 14.53-15.13] | pass |
| lookup_hit | 1024 | 0.95 [14.03-14.32 / 14.73-15.18] | pass |
| lookup_hit | 16384 | 0.95 [15.37-15.66 / 16.15-16.57] | pass |
| lookup_miss | 4 | 0.72 [13.26-45.99 / 14.62-20.30] | warm-up, not read |
| lookup_miss | 16 | 0.93 [13.58-13.76 / 14.58-14.72] | pass |
| lookup_miss | 32 | 0.94 [13.50-13.83 / 14.42-14.60] | pass |
| lookup_miss | 63 | 0.94 [13.22-13.52 / 14.07-14.71] | pass |
| lookup_miss | 64 | 0.94 [13.18-13.59 / 14.13-14.86] | pass |
| lookup_miss | 65 | 0.93 [13.31-13.68 / 14.20-14.90] | pass |
| lookup_miss | 128 | 0.94 [13.24-13.53 / 14.10-14.37] | pass |
| lookup_miss | 256 | 0.94 [13.33-13.65 / 14.13-14.40] | pass |
| lookup_miss | 1024 | 0.94 [13.33-13.54 / 14.10-14.43] | pass |
| lookup_miss | 16384 | 0.95 [14.32-14.54 / 15.17-15.67] | pass |
| delete | 4 | 0.92 [12.86-42.33 / 13.80-14.26] | warm-up, not read |
| delete | 16 | 0.95 [14.00-14.49 / 14.81-15.13] | pass |
| delete | 32 | 0.96 [13.89-14.53 / 14.64-14.97] | pass |
| delete | 63 | 0.96 [13.74-16.03 / 14.29-17.88] | pass |
| delete | 64 | 0.96 [13.64-15.99 / 14.26-17.83] | pass |
| delete | 65 | 0.96 [13.60-16.01 / 14.48-18.01] | pass |
| delete | 128 | 0.97 [13.73-14.06 / 14.30-16.06] | pass |
| delete | 256 | 0.95 [13.76-14.09 / 14.32-15.52] | pass |
| delete | 1024 | 0.96 [14.01-14.43 / 14.67-15.04] | pass |
| delete | 16384 | 0.96 [15.57-15.89 / 16.16-16.62] | pass |
| iterate | 4 | 0.83 [19.17-53.77 / 20.68-24.38] | warm-up, not read |
| iterate | 16 | 0.92 [16.50-17.53 / 16.94-19.16] | pass (<1.0) |
| iterate | 32 | 0.97 [16.98-18.21 / 17.36-18.83] | pass (<1.0) |
| iterate | 63 | 0.93 [14.67-15.24 / 15.35-17.12] | pass (<1.0) |
| iterate | 64 | 0.94 [14.50-15.09 / 15.27-15.67] | pass (<1.0) |
| iterate | 65 | 0.93 [15.14-16.14 / 15.66-17.10] | pass (<=1.10) |
| iterate | 128 | 0.94 [14.23-14.70 / 15.01-15.46] | pass (<=1.10) |
| iterate | 256 | 0.94 [14.12-14.46 / 14.95-15.28] | pass (<=1.10) |
| iterate | 1024 | 0.94 [14.00-14.56 / 14.65-15.24] | pass (<=1.10) |
| iterate | 16384 | 0.94 [13.93-14.41 / 14.77-15.10] | pass (<=1.10) |
| insert_nth | 4 | 1.04 [24.99-37.94 / 26.55-39.92] | warm-up, not read |
| insert_nth | 16 | 1.16 [22.13-29.49 / 22.23-30.86] | pass (overlap) |
| insert_nth | 32 | 1.01 [24.38-37.09 / 25.27-36.73] | pass |
| insert_nth | 63 | 1.00 [89.05-101.40 / 28.98-95.94] | pass |
| insert_nth | 64 | 0.99 [29.11-37.93 / 29.11-31.30] | pass |
| insert_nth | 65 | 0.97 [29.60-37.01 / 30.27-33.51] | migration: see 97th |
| insert_nth | 128 | 0.97 [28.14-34.87 / 28.67-30.25] | pass |
| insert_nth | 256 | 0.99 [29.31-35.22 / 29.82-32.05] | pass |
| insert_nth | 1024 | 0.95 [31.63-37.58 / 32.41-36.64] | pass |
| insert_nth | 16384 | 0.86 [40.25-52.75 / 47.75-112.75] | pass |

migration: c-lto 65th 31 ns [30-37] vs c 97th 1839 ns [1681-1979] = 0.02; c-lto 97th 1923 ns

cells judged: 53, FAIL: 0 []

