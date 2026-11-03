# Hash statistics

Files: 100 (0 header-only)
Hash cycles: 1644589209 of 20947065596 (7.9%)

## Sites

### s5 MVMHash_bind_key (src/6model/reprs/MVMHash.c:115)

Site cycles: 1042751283 (63.4% of hash, 5.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 241250 | 12885661 | 53.4 | 0.8 | 0.1 |
| insert | 3933950 | 764199986 | 194.3 | 46.5 | 3.6 |
| overwrite | 14650 | 1489858 | 101.7 | 0.1 | 0.0 |
| fetch_hit | 1781300 | 182653878 | 102.5 | 11.1 | 0.9 |
| fetch_miss | 944750 | 81183595 | 85.9 | 4.9 | 0.4 |
| delete_hit | 300 | 111888 | 373.0 | 0.0 | 0.0 |
| delete_miss | 1150 | 226417 | 196.9 | 0.0 | 0.0 |
| iter_start | 12650 | 0 | 0.0 | 0.0 | 0.0 |
| iter_step | 62500 | 0 | 0.0 | 0.0 | 0.0 |
| copy | 1550 | 0 | 0.0 | 0.0 | 0.0 |
| grow | 174815 | 196066067 | 1121.6 | (in insert) | (in insert) |
| migrate | 9900 | 60235455 | 6084.4 | (in insert) | (in insert) |

- build: <=4=241250

### i1 MVM_vm_create_instance (src/moar.c:182)

Site cycles: 159636352 (9.7% of hash, 0.8% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 100 | 64598966 | 645989.7 | 3.9 | 0.3 |
| insert | 4700 | 2279348 | 485.0 | 0.1 | 0.0 |
| fetch_hit | 264050 | 92758038 | 351.3 | 5.6 | 0.4 |
| grow | 11 | 1480 | 134.5 | (in insert) | (in insert) |

- build: <=64=100

### u4 MVM_unicode_init (src/strings/unicode_ops.c:959)

Site cycles: 149461301 (9.1% of hash, 0.7% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 11500 | 430485 | 37.4 | 0.0 | 0.0 |
| insert | 505800 | 146381956 | 289.4 | 8.9 | 0.7 |
| overwrite | 26600 | 2648860 | 99.6 | 0.2 | 0.0 |
| grow | 14400 | 91734579 | 6370.5 | (in insert) | (in insert) |

- build: <=4=11500

### i2 MVM_bytecode_finish_frame (src/core/bytecode.c:667)

Site cycles: 137292462 (8.3% of hash, 0.7% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 20200 | 4041177 | 200.1 | 0.2 | 0.0 |
| insert | 288300 | 53151635 | 184.4 | 3.2 | 0.3 |
| fetch_hit | 1117600 | 76694648 | 68.6 | 4.7 | 0.4 |
| fetch_miss | 24350 | 3405002 | 139.8 | 0.2 | 0.0 |
| grow | 21 | 3626 | 172.7 | (in insert) | (in insert) |

- build: <=16=17650 <=32=1650 <=64=400 <=128=400 <=256=50 <=1024=50

### f8 MVM_disp_syscall_setup (src/disp/syscall.c:1671)

Site cycles: 56498792 (3.4% of hash, 0.3% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 100 | 4523 | 45.2 | 0.0 | 0.0 |
| insert | 8400 | 4001370 | 476.4 | 0.2 | 0.0 |
| fetch_hit | 116250 | 52492899 | 451.6 | 3.2 | 0.3 |
| grow | 431 | 485551 | 1126.6 | (in insert) | (in insert) |

- build: <=4=100

### u1 generate_property_codes_by_names_aliases (src/strings/unicode_ops.c:915)

Site cycles: 21900825 (1.3% of hash, 0.1% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 50 | 1038738 | 20774.8 | 0.1 | 0.0 |
| insert | 219000 | 20831673 | 95.1 | 1.3 | 0.1 |
| fetch_hit | 100 | 30414 | 304.1 | 0.0 | 0.0 |
| grow | 50 | 26048 | 521.0 | (in insert) | (in insert) |

- build: <=16384=50

### f1 MVM_vm_create_instance (src/moar.c:186)

Site cycles: 21136668 (1.3% of hash, 0.1% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 100 | 67044 | 670.4 | 0.0 | 0.0 |
| insert | 150 | 47027 | 313.5 | 0.0 | 0.0 |
| overwrite | 251169 | 21022597 | 83.7 | 1.3 | 0.1 |

- build: <=4=100

### f4 MVM_vm_create_instance (src/moar.c:195)

Site cycles: 20945155 (1.3% of hash, 0.1% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 100 | 3451 | 34.5 | 0.0 | 0.0 |
| insert | 50 | 4107 | 82.1 | 0.0 | 0.0 |
| fetch_hit | 17850 | 20881579 | 1169.8 | 1.3 | 0.1 |
| fetch_miss | 50 | 56018 | 1120.4 | 0.0 | 0.0 |

- build: <=4=100

### s1 MVM_vm_create_instance (src/moar.c:203)

Site cycles: 16673340 (1.0% of hash, 0.1% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 100 | 12987 | 129.9 | 0.0 | 0.0 |
| insert | 2150 | 1625560 | 756.1 | 0.1 | 0.0 |
| overwrite | 8250 | 6293663 | 762.9 | 0.4 | 0.0 |
| fetch_hit | 14600 | 8741130 | 598.7 | 0.5 | 0.0 |
| grow | 150 | 51800 | 345.3 | (in insert) | (in insert) |

- build: <=4=100

### other

Site cycles: 10697546 (0.7% of hash, 0.1% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| fetch_miss | 249800 | 10697546 | 42.8 | 0.7 | 0.1 |
| iter_start | 5350 | 0 | 0.0 | 0.0 | 0.0 |

### f6 MVM_vm_create_instance (src/moar.c:207)

Site cycles: 3478387 (0.2% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 100 | 3197 | 32.0 | 0.0 | 0.0 |
| insert | 1850 | 861510 | 465.7 | 0.1 | 0.0 |
| fetch_hit | 200 | 463240 | 2316.2 | 0.0 | 0.0 |
| fetch_miss | 1850 | 2150440 | 1162.4 | 0.1 | 0.0 |
| grow | 202 | 425611 | 2107.0 | (in insert) | (in insert) |

- build: <=4=100

### f3 MVM_vm_create_instance (src/moar.c:191)

Site cycles: 1896802 (0.1% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 100 | 3304 | 33.0 | 0.0 | 0.0 |
| insert | 50 | 16946 | 338.9 | 0.0 | 0.0 |
| fetch_hit | 17900 | 1851392 | 103.4 | 0.1 | 0.0 |
| fetch_miss | 50 | 25160 | 503.2 | 0.0 | 0.0 |

- build: <=4=100

### p1 MVM_gc_object_id (src/gc/objectid.c:28)

Site cycles: 759663 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 100 | 10915 | 109.2 | 0.0 | 0.0 |
| insert | 1400 | 461701 | 329.8 | 0.0 | 0.0 |
| fetch_hit | 2950 | 287047 | 97.3 | 0.0 | 0.0 |
| grow | 150 | 162356 | 1082.4 | (in insert) | (in insert) |

- build: <=4=100

### f7 MVM_vm_create_instance (src/moar.c:210)

Site cycles: 637555 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 100 | 3486 | 34.9 | 0.0 | 0.0 |
| insert | 300 | 90724 | 302.4 | 0.0 | 0.0 |
| fetch_hit | 1600 | 543345 | 339.6 | 0.0 | 0.0 |

- build: <=4=100

### f5 MVM_vm_create_instance (src/moar.c:199)

Site cycles: 460425 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 100 | 3860 | 38.6 | 0.0 | 0.0 |
| insert | 500 | 82754 | 165.5 | 0.0 | 0.0 |
| fetch_hit | 150 | 270618 | 1804.1 | 0.0 | 0.0 |
| fetch_miss | 500 | 103193 | 206.4 | 0.0 | 0.0 |
| grow | 50 | 29156 | 583.1 | (in insert) | (in insert) |

- build: <=4=100

### s6 deserialize (src/6model/reprs/MVMHash.c:192)

Site cycles: 359204 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 250 | 57979 | 231.9 | 0.0 | 0.0 |
| insert | 900 | 148522 | 165.0 | 0.0 | 0.0 |
| fetch_hit | 1800 | 126544 | 70.3 | 0.0 | 0.0 |
| fetch_miss | 100 | 26159 | 261.6 | 0.0 | 0.0 |

- build: <=4=200 <=16=50

### f2 MVM_vm_create_instance (src/moar.c:187)

Site cycles: 3449 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 100 | 3449 | 34.5 | 0.0 | 0.0 |

- build: <=4=100

## Census sites not seen

i3 p2 s2 s3 s4 s7 s8 s9 u2 u3

## Hash share

| program | files | header-only | total cycles | hash cycles | % |
|---|---|---|---|---|---|
| nqp -e | 50 | 0 | 3041223103 | 278658170 | 9.2 |
| raku -e | 50 | 0 | 17905842493 | 1365931039 | 7.6 |
