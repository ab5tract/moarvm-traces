files 1365: sum of per-file wall deltas 74278 ms (base sum of walls 5120374 ms)
sum |base1-base2| 268023 ms, sum |head1-head2| 259902 ms

Top 20 by wall delta (mean of 2 runs per side)
| file | base ms | head ms | delta ms | ratio | base spread ms | head spread ms |
|---|---:|---:|---:|---:|---:|---:|
| t/spec/S32-str/sprintf-f.t | 74634 | 83770 | +9136 | 1.12 | 195 | 653 |
| t/spec/S32-str/sprintf-b.t | 94734 | 103551 | +8816 | 1.09 | 2123 | 1740 |
| t/spec/S32-str/sprintf-x.t | 96192 | 104037 | +7845 | 1.08 | 1960 | 126 |
| t/spec/S32-str/sprintf-e.t | 62944 | 67734 | +4790 | 1.08 | 814 | 1654 |
| t/spec/S17-supply/batch.t | 39172 | 42657 | +3486 | 1.09 | 1127 | 478 |
| t/spec/S32-str/sprintf-a.t | 38340 | 41446 | +3106 | 1.08 | 841 | 1220 |
| t/spec/S32-str/sprintf-c.t | 23334 | 25224 | +1890 | 1.08 | 1175 | 336 |
| t/spec/S06-operator-overloading/infix.rakudo.moar | 49836 | 51475 | +1640 | 1.03 | 2443 | 1008 |
| t/spec/6.c/APPENDICES/A03-older-specs/01-misc.rakudo.moar | 18864 | 20358 | +1494 | 1.08 | 171 | 223 |
| t/spec/S32-str/sprintf-u.t | 17216 | 18624 | +1408 | 1.08 | 467 | 434 |
| t/spec/S32-str/val.t | 17365 | 18752 | +1386 | 1.08 | 704 | 487 |
| t/spec/S32-exceptions/misc.rakudo.moar | 35589 | 36846 | +1257 | 1.04 | 512 | 1192 |
| t/spec/S10-packages/precompilation.t | 80444 | 81670 | +1226 | 1.02 | 12 | 415 |
| t/spec/S03-metaops/hyper.rakudo.moar | 23146 | 24364 | +1218 | 1.05 | 100 | 1184 |
| t/spec/S17-procasync/no-runaway-file-limit.t | 39852 | 41011 | +1160 | 1.03 | 1919 | 74 |
| t/spec/S03-junctions/misc.t | 14190 | 15334 | +1144 | 1.08 | 543 | 472 |
| t/spec/S04-declarations/my-6e.rakudo.moar | 5656 | 6746 | +1090 | 1.19 | 96 | 1810 |
| t/spec/6.c/MISC/bug-coverage.t | 16346 | 17388 | +1042 | 1.06 | 940 | 437 |
| t/spec/S32-str/sprintf-d.t | 49540 | 50552 | +1012 | 1.02 | 227 | 516 |
| t/spec/S04-exception-handlers/catch.t | 17666 | 18661 | +996 | 1.06 | 373 | 238 |
sum of top-20 deltas 55140 ms of total 74278

Top 20 by ratio (base >= 500 ms)
| file | base ms | head ms | delta ms | ratio | base spread ms | head spread ms |
|---|---:|---:|---:|---:|---:|---:|
| t/spec/S07-iterationbuffer/iterationbuffer.t | 1130 | 1500 | +370 | 1.33 | 29 | 251 |
| t/spec/S02-lexical-conventions/unicode-whitespace.t | 2706 | 3546 | +840 | 1.31 | 193 | 269 |
| t/spec/S03-operators/orelse.t | 1168 | 1525 | +358 | 1.31 | 97 | 450 |
| t/spec/S32-str/tclc.t | 710 | 924 | +215 | 1.30 | 69 | 167 |
| t/spec/S32-str/lc.t | 1082 | 1398 | +316 | 1.29 | 88 | 56 |
| t/spec/S02-magicals/GROUP.t | 1097 | 1410 | +313 | 1.29 | 346 | 174 |
| t/spec/S14-roles/composition.t | 3362 | 4292 | +930 | 1.28 | 280 | 32 |
| t/spec/S03-smartmatch/array-hash.t | 950 | 1208 | +258 | 1.27 | 14 | 36 |
| t/spec/S03-smartmatch/00-sanity.t | 1744 | 2216 | +472 | 1.27 | 348 | 185 |
| t/spec/S12-meta/primitives.t | 1580 | 1954 | +374 | 1.24 | 105 | 116 |
| t/spec/S12-methods/chaining.t | 1216 | 1490 | +275 | 1.23 | 135 | 35 |
| t/spec/S03-metaops/eager-hyper.t | 1182 | 1450 | +268 | 1.23 | 309 | 158 |
| t/spec/S04-statements/quietly.t | 2760 | 3358 | +598 | 1.22 | 552 | 75 |
| t/spec/S03-operators/spaceship-and-containers.t | 1038 | 1255 | +216 | 1.21 | 265 | 154 |
| t/spec/S02-types/hyperwhatever.t | 997 | 1196 | +200 | 1.20 | 0 | 87 |
| t/spec/S04-phasers/init.t | 1144 | 1371 | +226 | 1.20 | 193 | 106 |
| t/spec/S02-literals/listquote.rakudo.moar | 1574 | 1877 | +304 | 1.19 | 67 | 358 |
| t/spec/S04-declarations/my-6e.rakudo.moar | 5656 | 6746 | +1090 | 1.19 | 96 | 1810 |
| t/spec/integration/advent2013-day20.t | 1352 | 1612 | +260 | 1.19 | 25 | 141 |
| t/spec/S09-subscript/multidim-assignment.t | 1463 | 1744 | +281 | 1.19 | 104 | 262 |
sum of top-20 ratio deltas 8164 ms


positive deltas sum 152792, negative -78514, files slower 739
