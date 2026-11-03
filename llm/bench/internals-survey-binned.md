# Internal tables survey, lookups binned by table size (2026-11-03)

Plan Task 5b, added at the stop at the user's request: the survey's s5 and i2 "stay on default"
rulings rested on shares of TABLES by size. This record bins every FETCH by the table's entry count
(`header.cur_items` at the fetch) and carries count and cycles per (site, hit/miss, bucket).

```
Date:        2026-11-03
MoarVM:      zig-hash-internals at ac4436f44 plus the Task 5b change (stats.zig `fetches` histogram and
             `countFetch`, table.zig `fetch` hook, hash-stats.pl, docs/zig-build.md; committed after this record)
traces:      dcd5831 (parent of the "internals: lookups binned by table size" commit)
nqp/rakudo:  tune-zig-prefix's binaries (rakudo checkout configured against it); roast fb1d87214
Build:       stats  rm -f src/gen/config.{h,c,o}; zig build install --prefix /tmp/claude-1000/stats-zig-prefix -Dhash-stats=true
             default build check: zig build; objdump -d zig-out/lib/libmoar.so --disassemble=MVM_str_hash_fetch_nocheck | grep -c rdtsc -> 0
CPU:         AMD Ryzen 9 5900X 12-Core Processor (24 hardware threads)
Load:        W1 start 0.61 (1-minute), W2 start 0.64, W3 start 1.85 (gate: under 2.0)
Workloads:   tune-zig-prefix's raku and nqp against the stats libmoar:
  LD_LIBRARY_PATH=/tmp/claude-1000/stats-zig-prefix/lib MVM_HASH_STATS=<scratch>/b-wN <command>
  W1  50 x raku -e '' (5 s) and 50 x nqp -e '' (1 s): 100 files
  W2  rakudo checkout: make clean; make (244 s): 78 files; then make install with the default lib (16 s)
  W3  .precomp removed, roast fb1d87214, TEST_JOBS=24 make spectest (359 s incl. startup; make's own
      count 349 wallclock secs): Files=1365, Tests=138715, **Result: PASS**; 2624 stats files
Aggregation: tools/bench/hash-stats.pl <dir> --lib=/tmp/claude-1000/stats-zig-prefix/lib/libmoar.so --census
             --tsv=traces/llm/bench/internals-survey-binned-wN.tsv (no warnings)
Raw:         internals-survey-binned-w{1,2,3}.tsv (merged rows incl. `fetch` rows, labels in place of ids)
```

## How to read it

- Bucket = the table's entry count at the fetch: `<=64` is 33-64 entries (the Small rung), `<=65` is
  exactly 65, `<=128` is 66-128, and so on. A table that grows past 64 is binned where it stands at each
  fetch, not where it ends.
- Cycles are counted on the stats build (rdtsc round the fetch, counting cost included, 2-3.5x the
  default's per fetch per the overhead record), so a cycle share is a share of the stats build's fetch
  cycles. Misses and hits carry different per-op overhead, so treat the shares as an upper-resolution
  guide, not a speedup bound. **W3 cycles are contention-inflated (24 jobs on 24 threads, wall-cycle
  counting): the W3 cycle shares are shares within W3 only; W3's counts are usable across workloads.**
- Per bucket the hit count, miss count, cycles (hit + miss) and the share of the site's fetch cycles.
  The bucket sums equal the site's `fetch_hit` / `fetch_miss` op rows exactly (checked on the merged
  rows of every site and workload). Shares of a table sum to 100 within rounding.
- `other` is site 255: fetches on never-built (null) handles, all in bucket `<=4`.

## The two conclusions the stop needs

Shares of LOOKUPS (not of tables) on tables above 64 entries (buckets `<=65` and up) and above 128:

| site | workload | fetches | fetch cycles | >64: share of fetches | >64: share of fetch cycles | >128: fetches | >128: cycles |
|---|---|---|---|---|---|---|---|
| s5 | W1 | 2,726,050 | 231,636,877 | 16.2% | 23.8% | 11.9% | 19.6% |
| s5 | W2 | 145,359,131 | 11,462,229,507 | 47.4% | 53.6% | 47.3% | 53.5% |
| s5 | W3 | 940,396,828 | 267,074,712,252 | 26.8% | 35.1% | 23.9% | 33.2% |
| i2 | W1 | 1,141,950 | 70,768,137 | 13.1% | 33.1% | 13.1% | 33.1% |
| i2 | W2 | 58,562,640 | 2,980,117,821 | 0.8% | 1.9% | 0.8% | 1.9% |
| i2 | W3 | 403,504,854 | 68,331,432,221 | 6.6% | 27.9% | 6.6% | 27.9% |

