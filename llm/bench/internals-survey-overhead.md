# Internal tables survey: instrumentation overhead bound (2026-11-03)

**Run.** MoarVM `zig-hash-internals` at 1919eddda (traces 29be364), default
build (LTO, x86-64-v3) in `/tmp/claude-1000/tune-zig-prefix` against the stats
build (`-Dhash-stats=true`, same flags) in `/tmp/claude-1000/stats-zig-prefix`,
both rebuilt at HEAD after `rm -f src/gen/config.{h,c,o}`. AMD Ryzen 9 5900X.
`MVM_HASH_STATS` unset for both variants: the stats build still counts, the
cost of counting is what is measured. 1-minute load 1.05-1.13 before every
round (`internals-survey-overhead-hash-ab-load.log`); the runner waits for
load under 2.0.

    tools/bench/hash-ab.sh --rounds=5 --sizes=16,64,65,1024,16384 \
      --out=<scratch>/overhead \
      --variant=default:/tmp/claude-1000/tune-zig-prefix/lib:/tmp/claude-1000/tune-zig-prefix/bin/hash-bench \
      --variant=stats:/tmp/claude-1000/stats-zig-prefix/lib:/tmp/claude-1000/stats-zig-prefix/bin/hash-bench

(`--runs=5`, `--nth=all` by default; the nqp ladder runs through
`nqp-m` of tune-zig-prefix, the C-API ladder through the `hash-bench` exe.)

**Rule.** Overhead factor = stats / default ns per op, median of the 5 round
medians (the first number of each cell below; the bracket is the min-max of
round medians, stats then default). A factor is only as good as its spread:
cells whose brackets reach 40+ ns at sizes 16 and 1024 and 16384 (the first
round of each process, page faults and growth) are noisy; the size 64 and 65
cells are the cleanest.

**Result.** The counting is not free. At the C API (the level that matches the
hooks) lookups cost 2.1-3.5x (about +10 ns per call: two `rdtsc` and the
counter updates), deletes 2.0-2.3x, inserts 1.16-1.75x, iterate 1.13-1.31x
(iteration cycles are not counted, only the start and the steps). At the nqp
level, where interpretation dilutes it, lookups cost 1.5-2.3x, inserts
1.1-1.4x, overwrite 1.3-1.4x, iterate 1.05-1.12x. Take **about 2.3x for
fetches, 1.2-1.7x for inserts, 1.1-1.3x for iteration** as the factors the
survey applies; 3.5x is the worst cell (C-API lookup_miss at size 16).
Absolute cycle figures of the survey are therefore inflated, most for
lookup-heavy sites; shares between sites are inflated unevenly (more for sites
dominated by fetches, less for sites dominated by inserts and iteration).

Raw: `internals-survey-overhead-{nqp,capi}-{default,stats}.tsv` (the harness's
7 columns, per variant), `internals-survey-overhead-hash-ab-load.log`.

## nqp ladder (stats / default)

### insert

| size | nqp-stats / base |
|---:|---:|
| 16 | 1.42 [28.56-66.28 / 18.86-60.24] |
| 64 | 1.44 [29.63-35.12 / 20.59-29.69] |
| 65 | 1.25 [45.37-50.50 / 35.85-45.93] |
| 1024 | 1.33 [55.59-1150.54 / 46.07-1051.31] |
| 16384 | 1.11 [79.98-725.12 / 79.55-541.66] |

### lookup_hit

| size | nqp-stats / base |
|---:|---:|
| 16 | 1.55 [21.56-61.65 / 10.33-47.42] |
| 64 | 1.97 [23.09-26.07 / 11.47-50.83] |
| 65 | 1.79 [23.42-24.34 / 12.88-41.77] |
| 1024 | 1.71 [23.51-32.54 / 13.24-41.91] |
| 16384 | 1.46 [25.18-45.56 / 15.15-56.44] |

### lookup_miss

| size | nqp-stats / base |
|---:|---:|
| 16 | 2.26 [20.06-51.19 / 9.54-45.77] |
| 64 | 1.87 [21.31-24.24 / 11.21-13.27] |
| 65 | 1.80 [23.34-24.12 / 12.78-13.86] |
| 1024 | 1.81 [22.97-23.99 / 12.75-13.42] |
| 16384 | 1.74 [24.18-28.38 / 13.89-17.71] |

### delete

| size | nqp-stats / base |
|---:|---:|
| 16 | 1.38 [20.03-48.70 / 9.75-43.36] |
| 64 | 1.75 [21.11-23.97 / 11.64-12.73] |
| 65 | 1.74 [23.07-23.71 / 13.14-13.65] |
| 1024 | 1.73 [23.18-32.89 / 13.33-25.25] |
| 16384 | 1.59 [24.35-31.04 / 15.32-26.97] |

### iterate

