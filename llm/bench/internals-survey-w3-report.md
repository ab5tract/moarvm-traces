# Hash statistics

Files: 2624 (0 header-only)
Hash cycles: 1351679316876 of 31070970000964 (4.4%)

## Sites

### s5 MVMHash_bind_key (src/6model/reprs/MVMHash.c:115)

Site cycles: 1098598605529 (81.3% of hash, 3.5% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 39905612 | 13286959238 | 333.0 | 1.0 | 0.0 |
| insert | 402540319 | 801701897701 | 1991.6 | 59.3 | 2.6 |
| overwrite | 10396822 | 4091793351 | 393.6 | 0.3 | 0.0 |
| fetch_hit | 651152334 | 215348503155 | 330.7 | 15.9 | 0.7 |
| fetch_miss | 289147598 | 63339902319 | 219.1 | 4.7 | 0.2 |
| delete_hit | 1751101 | 702721548 | 401.3 | 0.1 | 0.0 |
| delete_miss | 474272 | 126828217 | 267.4 | 0.0 | 0.0 |
| iter_start | 39843137 | 0 | 0.0 | 0.0 | 0.0 |
| iter_step | 549789745 | 0 | 0.0 | 0.0 | 0.0 |
| copy | 18135480 | 0 | 0.0 | 0.0 | 0.0 |
| grow | 16668126 | 443038660885 | 26580.0 | (in insert) | (in insert) |
| migrate | 979329 | 93394885200 | 95366.2 | (in insert) | (in insert) |
| demolish | 39334243 | 0 | 0.0 | 0.0 | 0.0 |

- build: <=4=39905612
- demolish set 0 rung 0: <=4=21616652 <=16=17165683 <=32=360704 <=64=102193
- demolish set 0 rung 1: <=65=213 <=128=80532 <=256=4686 <=1024=3574 <=16384=6

### i2 MVM_bytecode_finish_frame (src/core/bytecode.c:667)

Site cycles: 89111833715 (6.6% of hash, 0.3% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 1610755 | 8010104211 | 4972.9 | 0.6 | 0.0 |
| insert | 19461880 | 9130198210 | 469.1 | 0.7 | 0.0 |
| fetch_hit | 273835246 | 52742686012 | 192.6 | 3.9 | 0.2 |
| fetch_miss | 122964791 | 19228845282 | 156.4 | 1.4 | 0.1 |
| grow | 1043 | 849927 | 814.9 | (in insert) | (in insert) |
| demolish | 52814 | 0 | 0.0 | 0.0 | 0.0 |

- build: <=16=1477426 <=32=88179 <=64=22506 <=65=7 <=128=17405 <=256=2616 <=1024=2615 <=16384=1
- demolish set 0 rung 0: <=16=52814

### i1 MVM_vm_create_instance (src/moar.c:182)

Site cycles: 49040371428 (3.6% of hash, 0.2% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2624 | 38487994664 | 14667680.9 | 2.8 | 0.1 |
| insert | 123328 | 98146200 | 795.8 | 0.0 | 0.0 |
| fetch_hit | 13967352 | 10454230564 | 748.5 | 0.8 | 0.0 |
| grow | 200 | 162652 | 813.3 | (in insert) | (in insert) |

- build: <=64=2624

### u4 MVM_unicode_init (src/strings/unicode_ops.c:959)

Site cycles: 48006249475 (3.6% of hash, 0.2% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 301760 | 27377631 | 90.7 | 0.0 | 0.0 |
| insert | 13272192 | 47834513354 | 3604.1 | 3.5 | 0.2 |
| overwrite | 697984 | 134067088 | 192.1 | 0.0 | 0.0 |
| fetch_hit | 9644 | 10262764 | 1064.2 | 0.0 | 0.0 |
| fetch_miss | 66 | 28638 | 433.9 | 0.0 | 0.0 |
| grow | 377856 | 45190334649 | 119596.7 | (in insert) | (in insert) |

- build: <=4=301760

### u1 generate_property_codes_by_names_aliases (src/strings/unicode_ops.c:915)

Site cycles: 15360018264 (1.1% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2615 | 13146204303 | 5027229.2 | 1.0 | 0.0 |
| insert | 11453700 | 2188008310 | 191.0 | 0.2 | 0.0 |
| fetch_hit | 15355 | 25794033 | 1679.8 | 0.0 | 0.0 |
| fetch_miss | 20 | 11618 | 580.9 | 0.0 | 0.0 |
| grow | 2615 | 4216705 | 1612.5 | (in insert) | (in insert) |

- build: <=16384=2615

### f8 MVM_disp_syscall_setup (src/disp/syscall.c:1671)

Site cycles: 12027636067 (0.9% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2624 | 635881 | 242.3 | 0.0 | 0.0 |
| insert | 220416 | 181108306 | 821.7 | 0.0 | 0.0 |
| fetch_hit | 8513316 | 11845891880 | 1391.5 | 0.9 | 0.0 |
| grow | 11056 | 72889519 | 6592.8 | (in insert) | (in insert) |

- build: <=4=2624

### other

Site cycles: 9822683785 (0.7% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| fetch_miss | 78835388 | 9822566752 | 124.6 | 0.7 | 0.0 |
| delete_miss | 840 | 117033 | 139.3 | 0.0 | 0.0 |
| iter_start | 5991312 | 0 | 0.0 | 0.0 | 0.0 |

### p1 MVM_gc_object_id (src/gc/objectid.c:28)

Site cycles: 6922524220 (0.5% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2603 | 1037409 | 398.5 | 0.0 | 0.0 |
| insert | 6452446 | 3769097230 | 584.1 | 0.3 | 0.0 |
| fetch_hit | 11047533 | 1808227106 | 163.7 | 0.1 | 0.0 |
| delete_hit | 5980878 | 1344162475 | 224.7 | 0.1 | 0.0 |
| grow | 17314 | 1123908004 | 64913.2 | (in insert) | (in insert) |

- build: <=4=2603

### f1 MVM_vm_create_instance (src/moar.c:186)

Site cycles: 6631029004 (0.5% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2624 | 60248876 | 22960.7 | 0.0 | 0.0 |
| insert | 5240 | 6309055 | 1204.0 | 0.0 | 0.0 |
| overwrite | 15081309 | 6564471073 | 435.3 | 0.5 | 0.0 |

- build: <=4=2624

### f4 MVM_vm_create_instance (src/moar.c:195)

Site cycles: 4280643834 (0.3% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2624 | 238302 | 90.8 | 0.0 | 0.0 |
| insert | 2624 | 671254 | 255.8 | 0.0 | 0.0 |
| fetch_hit | 1755144 | 4274818680 | 2435.6 | 0.3 | 0.0 |
| fetch_miss | 2624 | 4915598 | 1873.3 | 0.0 | 0.0 |

- build: <=4=2624

### s6 deserialize (src/6model/reprs/MVMHash.c:192)

Site cycles: 4236424532 (0.3% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 57604 | 342086978 | 5938.6 | 0.0 | 0.0 |
| insert | 642960 | 210345542 | 327.2 | 0.0 | 0.0 |
| overwrite | 6497 | 2783510 | 428.4 | 0.0 | 0.0 |
| fetch_hit | 1718867 | 790527394 | 459.9 | 0.1 | 0.0 |
| fetch_miss | 7453880 | 2890681108 | 387.8 | 0.2 | 0.0 |
| iter_start | 11848 | 0 | 0.0 | 0.0 | 0.0 |
| iter_step | 464041 | 0 | 0.0 | 0.0 | 0.0 |
| grow | 108 | 37222 | 344.6 | (in insert) | (in insert) |

- build: <=4=23982 <=16=24335 <=32=5189 <=64=3246 <=256=850 <=16384=2

### s1 MVM_vm_create_instance (src/moar.c:203)

Site cycles: 3682420858 (0.3% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2624 | 446516 | 170.2 | 0.0 | 0.0 |
| insert | 148344 | 400739424 | 2701.4 | 0.0 | 0.0 |
| overwrite | 728301 | 1965050908 | 2698.1 | 0.1 | 0.0 |
| fetch_hit | 648310 | 1253800045 | 1934.0 | 0.1 | 0.0 |
| delete_hit | 52814 | 62383965 | 1181.2 | 0.0 | 0.0 |
| iter_start | 12551 | 0 | 0.0 | 0.0 | 0.0 |
| iter_step | 3267479 | 0 | 0.0 | 0.0 | 0.0 |
| grow | 5845 | 65668414 | 11235.0 | (in insert) | (in insert) |
| migrate | 44 | 1704257 | 38733.1 | (in insert) | (in insert) |

- build: <=4=2624

### u3 generate_codepoints_by_name (src/strings/unicode_db.c:129559)

Site cycles: 2543456581 (0.2% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 36 | 62234 | 1728.7 | 0.0 | 0.0 |
| insert | 1867356 | 2539784812 | 1360.1 | 0.2 | 0.0 |
| fetch_hit | 1836 | 3589407 | 1955.0 | 0.0 | 0.0 |
| fetch_miss | 17 | 20128 | 1184.0 | 0.0 | 0.0 |
| grow | 864 | 2101126807 | 2431859.7 | (in insert) | (in insert) |

- build: <=4=36

### f3 MVM_vm_create_instance (src/moar.c:191)

Site cycles: 757443334 (0.1% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2624 | 133592 | 50.9 | 0.0 | 0.0 |
| insert | 2624 | 2083322 | 793.9 | 0.0 | 0.0 |
| fetch_hit | 1757768 | 751266902 | 427.4 | 0.1 | 0.0 |
| fetch_miss | 2624 | 3959518 | 1509.0 | 0.0 | 0.0 |

- build: <=4=2624

### f6 MVM_vm_create_instance (src/moar.c:207)

Site cycles: 453858632 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2624 | 160450 | 61.1 | 0.0 | 0.0 |
| insert | 70998 | 215609065 | 3036.8 | 0.0 | 0.0 |
| fetch_hit | 12592 | 88593281 | 7035.7 | 0.0 | 0.0 |
| fetch_miss | 70998 | 149495836 | 2105.6 | 0.0 | 0.0 |
| grow | 7909 | 129437692 | 16365.9 | (in insert) | (in insert) |

- build: <=4=2624

### f7 MVM_vm_create_instance (src/moar.c:210)

Site cycles: 104655705 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2624 | 230124 | 87.7 | 0.0 | 0.0 |
| insert | 7872 | 6977534 | 886.4 | 0.0 | 0.0 |
| fetch_hit | 83681 | 97448047 | 1164.5 | 0.0 | 0.0 |

- build: <=4=2624

### f5 MVM_vm_create_instance (src/moar.c:199)

Site cycles: 97775593 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2624 | 217743 | 83.0 | 0.0 | 0.0 |
| insert | 26240 | 9275332 | 353.5 | 0.0 | 0.0 |
| fetch_hit | 7985 | 78875601 | 9878.0 | 0.0 | 0.0 |
| fetch_miss | 26240 | 9406917 | 358.5 | 0.0 | 0.0 |
| grow | 2625 | 4478295 | 1706.0 | (in insert) | (in insert) |

- build: <=4=2624

### u2 generate_property_codes_by_seq_names (src/strings/unicode_ops.c:930)

Site cycles: 1566617 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 4 | 102231 | 25557.8 | 0.0 | 0.0 |
| insert | 14720 | 1449808 | 98.5 | 0.0 | 0.0 |
| fetch_hit | 5 | 9694 | 1938.8 | 0.0 | 0.0 |
| fetch_miss | 12 | 4884 | 407.0 | 0.0 | 0.0 |

- build: <=16384=4

### f2 MVM_vm_create_instance (src/moar.c:187)

Site cycles: 119703 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 2624 | 119703 | 45.6 | 0.0 | 0.0 |

- build: <=4=2624

## Census sites not seen

i3 p2 s2 s3 s4 s7 s8 s9

## Hash share

| program | files | header-only | total cycles | hash cycles | % |
|---|---|---|---|---|---|
| rakudo.moarvm | 2316 | 0 | 30227325385550 | 1296612090226 | 4.3 |
| rakudo.moarvm -e | 308 | 0 | 843644615414 | 55067226650 | 6.5 |
