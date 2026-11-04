# Uni benchmark, base against head after gating the Swiss set (2026-11-04)

5 rounds, both variants through the head's uni-bench exe, ladder=uni; head = libmoar without the Swiss set and with the plain hash (no widen). Ratios are head over base by round medians, [base range / head range] ns. Raw: internals-uni-widen/.

## capi

### cpbyname_hit

| size | capi-head / base |
|---:|---:|
| 4096 | 1.00 [45.14-46.30 / 44.92-45.98] |

### cpbyname_miss

| size | capi-head / base |
|---:|---:|
| 4096 | 0.99 [35.11-36.46 / 35.16-36.75] |

### cpbyname_miss_prefix

| size | capi-head / base |
|---:|---:|
| 4096 | 0.97 [28.19-28.69 / 28.89-30.04] |

### propcode_hit

| size | capi-head / base |
|---:|---:|
| 114 | 0.99 [17.91-18.58 / 18.03-19.12] |

### propcode_alias

| size | capi-head / base |
|---:|---:|
| 4266 | 0.98 [23.69-24.53 / 24.09-25.17] |

### propcode_miss

| size | capi-head / base |
|---:|---:|
| 4380 | 0.98 [20.71-21.17 / 21.11-21.48] |

### pvalcode_hit

| size | capi-head / base |
|---:|---:|
| 1024 | 0.97 [16.42-16.78 / 16.77-17.40] |

### pvalcode_miss

| size | capi-head / base |
|---:|---:|
| 1024 | 0.97 [14.13-14.51 / 14.46-14.79] |

### strfromname_seq

| size | capi-head / base |
|---:|---:|
| 3680 | 1.00 [47.75-48.76 / 47.48-48.56] |


## nqp

### cpbyname_hit

| size | nqp-head / base |
|---:|---:|
| 4096 | 0.91 [161.90-178.90 / 178.97-199.83] |

### cpbyname_miss

| size | nqp-head / base |
|---:|---:|
| 4096 | 0.95 [262.30-280.14 / 279.64-294.93] |

### cpbyname_miss_prefix

| size | nqp-head / base |
|---:|---:|
| 4096 | 0.97 [223.41-231.13 / 231.21-239.73] |

### propcode_hit

| size | nqp-head / base |
|---:|---:|
| 114 | 0.99 [113.30-124.82 / 113.52-118.05] |

### propcode_alias

| size | nqp-head / base |
|---:|---:|
| 4266 | 0.97 [99.71-115.29 / 102.85-109.80] |

### propcode_miss

| size | nqp-head / base |
|---:|---:|
| 4380 | 0.98 [92.83-105.62 / 96.21-101.69] |

### pvalcode_hit

| size | nqp-head / base |
|---:|---:|
| 1024 | 1.02 [147.16-159.43 / 146.11-154.24] |

### pvalcode_miss

| size | nqp-head / base |
|---:|---:|
| 1024 | 1.00 [145.70-153.40 / 143.52-151.33] |

### strfromname_seq

| size | nqp-head / base |
|---:|---:|
| 3680 | 0.95 [971.80-1072.33 / 1008.56-1118.65] |