| size | nqp-stats / base |
|---:|---:|
| 16 | 1.10 [12.21-45.93 / 10.94-40.55] |
| 64 | 1.12 [10.76-12.15 / 9.51-11.37] |
| 65 | 1.06 [15.74-16.45 / 14.92-15.46] |
| 1024 | 1.06 [15.24-16.01 / 14.28-15.48] |
| 16384 | 1.05 [14.99-16.16 / 14.22-15.16] |

### overwrite

| size | nqp-stats / base |
|---:|---:|
| 16 | 1.32 [23.51-58.74 / 15.74-50.70] |
| 64 | 1.41 [24.96-28.69 / 17.26-18.93] |
| 65 | 1.38 [27.90-29.03 / 20.38-22.32] |
| 1024 | 1.37 [28.17-29.65 / 20.55-22.73] |
| 16384 | 1.31 [30.03-32.22 / 22.73-26.84] |

### clone

| size | nqp-stats / base |
|---:|---:|
| 16 | 1.36 [5.82-10.94 / 4.15-69.29] |
| 64 | 1.33 [4.88-8.18 / 3.14-7.42] |
| 65 | 1.13 [13.61-20.00 / 14.06-16.62] |
| 1024 | 0.60 [11.62-109.19 / 10.60-318.11] |
| 16384 | 1.04 [25.04-539.58 / 23.65-892.20] |

### iterate_delete

| size | nqp-stats / base |
|---:|---:|
| 16 | 1.55 [31.20-64.72 / 20.41-49.39] |
| 64 | 1.50 [31.39-33.87 / 20.70-22.36] |
| 65 | 1.42 [37.61-38.55 / 26.81-27.97] |
| 1024 | 1.40 [37.36-41.01 / 26.53-27.52] |
| 16384 | 1.28 [41.06-53.51 / 32.01-33.94] |

### insert_nth

| size | nqp-stats / base |
|---:|---:|
| 16 | 0.78 [22.37-67.72 / 13.97-85.16] |
| 64 | 1.31 [23.64-31.66 / 15.07-26.13] |
| 65 | 0.99 [991.34-1129.78 / 838.26-1094.03] |
| 1024 | 1.11 [44.92-175.81 / 40.70-187.55] |
| 16384 | 0.98 [67.50-375.75 / 50.00-561.25] |


## C-API ladder (stats / default)

### insert

| size | capi-stats / base |
|---:|---:|
| 16 | 1.75 [22.19-25.55 / 12.56-14.97] |
| 64 | 1.62 [22.31-27.33 / 13.46-20.20] |
| 65 | 1.29 [38.10-40.75 / 29.59-35.65] |
| 1024 | 1.19 [47.05-54.16 / 42.26-45.89] |
| 16384 | 1.16 [49.18-67.84 / 41.14-53.93] |

### lookup_hit

| size | capi-stats / base |
|---:|---:|
| 16 | 3.26 [15.74-18.03 / 4.78-6.25] |
| 64 | 3.11 [17.48-19.02 / 5.60-6.53] |
| 65 | 2.30 [17.77-19.20 / 7.65-8.72] |
| 1024 | 2.28 [17.91-21.54 / 7.66-8.59] |
| 16384 | 2.17 [18.60-24.86 / 8.34-9.03] |

### lookup_miss

| size | capi-stats / base |
|---:|---:|
| 16 | 3.49 [15.30-15.90 / 4.42-4.85] |
| 64 | 2.85 [16.09-17.48 / 5.43-6.51] |
| 65 | 2.22 [17.92-19.09 / 7.98-8.81] |
| 1024 | 2.25 [17.85-18.77 / 7.97-8.43] |
| 16384 | 2.07 [19.28-23.92 / 9.42-12.90] |

### delete

| size | capi-stats / base |
|---:|---:|
| 16 | 2.30 [15.71-16.53 / 6.74-9.29] |
| 64 | 1.96 [16.49-17.86 / 8.61-9.24] |
| 65 | 2.29 [18.54-19.50 / 7.97-8.53] |
| 1024 | 2.35 [18.55-19.66 / 7.88-8.24] |
| 16384 | 2.22 [19.10-20.25 / 8.56-8.93] |

### iterate

| size | capi-stats / base |
|---:|---:|
| 16 | 1.30 [8.14-8.52 / 6.25-6.90] |
| 64 | 1.31 [8.04-8.40 / 6.08-6.57] |
| 65 | 1.13 [12.42-12.88 / 11.03-11.62] |
| 1024 | 1.13 [12.23-12.79 / 10.64-11.08] |
| 16384 | 1.14 [12.19-12.77 / 10.61-10.95] |

### insert_nth

| size | capi-stats / base |
|---:|---:|
| 16 | 2.00 [17.23-20.13 / 8.52-9.03] |
| 64 | 1.65 [17.86-20.82 / 10.03-36.73] |
| 65 | 0.99 [979.01-1104.71 / 1025.28-1105.08] |
| 1024 | 1.35 [32.09-38.36 / 22.23-28.81] |
| 16384 | 1.15 [32.75-222.75 / 20.25-47.75] |