**s5:** tables above 64 entries are a small minority of s5's builds (0.14-4.1 percent migrate past Small)
but they take 16-47 percent of its lookups and 24-54 percent of its lookup cycles (W3: 27 and 35
percent), so the table-share reading understated the big tables' weight by one to two orders of magnitude
(0.14 percent of builds against 47 percent of W2's fetches). The hit share of the fetches above 64 is 97.0 percent in W2, 76.2 in W3 and 45.1 in W1 (W1's are mostly misses). Whether
that overturns "stay on default" is the user's ruling at the stop; what it shows is that a layout that
wins at 65 and up (Swiss, 0.88-0.99 on hits) acts on up to about half of s5's fetch cycles, while a
per-table choice is available only at the build call (hint 0 for s5, so size is unknown there) with
no mid-life switch.

**i2:** above 64 entries, i2 takes 0.8-13.1 percent of its lookups but 1.9-33.1 percent of its lookup
cycles (W3: 6.6 and 27.9): the big lexical tables are few but costly per fetch. The hit/miss split
above 64 (counts, cycles in the stats build):

| workload | hits | misses | hit share of fetches >64 | hit cycles | miss cycles |
|---|---|---|---|---|---|
| W1 | 148,650 | 1,250 | 99.2% | 23,208,066 | 211,484 |
| W2 | 456,046 | 18,432 | 96.1% | 56,492,913 | 1,578,772 |
| W3 | 26,015,133 | 741,452 | 97.2% | 18,759,320,520 | 276,975,265 |

So above 64 i2 is a hit-dominated site (96-99 percent hits); the miss-heavy mix (31-37 percent
misses, outer-frame walk) is on the small tables. `num_lexicals` is known at the build call, so a
per-frame choice is implementable; the lever is whether a hit win of 0.88-0.99 on tables above 64 is
worth carrying 2-33 percent of i2's fetch cycles (i2 itself is 6.6-14.0 percent of hash cycles).

## Per site

Every site with fetches; s5 and i2 first, then by fetch cycles over the three workloads.

### s5

