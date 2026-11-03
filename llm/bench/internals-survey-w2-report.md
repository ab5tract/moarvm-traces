# Hash statistics

Files: 78 (0 header-only)
Hash cycles: 26558985531 of 915622944923 (2.9%)

## Sites

### s5 MVMHash_bind_key (src/6model/reprs/MVMHash.c:115)

Site cycles: 21709894200 (81.7% of hash, 2.4% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 7641481 | 434677011 | 56.9 | 1.6 | 0.0 |
| insert | 17569729 | 7155699735 | 407.3 | 26.9 | 0.8 |
| overwrite | 1699945 | 151085738 | 88.9 | 0.6 | 0.0 |
| fetch_hit | 123319024 | 11963436132 | 97.0 | 45.0 | 1.3 |
| fetch_miss | 21974890 | 1903014041 | 86.6 | 7.2 | 0.2 |
| delete_hit | 916531 | 97527974 | 106.4 | 0.4 | 0.0 |
| delete_miss | 5043 | 4453569 | 883.1 | 0.0 | 0.0 |
| iter_start | 14936701 | 0 | 0.0 | 0.0 | 0.0 |
| iter_step | 91335808 | 0 | 0.0 | 0.0 | 0.0 |
| copy | 345393 | 0 | 0.0 | 0.0 | 0.0 |
| grow | 187747 | 919154067 | 4895.7 | (in insert) | (in insert) |
| migrate | 10579 | 74670319 | 7058.4 | (in insert) | (in insert) |
| demolish | 5621858 | 0 | 0.0 | 0.0 | 0.0 |

- build: <=4=7641481
- demolish set 0 rung 0: <=4=5183080 <=16=371249 <=32=50781 <=64=6271
- demolish set 0 rung 1: <=65=101 <=128=3250 <=256=4720 <=1024=2377 <=16384=29

### i2 MVM_bytecode_finish_frame (src/core/bytecode.c:667)

Site cycles: 3729525621 (14.0% of hash, 0.4% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 4713 | 1224959 | 259.9 | 0.0 | 0.0 |
| insert | 73908 | 17367103 | 235.0 | 0.1 | 0.0 |
| fetch_hit | 39346740 | 2220869989 | 56.4 | 8.4 | 0.2 |
| fetch_miss | 23461133 | 1490063570 | 63.5 | 5.6 | 0.2 |
| grow | 8 | 1406 | 175.8 | (in insert) | (in insert) |

- build: <=16=3847 <=32=563 <=64=48 <=128=242 <=256=5 <=1024=8

### other

Site cycles: 468729616 (1.8% of hash, 0.1% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| fetch_miss | 12141794 | 468594675 | 38.6 | 1.8 | 0.1 |
| delete_miss | 1581 | 134941 | 85.4 | 0.0 | 0.0 |
| iter_start | 769132 | 0 | 0.0 | 0.0 | 0.0 |

### s6 deserialize (src/6model/reprs/MVMHash.c:192)

Site cycles: 203599346 (0.8% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 163 | 107226 | 657.8 | 0.0 | 0.0 |
| insert | 4608 | 1167833 | 253.4 | 0.0 | 0.0 |
| overwrite | 242 | 67895 | 280.6 | 0.0 | 0.0 |
| fetch_hit | 519060 | 88565254 | 170.6 | 0.3 | 0.0 |
| fetch_miss | 1330078 | 113691138 | 85.5 | 0.4 | 0.0 |
| iter_start | 525 | 0 | 0.0 | 0.0 | 0.0 |
| iter_step | 21001 | 0 | 0.0 | 0.0 | 0.0 |

- build: <=4=64 <=16=70 <=32=11 <=64=3 <=256=15

### u4 MVM_unicode_init (src/strings/unicode_ops.c:959)

Site cycles: 119148250 (0.4% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 8970 | 350548 | 39.1 | 0.0 | 0.0 |
| insert | 394524 | 116507257 | 295.3 | 0.4 | 0.0 |
| overwrite | 20748 | 2122502 | 102.3 | 0.0 | 0.0 |
| fetch_hit | 524 | 167943 | 320.5 | 0.0 | 0.0 |
| grow | 11232 | 71773449 | 6390.1 | (in insert) | (in insert) |

- build: <=4=8970

### f4 MVM_vm_create_instance (src/moar.c:195)

Site cycles: 109899261 (0.4% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 78 | 2490 | 31.9 | 0.0 | 0.0 |
| insert | 4 | 333 | 83.2 | 0.0 | 0.0 |
| fetch_hit | 62227 | 109891665 | 1766.0 | 0.4 | 0.0 |
| fetch_miss | 4 | 4773 | 1193.2 | 0.0 | 0.0 |

- build: <=4=78

### i1 MVM_vm_create_instance (src/moar.c:182)

Site cycles: 75260960 (0.3% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 78 | 51982743 | 666445.4 | 0.2 | 0.0 |
| insert | 3666 | 1918413 | 523.3 | 0.0 | 0.0 |
| fetch_hit | 42477 | 21359804 | 502.9 | 0.1 | 0.0 |
| grow | 4 | 777 | 194.2 | (in insert) | (in insert) |

- build: <=64=78

### p1 MVM_gc_object_id (src/gc/objectid.c:28)

Site cycles: 73556175 (0.3% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 53 | 6216 | 117.3 | 0.0 | 0.0 |
| insert | 217735 | 30912441 | 142.0 | 0.1 | 0.0 |
| fetch_hit | 357044 | 34261305 | 96.0 | 0.1 | 0.0 |
| delete_hit | 216729 | 8376213 | 38.6 | 0.0 | 0.0 |
| grow | 93 | 488992 | 5258.0 | (in insert) | (in insert) |

- build: <=4=53

### f8 MVM_disp_syscall_setup (src/disp/syscall.c:1671)

Site cycles: 26360474 (0.1% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 78 | 3483 | 44.7 | 0.0 | 0.0 |
| insert | 6552 | 3215267 | 490.7 | 0.0 | 0.0 |
| fetch_hit | 41662 | 23141724 | 555.5 | 0.1 | 0.0 |
| grow | 330 | 401598 | 1217.0 | (in insert) | (in insert) |

- build: <=4=78

### f3 MVM_vm_create_instance (src/moar.c:191)

Site cycles: 18160268 (0.1% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 78 | 2346 | 30.1 | 0.0 | 0.0 |
| insert | 4 | 1369 | 342.2 | 0.0 | 0.0 |
| fetch_hit | 62231 | 18154518 | 291.7 | 0.1 | 0.0 |
| fetch_miss | 4 | 2035 | 508.8 | 0.0 | 0.0 |

- build: <=4=78

### s1 MVM_vm_create_instance (src/moar.c:203)

Site cycles: 12363068 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 78 | 17131 | 219.6 | 0.0 | 0.0 |
| insert | 1082 | 834239 | 771.0 | 0.0 | 0.0 |
| overwrite | 7599 | 8743359 | 1150.6 | 0.0 | 0.0 |
| fetch_hit | 5003 | 2768339 | 553.3 | 0.0 | 0.0 |
| iter_start | 1733 | 0 | 0.0 | 0.0 | 0.0 |
| iter_step | 40785 | 0 | 0.0 | 0.0 | 0.0 |
| grow | 84 | 27676 | 329.5 | (in insert) | (in insert) |

- build: <=4=78

### f1 MVM_vm_create_instance (src/moar.c:186)

Site cycles: 8854151 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 78 | 53280 | 683.1 | 0.0 | 0.0 |
| insert | 88 | 34669 | 394.0 | 0.0 | 0.0 |
| overwrite | 56800 | 8766202 | 154.3 | 0.0 | 0.0 |

- build: <=4=78

### u1 generate_property_codes_by_names_aliases (src/strings/unicode_ops.c:915)

Site cycles: 2171052 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 3 | 714211 | 238070.3 | 0.0 | 0.0 |
| insert | 13140 | 1330115 | 101.2 | 0.0 | 0.0 |
| fetch_hit | 534 | 126726 | 237.3 | 0.0 | 0.0 |
| grow | 3 | 2035 | 678.3 | (in insert) | (in insert) |

- build: <=16384=3

### f6 MVM_vm_create_instance (src/moar.c:207)

Site cycles: 1280097 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 78 | 2635 | 33.8 | 0.0 | 0.0 |
| insert | 873 | 315240 | 361.1 | 0.0 | 0.0 |
| fetch_hit | 4 | 9879 | 2469.8 | 0.0 | 0.0 |
| fetch_miss | 873 | 952343 | 1090.9 | 0.0 | 0.0 |
| grow | 89 | 124024 | 1393.5 | (in insert) | (in insert) |

- build: <=4=78

### f7 MVM_vm_create_instance (src/moar.c:210)

Site cycles: 144862 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 78 | 2856 | 36.6 | 0.0 | 0.0 |
| insert | 234 | 97347 | 416.0 | 0.0 | 0.0 |
| fetch_hit | 102 | 44659 | 437.8 | 0.0 | 0.0 |

- build: <=4=78

### f5 MVM_vm_create_instance (src/moar.c:199)

Site cycles: 35531 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 78 | 3453 | 44.3 | 0.0 | 0.0 |
| insert | 40 | 7917 | 197.9 | 0.0 | 0.0 |
| fetch_hit | 9 | 16095 | 1788.3 | 0.0 | 0.0 |
| fetch_miss | 40 | 8066 | 201.7 | 0.0 | 0.0 |
| grow | 4 | 3552 | 888.0 | (in insert) | (in insert) |

- build: <=4=78

### f2 MVM_vm_create_instance (src/moar.c:187)

Site cycles: 2599 (0.0% of hash, 0.0% of total)

| op | count | cycles | cycles/op | % of hash | % of total |
|---|---|---|---|---|---|
| build | 78 | 2599 | 33.3 | 0.0 | 0.0 |

- build: <=4=78

## Census sites not seen

i3 p2 s2 s3 s4 s7 s8 s9 u2 u3

## Hash share

| program | files | header-only | total cycles | hash cycles | % |
|---|---|---|---|---|---|
| --output=rakudo-debug.moarvm | 1 | 0 | 695390025 | 31252435 | 4.5 |
| --output=rakudo.moarvm | 1 | 0 | 278373163 | 14467487 | 5.2 |
| Actions.moarvm | 2 | 0 | 21721522549 | 707075827 | 3.3 |
| Compiler.moarvm | 1 | 0 | 497997356 | 20544237 | 4.1 |
| Grammar.moarvm | 2 | 0 | 24113263673 | 993457432 | 4.1 |
| Metamodel.moarvm | 1 | 0 | 6304059075 | 188348904 | 3.0 |
| ModuleLoader.moarvm | 1 | 0 | 394962864 | 18173624 | 4.6 |
| Ops.moarvm | 1 | 0 | 660688058 | 27211551 | 4.1 |
| Optimizer.moarvm | 1 | 0 | 7607142391 | 148775996 | 2.0 |
| Pod.moarvm | 1 | 0 | 2859328032 | 115745565 | 4.0 |
| SysConfig.moarvm | 1 | 0 | 198952071 | 10204192 | 5.1 |
| World.moarvm | 1 | 0 | 7385843615 | 200468338 | 2.7 |
| nqp | 46 | 0 | 56390559919 | 3186934304 | 5.7 |
| nqp -e | 12 | 0 | 860338282 | 77596409 | 9.0 |
| rakudo.moarvm | 3 | 0 | 371700287788 | 16098154403 | 4.3 |
| v6c.moarvm | 1 | 0 | 413790430032 | 4707252581 | 1.1 |
| v6d.moarvm | 1 | 0 | 81504377 | 5910705 | 7.3 |
| v6e.moarvm | 1 | 0 | 82301653 | 7411541 | 9.0 |
