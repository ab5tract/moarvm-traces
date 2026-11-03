# Hash statistics

Files: 2 (0 header-only)
Hash cycles: 1832020624 of 16577989638 (11.1%)

## Sites

### u1 generate_property_codes_by_names_aliases (src/strings/unicode_ops.c:915)

Site cycles: 700184591 (38.2% of hash, 4.2% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2 | 38221 | 19110.5 | 0.0 | 0.0 |
| insert | 8760 | 1004600 | 114.7 | 0.1 | 0.0 |
| fetch_hit | 7470024 | 508913601 | 68.1 | 27.8 | 3.1 |
| fetch_miss | 3355080 | 190228169 | 56.7 | 10.4 | 1.1 |
| grow | 2 | 3478 | 1739.0 | (in insert) | (in insert) |

- build: <=16384=2

### u3 generate_codepoints_by_name (src/strings/unicode_db.c:129559)

Site cycles: 625297867 (34.1% of hash, 3.8% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2 | 185 | 92.5 | 0.0 | 0.0 |
| insert | 103742 | 31892208 | 307.4 | 1.7 | 0.2 |
| fetch_hit | 3148910 | 319994504 | 101.6 | 17.5 | 1.9 |
| fetch_miss | 4250322 | 273410970 | 64.3 | 14.9 | 1.6 |
| grow | 48 | 18976079 | 395335.0 | (in insert) | (in insert) |

- build: <=4=2

### u4 MVM_unicode_init (src/strings/unicode_ops.c:959)

Site cycles: 397851409 (21.7% of hash, 2.4% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 230 | 9086 | 39.5 | 0.0 | 0.0 |
| insert | 10116 | 2760491 | 272.9 | 0.2 | 0.0 |
| overwrite | 532 | 52170 | 98.1 | 0.0 | 0.0 |
| fetch_hit | 3143680 | 231792211 | 73.7 | 12.7 | 1.4 |
| fetch_miss | 3143680 | 163237451 | 51.9 | 8.9 | 1.0 |
| grow | 288 | 1626032 | 5645.9 | (in insert) | (in insert) |

- build: <=4=230

### s5 MVMHash_bind_key (src/6model/reprs/MVMHash.c:115)

Site cycles: 55531643 (3.0% of hash, 0.3% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 45478 | 2221097 | 48.8 | 0.1 | 0.0 |
| insert | 92924 | 20270607 | 218.1 | 1.1 | 0.1 |
| overwrite | 1028 | 70402 | 68.5 | 0.0 | 0.0 |
| fetch_hit | 381901 | 27598768 | 72.3 | 1.5 | 0.2 |
| fetch_miss | 85365 | 5077184 | 59.5 | 0.3 | 0.0 |
| delete_hit | 3818 | 293585 | 76.9 | 0.0 | 0.0 |
| iter_start | 10066 | 0 | 0.0 | 0.0 | 0.0 |
| iter_step | 24975 | 0 | 0.0 | 0.0 | 0.0 |
| copy | 20 | 0 | 0.0 | 0.0 | 0.0 |
| grow | 641 | 1339657 | 2089.9 | (in insert) | (in insert) |
| migrate | 42 | 171532 | 4084.1 | (in insert) | (in insert) |
| demolish | 44894 | 0 | 0.0 | 0.0 | 0.0 |

- build: <=4=45478
- demolish set 0 rung 0: <=4=44257 <=16=589 <=32=24 <=64=14
- demolish set 0 rung 1: <=128=8 <=256=2

### u2 generate_property_codes_by_seq_names (src/strings/unicode_ops.c:930)

Site cycles: 39381960 (2.1% of hash, 0.2% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2 | 9361 | 4680.5 | 0.0 | 0.0 |
| insert | 7360 | 622673 | 84.6 | 0.0 | 0.0 |
| fetch_hit | 334546 | 38749926 | 115.8 | 2.1 | 0.2 |

- build: <=16384=2

### i2 MVM_bytecode_finish_frame (src/core/bytecode.c:667)

Site cycles: 10000342 (0.5% of hash, 0.1% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 80 | 18278 | 228.5 | 0.0 | 0.0 |
| insert | 1130 | 270690 | 239.5 | 0.0 | 0.0 |
| fetch_hit | 78739 | 6242533 | 79.3 | 0.3 | 0.0 |
| fetch_miss | 55121 | 3468841 | 62.9 | 0.2 | 0.0 |

- build: <=16=62 <=32=14 <=128=4

### other

Site cycles: 1458463 (0.1% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| fetch_miss | 39417 | 1458463 | 37.0 | 0.1 | 0.0 |
| iter_start | 766 | 0 | 0.0 | 0.0 | 0.0 |

### i1 MVM_vm_create_instance (src/moar.c:182)

Site cycles: 1430753 (0.1% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2 | 1125540 | 562770.0 | 0.1 | 0.0 |
| insert | 94 | 50542 | 537.7 | 0.0 | 0.0 |
| fetch_hit | 550 | 254671 | 463.0 | 0.0 | 0.0 |

- build: <=64=2

### f8 MVM_disp_syscall_setup (src/disp/syscall.c:1671)

Site cycles: 652237 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2 | 38 | 19.0 | 0.0 | 0.0 |
| insert | 168 | 79439 | 472.9 | 0.0 | 0.0 |
| fetch_hit | 1020 | 572760 | 561.5 | 0.0 | 0.0 |
| grow | 9 | 9805 | 1089.4 | (in insert) | (in insert) |

- build: <=4=2

### s1 MVM_vm_create_instance (src/moar.c:203)

Site cycles: 139564 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2 | 555 | 277.5 | 0.0 | 0.0 |
| insert | 26 | 19462 | 748.5 | 0.0 | 0.0 |
| overwrite | 76 | 61531 | 809.6 | 0.0 | 0.0 |
| fetch_hit | 102 | 58016 | 568.8 | 0.0 | 0.0 |
| iter_start | 8 | 0 | 0.0 | 0.0 | 0.0 |
| iter_step | 104 | 0 | 0.0 | 0.0 | 0.0 |
| grow | 2 | 555 | 277.5 | (in insert) | (in insert) |

- build: <=4=2

### f1 MVM_vm_create_instance (src/moar.c:186)

Site cycles: 47286 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2 | 1295 | 647.5 | 0.0 | 0.0 |
| insert | 2 | 962 | 481.0 | 0.0 | 0.0 |
| overwrite | 276 | 45029 | 163.1 | 0.0 | 0.0 |

- build: <=4=2

### f6 MVM_vm_create_instance (src/moar.c:207)

Site cycles: 28194 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2 | 74 | 37.0 | 0.0 | 0.0 |
| insert | 20 | 5994 | 299.7 | 0.0 | 0.0 |
| fetch_miss | 20 | 22126 | 1106.3 | 0.0 | 0.0 |
| grow | 2 | 1850 | 925.0 | (in insert) | (in insert) |

- build: <=4=2

### p1 MVM_gc_object_id (src/gc/objectid.c:28)

Site cycles: 8063 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2 | 148 | 74.0 | 0.0 | 0.0 |
| insert | 10 | 5142 | 514.2 | 0.0 | 0.0 |
| fetch_hit | 12 | 2146 | 178.8 | 0.0 | 0.0 |
| delete_hit | 10 | 627 | 62.7 | 0.0 | 0.0 |

- build: <=4=2

### s6 deserialize (src/6model/reprs/MVMHash.c:192)

Site cycles: 5587 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2 | 555 | 277.5 | 0.0 | 0.0 |
| insert | 6 | 2220 | 370.0 | 0.0 | 0.0 |
| fetch_hit | 12 | 2812 | 234.3 | 0.0 | 0.0 |

- build: <=4=2

### f7 MVM_vm_create_instance (src/moar.c:210)

Site cycles: 2405 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2 | 74 | 37.0 | 0.0 | 0.0 |
| insert | 6 | 2331 | 388.5 | 0.0 | 0.0 |

- build: <=4=2

### f2 MVM_vm_create_instance (src/moar.c:187)

Site cycles: 74 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2 | 74 | 37.0 | 0.0 | 0.0 |

- build: <=4=2

### f3 MVM_vm_create_instance (src/moar.c:191)

Site cycles: 74 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2 | 74 | 37.0 | 0.0 | 0.0 |

- build: <=4=2

### f4 MVM_vm_create_instance (src/moar.c:195)

Site cycles: 74 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2 | 74 | 37.0 | 0.0 | 0.0 |

- build: <=4=2

### f5 MVM_vm_create_instance (src/moar.c:199)

Site cycles: 38 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2 | 38 | 19.0 | 0.0 | 0.0 |

- build: <=4=2

## Census sites not seen

i3 p2 s2 s3 s4 s7 s8 s9

## Hash share

| program | files | header-only | total cycles | hash cycles | % |
|---|---|---|---|---|---|
| nqp-m | 2 | 0 | 16577989638 | 1832020624 | 11.1 |