**W1** (2726050 fetches, 231636877 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 609754 | 219050 | 60946665 | 26.3 |
| <=16 | 810126 | 86350 | 59879859 | 25.9 |
| <=32 | 126821 | 224300 | 31573781 | 13.6 |
| <=64 | 34845 | 172200 | 24136642 | 10.4 |
| <=65 | 3452 | 113850 | 9617517 | 4.2 |
| <=128 | 12852 | 115850 | 14395479 | 6.2 |
| <=256 | 22650 | 6200 | 5844334 | 2.5 |
| <=1024 | 160800 | 6950 | 25242600 | 10.9 |

- at or above 65: 16.2% of fetches, 23.8% of fetch cycles
- at or above 128: 11.9% of fetches, 19.6% of fetch cycles

**W2** (145359131 fetches, 11462229507 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 26483836 | 13107484 | 2480595790 | 21.6 |
| <=16 | 12319117 | 4958352 | 1721050836 | 15.0 |
| <=32 | 1528736 | 1005614 | 327854979 | 2.9 |
| <=64 | 16278290 | 838529 | 787601856 | 6.9 |
| <=65 | 15793 | 111603 | 16971840 | 0.1 |
| <=128 | 4880509 | 375785 | 503501129 | 4.4 |
| <=256 | 27348161 | 332304 | 1906451992 | 16.6 |
| <=1024 | 30040634 | 930116 | 2778867021 | 24.2 |
| <=16384 | 3018780 | 280501 | 673248324 | 5.9 |
| >16384 | 1470384 | 34603 | 266085740 | 2.3 |

- at or above 65: 47.4% of fetches, 53.6% of fetch cycles
- at or above 128: 47.3% of fetches, 53.5% of fetch cycles

**W3** (940396828 fetches, 267074712252 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 143761015 | 73734141 | 64460253915 | 24.1 |
| <=16 | 256023032 | 61758398 | 69810605914 | 26.1 |
| <=32 | 19525814 | 54875488 | 18017056692 | 6.7 |
| <=64 | 39712021 | 38714993 | 21150516146 | 7.9 |
| <=65 | 1052993 | 26342328 | 4880039308 | 1.8 |
| <=128 | 12248097 | 28050271 | 13173099196 | 4.9 |
| <=256 | 23664133 | 2225698 | 14695371324 | 5.5 |
| <=1024 | 133909129 | 2836630 | 54431582030 | 20.4 |
| <=16384 | 21250922 | 477203 | 6315549878 | 2.4 |
| >16384 | 90856 | 143666 | 140637849 | 0.1 |

- at or above 65: 26.8% of fetches, 35.1% of fetch cycles
- at or above 128: 23.9% of fetches, 33.2% of fetch cycles

### i2

**W1** (1141950 fetches, 70768137 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=16 | 924850 | 17350 | 43008951 | 60.8 |
| <=32 | 36200 | 5450 | 3825121 | 5.4 |
| <=64 | 7900 | 300 | 514515 | 0.7 |
| <=128 | 13850 | 850 | 1851831 | 2.6 |
| <=256 | 1000 | 100 | 367047 | 0.5 |
| <=1024 | 133800 | 300 | 21200672 | 30.0 |

- at or above 65: 13.1% of fetches, 33.1% of fetch cycles
- at or above 128: 13.1% of fetches, 33.1% of fetch cycles

**W2** (58562640 fetches, 2980117821 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=16 | 34364149 | 23086673 | 2834251471 | 95.1 |
| <=32 | 294128 | 341919 | 87715504 | 2.9 |
| <=64 | 1268 | 25 | 79161 | 0.0 |
| <=128 | 368237 | 11967 | 37676336 | 1.3 |
| <=256 | 218 | 4649 | 286218 | 0.0 |
| <=1024 | 87591 | 1816 | 20109131 | 0.7 |

- at or above 65: 0.8% of fetches, 1.9% of fetch cycles
- at or above 128: 0.8% of fetches, 1.9% of fetch cycles

**W3** (403504854 fetches, 68331432221 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=16 | 242739343 | 102887007 | 39711209975 | 58.1 |
| <=32 | 9399084 | 13377070 | 8059929793 | 11.8 |
| <=64 | 2325971 | 6019794 | 1523996668 | 2.2 |
| <=65 | 355 | 1642 | 606508 | 0.0 |
| <=128 | 1103293 | 475893 | 1083103367 | 1.6 |
| <=256 | 67571 | 16030 | 189258161 | 0.3 |
| <=1024 | 24843914 | 247873 | 17763321977 | 26.0 |
| <=16384 | 0 | 14 | 5772 | 0.0 |

- at or above 65: 6.6% of fetches, 27.9% of fetch cycles
- at or above 128: 6.6% of fetches, 27.9% of fetch cycles

### f8

**W1** (116250 fetches, 49193979 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=128 | 116250 | 0 | 49193979 | 100.0 |

- at or above 65: 100.0% of fetches, 100.0% of fetch cycles
- at or above 128: 100.0% of fetches, 100.0% of fetch cycles

**W2** (41662 fetches, 22384963 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=128 | 41662 | 0 | 22384963 | 100.0 |

- at or above 65: 100.0% of fetches, 100.0% of fetch cycles
- at or above 128: 100.0% of fetches, 100.0% of fetch cycles

**W3** (8513338 fetches, 11588037252 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=128 | 8513338 | 0 | 11588037252 | 100.0 |

- at or above 65: 100.0% of fetches, 100.0% of fetch cycles
- at or above 128: 100.0% of fetches, 100.0% of fetch cycles

### i1

**W1** (264050 fetches, 89138217 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=64 | 264050 | 0 | 89138217 | 100.0 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

**W2** (42477 fetches, 20158083 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=64 | 42477 | 0 | 20158083 | 100.0 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

**W3** (13967449 fetches, 9924790424 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=64 | 13967449 | 0 | 9924790424 | 100.0 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

### other

**W1** (249800 fetches, 7953068 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 0 | 249800 | 7953068 | 100.0 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

**W2** (12141794 fetches, 419104626 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 0 | 12141794 | 419104626 | 100.0 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

**W3** (78843831 fetches, 7677222491 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 0 | 78843831 | 7677222491 | 100.0 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

### f4

**W1** (17900 fetches, 21047931 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 17850 | 50 | 21047931 | 100.0 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

**W2** (62231 fetches, 103449891 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 62227 | 4 | 103449891 | 100.0 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

**W3** (1757791 fetches, 4175532399 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 1755167 | 2624 | 4175532399 | 100.0 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

### s6

**W1** (1900 fetches, 114758 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 1800 | 50 | 100846 | 87.9 |
| <=16 | 0 | 50 | 13912 | 12.1 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

**W2** (1849138 fetches, 197168052 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 209049 | 696465 | 52118746 | 26.4 |
| <=16 | 75559 | 591823 | 89479468 | 45.4 |
| <=32 | 8056 | 41762 | 7653393 | 3.9 |
| <=64 | 191 | 0 | 173308 | 0.1 |
| <=256 | 226205 | 28 | 47743137 | 24.2 |

- at or above 65: 12.2% of fetches, 24.2% of fetch cycles
- at or above 128: 12.2% of fetches, 24.2% of fetch cycles

**W3** (9173784 fetches, 3401638573 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 1374681 | 2578362 | 974608811 | 28.7 |
| <=16 | 222290 | 4581936 | 2188120306 | 64.3 |
| <=32 | 87623 | 294004 | 192301613 | 5.7 |
| <=64 | 6501 | 20 | 8681014 | 0.3 |
| <=256 | 28208 | 150 | 37905369 | 1.1 |
| <=16384 | 8 | 1 | 21460 | 0.0 |

- at or above 65: 0.3% of fetches, 1.1% of fetch cycles
- at or above 128: 0.3% of fetches, 1.1% of fetch cycles

### p1

**W1** (2950 fetches, 224791 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 200 | 0 | 13590 | 6.0 |
| <=16 | 600 | 0 | 37210 | 16.6 |
| <=32 | 2150 | 0 | 173991 | 77.4 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

**W2** (353807 fetches, 23708488 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 8521 | 0 | 479581 | 2.0 |
| <=16 | 19935 | 0 | 1177953 | 5.0 |
| <=32 | 21380 | 0 | 1243475 | 5.2 |
| <=64 | 36136 | 0 | 1974329 | 8.3 |
| <=65 | 1023 | 0 | 50441 | 0.2 |
| <=128 | 59536 | 0 | 3336044 | 14.1 |
| <=256 | 76797 | 0 | 4429421 | 18.7 |
| <=1024 | 99293 | 0 | 7505016 | 31.7 |
| <=16384 | 31186 | 0 | 3512228 | 14.8 |

- at or above 65: 75.7% of fetches, 79.4% of fetch cycles
- at or above 128: 75.4% of fetches, 79.2% of fetch cycles

**W3** (11050778 fetches, 1373557018 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 39898 | 0 | 6161383 | 0.4 |
| <=16 | 155901 | 0 | 30444005 | 2.2 |
| <=32 | 207738 | 0 | 25946616 | 1.9 |
| <=64 | 361668 | 0 | 52895010 | 3.9 |
| <=65 | 10247 | 0 | 1423665 | 0.1 |
| <=128 | 610658 | 0 | 65352445 | 4.8 |
| <=256 | 1009064 | 0 | 117900280 | 8.6 |
| <=1024 | 5141525 | 0 | 610763365 | 44.5 |
| <=16384 | 3514079 | 0 | 462670249 | 33.7 |

- at or above 65: 93.1% of fetches, 91.6% of fetch cycles
- at or above 128: 93.0% of fetches, 91.5% of fetch cycles

### s1

**W1** (14600 fetches, 8881828 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=16 | 3550 | 0 | 1936529 | 21.8 |
| <=32 | 11050 | 0 | 6945299 | 78.2 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

**W2** (5003 fetches, 2776618 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=16 | 4063 | 0 | 2176885 | 78.4 |
| <=32 | 940 | 0 | 599733 | 21.6 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

**W3** (648310 fetches, 1149481860 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=16 | 52480 | 0 | 72851335 | 6.3 |
| <=32 | 593946 | 0 | 1073437388 | 93.4 |
| <=64 | 1866 | 0 | 3167311 | 0.3 |
| <=128 | 18 | 0 | 25826 | 0.0 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

### f3

**W1** (17950 fetches, 1747103 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 17900 | 50 | 1747103 | 100.0 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

**W2** (62235 fetches, 18625948 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 62231 | 4 | 18625948 | 100.0 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

**W3** (1760415 fetches, 745680128 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 1757791 | 2624 | 745680128 | 100.0 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

### f6

**W1** (2050 fetches, 2559623 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 0 | 500 | 549598 | 21.5 |
| <=16 | 0 | 850 | 937691 | 36.6 |
| <=32 | 200 | 500 | 1072334 | 41.9 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

**W2** (877 fetches, 914603 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 0 | 390 | 429200 | 46.9 |
| <=16 | 0 | 448 | 443556 | 48.5 |
| <=32 | 4 | 35 | 41847 | 4.6 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

**W3** (83590 fetches, 218480005 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 0 | 13120 | 19712749 | 9.0 |
| <=16 | 0 | 31488 | 51347342 | 23.5 |
| <=32 | 12592 | 26390 | 147419914 | 67.5 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

### f5

**W1** (650 fetches, 377252 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 0 | 250 | 58349 | 15.5 |
| <=16 | 150 | 250 | 318903 | 84.5 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

**W2** (49 fetches, 21460 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 0 | 20 | 3922 | 18.3 |
| <=16 | 9 | 20 | 17538 | 81.7 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

**W3** (34225 fetches, 79428492 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 0 | 13120 | 5716611 | 7.2 |
| <=16 | 7985 | 13120 | 73711881 | 92.8 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

### f7

**W1** (1600 fetches, 552114 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 1600 | 0 | 552114 | 100.0 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

**W2** (102 fetches, 37370 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 102 | 0 | 37370 | 100.0 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

**W3** (83681 fetches, 72062051 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 83681 | 0 | 72062051 | 100.0 |

- at or above 65: 0.0% of fetches, 0.0% of fetch cycles
- at or above 128: 0.0% of fetches, 0.0% of fetch cycles

### u1

**W1** (100 fetches, 32375 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=16384 | 100 | 0 | 32375 | 100.0 |

- at or above 65: 100.0% of fetches, 100.0% of fetch cycles
- at or above 128: 100.0% of fetches, 100.0% of fetch cycles

**W2** (534 fetches, 114785 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=16384 | 534 | 0 | 114785 | 100.0 |

- at or above 65: 100.0% of fetches, 100.0% of fetch cycles
- at or above 128: 100.0% of fetches, 100.0% of fetch cycles

**W3** (15563 fetches, 23524060 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=16384 | 15543 | 20 | 23524060 | 100.0 |

- at or above 65: 100.0% of fetches, 100.0% of fetch cycles
- at or above 128: 100.0% of fetches, 100.0% of fetch cycles

### u4

W1: no fetches

**W2** (524 fetches, 162097 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=256 | 524 | 0 | 162097 | 100.0 |

- at or above 65: 100.0% of fetches, 100.0% of fetch cycles
- at or above 128: 100.0% of fetches, 100.0% of fetch cycles

**W3** (9788 fetches, 9423423 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=4 | 687 | 0 | 203651 | 2.2 |
| <=16 | 1392 | 23 | 255337 | 2.7 |
| <=64 | 9 | 0 | 1110 | 0.0 |
| <=256 | 6680 | 40 | 8669130 | 92.0 |
| <=1024 | 395 | 0 | 113962 | 1.2 |
| <=16384 | 559 | 3 | 180233 | 1.9 |

- at or above 65: 78.4% of fetches, 95.1% of fetch cycles
- at or above 128: 78.4% of fetches, 95.1% of fetch cycles

### u3

W1: no fetches

W2: no fetches

**W3** (1853 fetches, 3398635 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| >16384 | 1836 | 17 | 3398635 | 100.0 |

- at or above 65: 100.0% of fetches, 100.0% of fetch cycles
- at or above 128: 100.0% of fetches, 100.0% of fetch cycles

### u2

W1: no fetches

W2: no fetches

**W3** (17 fetches, 7289 fetch cycles)

| size | hits | misses | cycles | % of fetch cycles |
|---|---|---|---|---|
| <=16384 | 5 | 12 | 7289 | 100.0 |

- at or above 65: 100.0% of fetches, 100.0% of fetch cycles
- at or above 128: 100.0% of fetches, 100.0% of fetch cycles


