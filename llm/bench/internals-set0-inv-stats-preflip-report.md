# Hash statistics

Files: 1 (0 header-only)
Hash cycles: 5172120104 of 128942319017 (4.0%)

## Sites

### s5 MVMHash_bind_key (src/6model/reprs/MVMHash.c:115)

Site cycles: 3907055498 (75.5% of hash, 3.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 940330 | 53615791 | 57.0 | 1.0 | 0.0 |
| insert | 3315921 | 838679003 | 252.9 | 16.2 | 0.7 |
| overwrite | 437246 | 40271616 | 92.1 | 0.8 | 0.0 |
| fetch_hit | 27713269 | 2454518500 | 88.6 | 47.5 | 1.9 |
| fetch_miss | 6486974 | 504910099 | 77.8 | 9.8 | 0.4 |
| delete_hit | 26475 | 12314377 | 465.1 | 0.2 | 0.0 |
| delete_miss | 8290 | 2746112 | 331.3 | 0.1 | 0.0 |
| iter_start | 1126858 | 0 | 0.0 | 0.0 | 0.0 |
| iter_step | 4262868 | 0 | 0.0 | 0.0 | 0.0 |
| copy | 41744 | 0 | 0.0 | 0.0 | 0.0 |
| grow | 150751 | 48769884 | 323.5 | (in insert) | (in insert) |
| migrate | 546 | 2459131 | 4503.9 | (in insert) | (in insert) |
| demolish | 967374 | 0 | 0.0 | 0.0 | 0.0 |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 2982374 | 2738027 | 472999006 | 16.0 |
| <=16 | 6431104 | 1934938 | 593450752 | 20.1 |
| <=32 | 621581 | 517456 | 136168536 | 4.6 |
| <=64 | 2482705 | 873397 | 187395616 | 6.3 |
| <=65 | 195 | 163124 | 14712729 | 0.5 |
| <=128 | 14035 | 216328 | 30421683 | 1.0 |
| <=256 | 210601 | 42451 | 39305208 | 1.3 |
| <=1024 | 14964045 | 1253 | 1484427753 | 50.2 |
| <=16384 | 6629 | 0 | 547316 | 0.0 |

- at or above 65 entries: 45.7% of fetches, 53.0% of fetch cycles
- at or above 128 entries: 45.2% of fetches, 52.5% of fetch cycles

- build: <=4=940330
- demolish set 0 rung 0: <=4=786049 <=16=164251 <=32=966 <=64=8119
- demolish set 0 rung 1: <=65=1 <=128=7987 <=1024=1

### i2 MVM_bytecode_finish_frame (src/core/bytecode.c:667)

Site cycles: 723230991 (14.0% of hash, 0.6% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 8810 | 2476225 | 281.1 | 0.0 | 0.0 |
| insert | 97257 | 31573668 | 324.6 | 0.6 | 0.0 |
| fetch_hit | 4210549 | 409010536 | 97.1 | 7.9 | 0.3 |
| fetch_miss | 4406925 | 280170562 | 63.6 | 5.4 | 0.2 |
| demolish | 7535 | 0 | 0.0 | 0.0 | 0.0 |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=16 | 2843828 | 3248763 | 365337425 | 53.0 |
| <=32 | 541285 | 660463 | 126434696 | 18.3 |
| <=64 | 104410 | 497580 | 52902498 | 7.7 |
| <=128 | 48811 | 62 | 9861574 | 1.4 |
| <=256 | 30 | 2 | 10138 | 0.0 |
| <=1024 | 672185 | 55 | 134634767 | 19.5 |

- at or above 65 entries: 8.4% of fetches, 21.0% of fetch cycles
- at or above 128 entries: 8.4% of fetches, 21.0% of fetch cycles

- build: <=16=8752 <=32=39 <=64=10 <=128=7 <=256=1 <=1024=1
- demolish set 0 rung 0: <=16=7535

### p1 MVM_gc_object_id (src/gc/objectid.c:28)

Site cycles: 197568081 (3.8% of hash, 0.2% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 37 | 37.0 | 0.0 | 0.0 |
| insert | 788128 | 81195043 | 103.0 | 1.6 | 0.1 |
| fetch_hit | 1425493 | 69176662 | 48.5 | 1.3 | 0.1 |
| delete_hit | 788128 | 47196339 | 59.9 | 0.9 | 0.0 |
| grow | 14 | 110815 | 7915.4 | (in insert) | (in insert) |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 2621 | 0 | 116542 | 0.2 |
| <=16 | 8491 | 0 | 384991 | 0.6 |
| <=32 | 11714 | 0 | 521987 | 0.8 |
| <=64 | 27247 | 0 | 1293844 | 1.9 |
| <=65 | 1078 | 0 | 42808 | 0.1 |
| <=128 | 55365 | 0 | 2448786 | 3.5 |
| <=256 | 114159 | 0 | 5331701 | 7.7 |
| <=1024 | 699658 | 0 | 33361725 | 48.2 |
| <=16384 | 505160 | 0 | 25674278 | 37.1 |

- at or above 65 entries: 96.5% of fetches, 96.7% of fetch cycles
- at or above 128 entries: 96.4% of fetches, 96.6% of fetch cycles

- build: <=4=1

### other

Site cycles: 118573062 (2.3% of hash, 0.1% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| fetch_miss | 2378519 | 118573062 | 49.9 | 2.3 | 0.1 |
| iter_start | 472974 | 0 | 0.0 | 0.0 | 0.0 |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 0 | 2378519 | 118573062 | 100.0 |

- at or above 65 entries: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128 entries: 0.0% of fetches, 0.0% of fetch cycles

### s6 deserialize (src/6model/reprs/MVMHash.c:192)

Site cycles: 91549755 (1.8% of hash, 0.1% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 31 | 11692 | 377.2 | 0.0 | 0.0 |
| insert | 436 | 64275 | 147.4 | 0.0 | 0.0 |
| overwrite | 4 | 962 | 240.5 | 0.0 | 0.0 |
| fetch_hit | 125951 | 6362317 | 50.5 | 0.1 | 0.0 |
| fetch_miss | 721127 | 85110509 | 118.0 | 1.6 | 0.1 |
| iter_start | 287 | 0 | 0.0 | 0.0 | 0.0 |
| iter_step | 4446 | 0 | 0.0 | 0.0 | 0.0 |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 125908 | 254966 | 19646279 | 21.5 |
| <=16 | 38 | 451590 | 70942114 | 77.6 |
| <=32 | 0 | 14571 | 882324 | 1.0 |
| <=64 | 3 | 0 | 1813 | 0.0 |
| <=256 | 2 | 0 | 296 | 0.0 |

- at or above 65 entries: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128 entries: 0.0% of fetches, 0.0% of fetch cycles

- build: <=4=12 <=16=13 <=32=3 <=64=2 <=256=1

### s1 MVM_vm_create_instance (src/moar.c:203)

Site cycles: 69752958 (1.3% of hash, 0.1% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 296 | 296.0 | 0.0 | 0.0 |
| insert | 8100 | 8768149 | 1082.5 | 0.2 | 0.0 |
| overwrite | 48915 | 55100955 | 1126.5 | 1.1 | 0.0 |
| fetch_hit | 267 | 167575 | 627.6 | 0.0 | 0.0 |
| delete_hit | 7535 | 5715983 | 758.6 | 0.1 | 0.0 |
| iter_start | 503 | 0 | 0.0 | 0.0 | 0.0 |
| iter_step | 401801 | 0 | 0.0 | 0.0 | 0.0 |
| grow | 12 | 510859 | 42571.6 | (in insert) | (in insert) |
| migrate | 1 | 14652 | 14652.0 | (in insert) | (in insert) |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=16 | 20 | 0 | 10804 | 6.4 |
| <=32 | 240 | 0 | 150037 | 89.5 |
| <=64 | 7 | 0 | 6734 | 4.0 |

- at or above 65 entries: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128 entries: 0.0% of fetches, 0.0% of fetch cycles

- build: <=4=1

### f4 MVM_vm_create_instance (src/moar.c:195)

Site cycles: 26685177 (0.5% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 37 | 37.0 | 0.0 | 0.0 |
| insert | 1 | 74 | 74.0 | 0.0 | 0.0 |
| fetch_hit | 13272 | 26684104 | 2010.6 | 0.5 | 0.0 |
| fetch_miss | 1 | 962 | 962.0 | 0.0 | 0.0 |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 13272 | 1 | 26685066 | 100.0 |

- at or above 65 entries: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128 entries: 0.0% of fetches, 0.0% of fetch cycles

- build: <=4=1

### i1 MVM_vm_create_instance (src/moar.c:182)

Site cycles: 11059892 (0.2% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 465867 | 465867.0 | 0.0 | 0.0 |
| insert | 47 | 35187 | 748.7 | 0.0 | 0.0 |
| fetch_hit | 21773 | 10558838 | 485.0 | 0.2 | 0.0 |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=64 | 21773 | 0 | 10558838 | 100.0 |

- at or above 65 entries: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128 entries: 0.0% of fetches, 0.0% of fetch cycles

- build: <=64=1

### f8 MVM_disp_syscall_setup (src/disp/syscall.c:1671)

Site cycles: 10607900 (0.2% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 74 | 74.0 | 0.0 | 0.0 |
| insert | 84 | 52873 | 629.4 | 0.0 | 0.0 |
| fetch_hit | 20137 | 10554953 | 524.2 | 0.2 | 0.0 |
| grow | 4 | 9102 | 2275.5 | (in insert) | (in insert) |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=128 | 20137 | 0 | 10554953 | 100.0 |

- at or above 65 entries: 100.0% of fetches, 100.0% of fetch cycles
- at or above 128 entries: 100.0% of fetches, 100.0% of fetch cycles

- build: <=4=1

### f1 MVM_vm_create_instance (src/moar.c:186)

Site cycles: 8751388 (0.2% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 703 | 703.0 | 0.0 | 0.0 |
| insert | 2 | 1147 | 573.5 | 0.0 | 0.0 |
| overwrite | 30619 | 8749538 | 285.8 | 0.2 | 0.0 |

- build: <=4=1

### f3 MVM_vm_create_instance (src/moar.c:191)

Site cycles: 5436744 (0.1% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 1 | 1.0 | 0.0 | 0.0 |
| insert | 1 | 481 | 481.0 | 0.0 | 0.0 |
| fetch_hit | 13273 | 5435818 | 409.5 | 0.1 | 0.0 |
| fetch_miss | 1 | 444 | 444.0 | 0.0 | 0.0 |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 13273 | 1 | 5436262 | 100.0 |

- at or above 65 entries: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128 entries: 0.0% of fetches, 0.0% of fetch cycles

- build: <=4=1

### u4 MVM_unicode_init (src/strings/unicode_ops.c:967)

Site cycles: 1376176 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 115 | 479076 | 4165.9 | 0.0 | 0.0 |
| insert | 5058 | 852330 | 168.5 | 0.0 | 0.0 |
| overwrite | 266 | 44770 | 168.3 | 0.0 | 0.0 |
| grow | 1 | 555 | 555.0 | (in insert) | (in insert) |

- build: <=4=7 <=16=90 <=32=2 <=64=6 <=128=3 <=256=4 <=1024=2 <=16384=1

### u1 generate_property_codes_by_names_aliases (src/strings/unicode_ops.c:915)

Site cycles: 378317 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 8103 | 8103.0 | 0.0 | 0.0 |
| insert | 4380 | 369918 | 84.5 | 0.0 | 0.0 |
| fetch_hit | 2 | 296 | 148.0 | 0.0 | 0.0 |
| grow | 1 | 481 | 481.0 | (in insert) | (in insert) |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=16384 | 2 | 0 | 296 | 100.0 |

- at or above 65 entries: 100.0% of fetches, 100.0% of fetch cycles
- at or above 128 entries: 100.0% of fetches, 100.0% of fetch cycles

- build: <=16384=1

### f6 MVM_vm_create_instance (src/moar.c:207)

Site cycles: 70189 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 37 | 37.0 | 0.0 | 0.0 |
| insert | 29 | 16946 | 584.3 | 0.0 | 0.0 |
| fetch_hit | 7 | 17871 | 2553.0 | 0.0 | 0.0 |
| fetch_miss | 29 | 35335 | 1218.4 | 0.0 | 0.0 |
| grow | 3 | 9842 | 3280.7 | (in insert) | (in insert) |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 0 | 5 | 5476 | 10.3 |
| <=16 | 0 | 12 | 13431 | 25.2 |
| <=32 | 7 | 12 | 34299 | 64.5 |

- at or above 65 entries: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128 entries: 0.0% of fetches, 0.0% of fetch cycles

- build: <=4=1

### f7 MVM_vm_create_instance (src/moar.c:210)

Site cycles: 14874 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 37 | 37.0 | 0.0 | 0.0 |
| insert | 3 | 1961 | 653.7 | 0.0 | 0.0 |
| fetch_hit | 32 | 12876 | 402.4 | 0.0 | 0.0 |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 32 | 0 | 12876 | 100.0 |

- at or above 65 entries: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128 entries: 0.0% of fetches, 0.0% of fetch cycles

- build: <=4=1

### f5 MVM_vm_create_instance (src/moar.c:199)

Site cycles: 9065 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 37 | 37.0 | 0.0 | 0.0 |
| insert | 10 | 1665 | 166.5 | 0.0 | 0.0 |
| fetch_hit | 3 | 5439 | 1813.0 | 0.0 | 0.0 |
| fetch_miss | 10 | 1924 | 192.4 | 0.0 | 0.0 |
| grow | 1 | 740 | 740.0 | (in insert) | (in insert) |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 0 | 5 | 1184 | 16.1 |
| <=16 | 3 | 5 | 6179 | 83.9 |

- at or above 65 entries: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128 entries: 0.0% of fetches, 0.0% of fetch cycles

- build: <=4=1

### f2 MVM_vm_create_instance (src/moar.c:187)

Site cycles: 37 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 37 | 37.0 | 0.0 | 0.0 |

- build: <=4=1

## Hash share

| program | files | header-only | total cycles | hash cycles | % |
|---|---|---|---|---|---|
| rakudo.moarvm | 1 | 0 | 128942319017 | 5172120104 | 4.0 |
