# Hash statistics

Files: 1 (0 header-only)
Hash cycles: 5838916818 of 148053138401 (3.9%)

## Sites

### s5 MVMHash_bind_key (src/6model/reprs/MVMHash.c:115)

Site cycles: 4400486132 (75.4% of hash, 3.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1099125 | 60524874 | 55.1 | 1.0 | 0.0 |
| insert | 3856064 | 920367460 | 238.7 | 15.8 | 0.6 |
| overwrite | 501267 | 47242953 | 94.2 | 0.8 | 0.0 |
| fetch_hit | 32074233 | 2787549711 | 86.9 | 47.7 | 1.9 |
| fetch_miss | 7477189 | 568373224 | 76.0 | 9.7 | 0.4 |
| delete_hit | 30894 | 13938919 | 451.2 | 0.2 | 0.0 |
| delete_miss | 9763 | 2488991 | 254.9 | 0.0 | 0.0 |
| iter_start | 1311006 | 0 | 0.0 | 0.0 | 0.0 |
| iter_step | 4874198 | 0 | 0.0 | 0.0 | 0.0 |
| copy | 49109 | 0 | 0.0 | 0.0 | 0.0 |
| grow | 176518 | 58974397 | 334.1 | (in insert) | (in insert) |
| migrate | 546 | 1606426 | 2942.2 | (in insert) | (in insert) |
| demolish | 1125136 | 0 | 0.0 | 0.0 | 0.0 |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 3483962 | 3170619 | 555815133 | 16.6 |
| <=16 | 7362470 | 2219786 | 637995363 | 19.0 |
| <=32 | 696477 | 595286 | 133051952 | 4.0 |
| <=64 | 2944809 | 1008265 | 193202172 | 5.8 |
| <=65 | 195 | 186005 | 11635957 | 0.3 |
| <=128 | 14035 | 246978 | 38568050 | 1.1 |
| <=256 | 239220 | 48997 | 44935168 | 1.3 |
| <=1024 | 17326436 | 1253 | 1740425150 | 51.9 |
| <=16384 | 6629 | 0 | 293990 | 0.0 |

- at or above 65 entries: 45.7% of fetches, 54.7% of fetch cycles
- at or above 128 entries: 45.2% of fetches, 54.4% of fetch cycles

- build: <=4=1099125
- demolish set 0 rung 0: <=4=913577 <=16=191597 <=32=966 <=64=9580
- demolish set 0 rung 1: <=65=1 <=128=9414 <=1024=1

### i2 MVM_bytecode_finish_frame (src/core/bytecode.c:667)

Site cycles: 826281074 (14.2% of hash, 0.6% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 10283 | 2917820 | 283.8 | 0.0 | 0.0 |
| insert | 113460 | 35205863 | 310.3 | 0.6 | 0.0 |
| fetch_hit | 4840752 | 454943981 | 94.0 | 7.8 | 0.3 |
| fetch_miss | 5092206 | 333213410 | 65.4 | 5.7 | 0.2 |
| demolish | 8482 | 0 | 0.0 | 0.0 | 0.0 |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=16 | 3277031 | 3763284 | 417463216 | 53.0 |
| <=32 | 613955 | 762918 | 148466338 | 18.8 |
| <=64 | 121834 | 565885 | 56240671 | 7.1 |
| <=128 | 57649 | 62 | 10825863 | 1.4 |
| <=256 | 30 | 2 | 11063 | 0.0 |
| <=1024 | 770253 | 55 | 155150240 | 19.7 |

- at or above 65 entries: 8.3% of fetches, 21.1% of fetch cycles
- at or above 128 entries: 8.3% of fetches, 21.1% of fetch cycles

- build: <=16=10225 <=32=39 <=64=10 <=128=7 <=256=1 <=1024=1
- demolish set 0 rung 0: <=16=8482

### p1 MVM_gc_object_id (src/gc/objectid.c:28)

Site cycles: 217150358 (3.7% of hash, 0.1% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 74 | 74.0 | 0.0 | 0.0 |
| insert | 915850 | 90597306 | 98.9 | 1.6 | 0.1 |
| fetch_hit | 1657267 | 80357513 | 48.5 | 1.4 | 0.1 |
| delete_hit | 914429 | 46195465 | 50.5 | 0.8 | 0.0 |
| grow | 13 | 115144 | 8857.2 | (in insert) | (in insert) |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 3025 | 0 | 141523 | 0.2 |
| <=16 | 9993 | 0 | 472021 | 0.6 |
| <=32 | 13360 | 0 | 581364 | 0.7 |
| <=64 | 31573 | 0 | 1555813 | 1.9 |
| <=65 | 1240 | 0 | 50525 | 0.1 |
| <=128 | 64223 | 0 | 2986591 | 3.7 |
| <=256 | 131996 | 0 | 6175987 | 7.7 |
| <=1024 | 809256 | 0 | 38557374 | 48.0 |
| <=16384 | 592601 | 0 | 29836315 | 37.1 |

- at or above 65 entries: 96.5% of fetches, 96.6% of fetch cycles
- at or above 128 entries: 96.4% of fetches, 96.5% of fetch cycles

- build: <=4=1

### other

Site cycles: 134099354 (2.3% of hash, 0.1% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| fetch_miss | 2753444 | 134099354 | 48.7 | 2.3 | 0.1 |
| iter_start | 557232 | 0 | 0.0 | 0.0 | 0.0 |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 0 | 2753444 | 134099354 | 100.0 |

- at or above 65 entries: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128 entries: 0.0% of fetches, 0.0% of fetch cycles

### s6 deserialize (src/6model/reprs/MVMHash.c:192)

Site cycles: 108568208 (1.9% of hash, 0.1% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 31 | 12099 | 390.3 | 0.0 | 0.0 |
| insert | 436 | 65307 | 149.8 | 0.0 | 0.0 |
| overwrite | 4 | 925 | 231.2 | 0.0 | 0.0 |
| fetch_hit | 148450 | 7073546 | 47.6 | 0.1 | 0.0 |
| fetch_miss | 824765 | 101416331 | 123.0 | 1.7 | 0.1 |
| iter_start | 318 | 0 | 0.0 | 0.0 | 0.0 |
| iter_step | 4882 | 0 | 0.0 | 0.0 | 0.0 |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 148407 | 291437 | 21694164 | 20.0 |
| <=16 | 38 | 517545 | 85818652 | 79.1 |
| <=32 | 0 | 15783 | 975988 | 0.9 |
| <=64 | 3 | 0 | 629 | 0.0 |
| <=256 | 2 | 0 | 444 | 0.0 |

- at or above 65 entries: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128 entries: 0.0% of fetches, 0.0% of fetch cycles

- build: <=4=12 <=16=13 <=32=3 <=64=2 <=256=1

### s1 MVM_vm_create_instance (src/moar.c:203)

Site cycles: 78450399 (1.3% of hash, 0.1% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 333 | 333.0 | 0.0 | 0.0 |
| insert | 9573 | 9355376 | 977.3 | 0.2 | 0.0 |
| overwrite | 56995 | 62777456 | 1101.5 | 1.1 | 0.0 |
| fetch_hit | 267 | 155735 | 583.3 | 0.0 | 0.0 |
| delete_hit | 8482 | 6161499 | 726.4 | 0.1 | 0.0 |
| iter_start | 580 | 0 | 0.0 | 0.0 | 0.0 |
| iter_step | 472714 | 0 | 0.0 | 0.0 | 0.0 |
| grow | 7 | 160691 | 22955.9 | (in insert) | (in insert) |
| migrate | 1 | 9213 | 9213.0 | (in insert) | (in insert) |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=16 | 20 | 0 | 10249 | 6.6 |
| <=32 | 240 | 0 | 138641 | 89.0 |
| <=64 | 7 | 0 | 6845 | 4.4 |

- at or above 65 entries: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128 entries: 0.0% of fetches, 0.0% of fetch cycles

- build: <=4=1

### f4 MVM_vm_create_instance (src/moar.c:195)

Site cycles: 30547422 (0.5% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 37 | 37.0 | 0.0 | 0.0 |
| insert | 1 | 111 | 111.0 | 0.0 | 0.0 |
| fetch_hit | 15149 | 30546460 | 2016.4 | 0.5 | 0.0 |
| fetch_miss | 1 | 814 | 814.0 | 0.0 | 0.0 |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 15149 | 1 | 30547274 | 100.0 |

- at or above 65 entries: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128 entries: 0.0% of fetches, 0.0% of fetch cycles

- build: <=4=1

### i1 MVM_vm_create_instance (src/moar.c:182)

Site cycles: 12653445 (0.2% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 750767 | 750767.0 | 0.0 | 0.0 |
| insert | 47 | 24346 | 518.0 | 0.0 | 0.0 |
| fetch_hit | 24719 | 11878332 | 480.5 | 0.2 | 0.0 |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=64 | 24719 | 0 | 11878332 | 100.0 |

- at or above 65 entries: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128 entries: 0.0% of fetches, 0.0% of fetch cycles

- build: <=64=1

### f8 MVM_disp_syscall_setup (src/disp/syscall.c:1671)

Site cycles: 12036433 (0.2% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 37 | 37.0 | 0.0 | 0.0 |
| insert | 84 | 38332 | 456.3 | 0.0 | 0.0 |
| fetch_hit | 23083 | 11998064 | 519.8 | 0.2 | 0.0 |
| grow | 5 | 4810 | 962.0 | (in insert) | (in insert) |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=128 | 23083 | 0 | 11998064 | 100.0 |

- at or above 65 entries: 100.0% of fetches, 100.0% of fetch cycles
- at or above 128 entries: 100.0% of fetches, 100.0% of fetch cycles

- build: <=4=1

### f1 MVM_vm_create_instance (src/moar.c:186)

Site cycles: 11065889 (0.2% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 999 | 999.0 | 0.0 | 0.0 |
| insert | 2 | 629 | 314.5 | 0.0 | 0.0 |
| overwrite | 35236 | 11064261 | 314.0 | 0.2 | 0.0 |

- build: <=4=1

### f3 MVM_vm_create_instance (src/moar.c:191)

Site cycles: 5683052 (0.1% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 37 | 37.0 | 0.0 | 0.0 |
| insert | 1 | 296 | 296.0 | 0.0 | 0.0 |
| fetch_hit | 15150 | 5682312 | 375.1 | 0.1 | 0.0 |
| fetch_miss | 1 | 407 | 407.0 | 0.0 | 0.0 |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 15150 | 1 | 5682719 | 100.0 |

- at or above 65 entries: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128 entries: 0.0% of fetches, 0.0% of fetch cycles

- build: <=4=1

### u4 MVM_unicode_init (src/strings/unicode_ops.c:967)

Site cycles: 1318678 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 115 | 754060 | 6557.0 | 0.0 | 0.0 |
| insert | 5058 | 532132 | 105.2 | 0.0 | 0.0 |
| overwrite | 266 | 32486 | 122.1 | 0.0 | 0.0 |
| grow | 1 | 592 | 592.0 | (in insert) | (in insert) |

- build: <=4=7 <=16=90 <=32=2 <=64=6 <=128=3 <=256=4 <=1024=2 <=16384=1

### u1 generate_property_codes_by_names_aliases (src/strings/unicode_ops.c:915)

Site cycles: 493751 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 8140 | 8140.0 | 0.0 | 0.0 |
| insert | 4380 | 484982 | 110.7 | 0.0 | 0.0 |
| fetch_hit | 2 | 629 | 314.5 | 0.0 | 0.0 |
| grow | 1 | 777 | 777.0 | (in insert) | (in insert) |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=16384 | 2 | 0 | 629 | 100.0 |

- at or above 65 entries: 100.0% of fetches, 100.0% of fetch cycles
- at or above 128 entries: 100.0% of fetches, 100.0% of fetch cycles

- build: <=16384=1

### f6 MVM_vm_create_instance (src/moar.c:207)

Site cycles: 64159 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 1 | 1.0 | 0.0 | 0.0 |
| insert | 29 | 14578 | 502.7 | 0.0 | 0.0 |
| fetch_hit | 7 | 16687 | 2383.9 | 0.0 | 0.0 |
| fetch_miss | 29 | 32893 | 1134.2 | 0.0 | 0.0 |
| grow | 3 | 7252 | 2417.3 | (in insert) | (in insert) |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 0 | 5 | 5032 | 10.1 |
| <=16 | 0 | 12 | 12987 | 26.2 |
| <=32 | 7 | 12 | 31561 | 63.7 |

- at or above 65 entries: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128 entries: 0.0% of fetches, 0.0% of fetch cycles

- build: <=4=1

### f7 MVM_vm_create_instance (src/moar.c:210)

Site cycles: 10027 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 37 | 37.0 | 0.0 | 0.0 |
| insert | 3 | 1221 | 407.0 | 0.0 | 0.0 |
| fetch_hit | 32 | 8769 | 274.0 | 0.0 | 0.0 |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 32 | 0 | 8769 | 100.0 |

- at or above 65 entries: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128 entries: 0.0% of fetches, 0.0% of fetch cycles

- build: <=4=1

### f5 MVM_vm_create_instance (src/moar.c:199)

Site cycles: 8400 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1 | 1 | 1.0 | 0.0 | 0.0 |
| insert | 10 | 1813 | 181.3 | 0.0 | 0.0 |
| fetch_hit | 3 | 4810 | 1603.3 | 0.0 | 0.0 |
| fetch_miss | 10 | 1776 | 177.6 | 0.0 | 0.0 |
| grow | 1 | 851 | 851.0 | (in insert) | (in insert) |

Lookups by table size (the table's entries at the fetch):

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 0 | 5 | 1036 | 15.7 |
| <=16 | 3 | 5 | 5550 | 84.3 |

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
| rakudo.moarvm | 1 | 0 | 148053138401 | 5838916818 | 3.9 |
