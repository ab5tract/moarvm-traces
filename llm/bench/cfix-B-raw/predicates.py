#!/usr/bin/env python3
"""predicates.py: the bounds checks of read_buf and write_buf before and after
each commit of the branch, as integer predicates in uint64 arithmetic (C's
rules: MVMint64 offset converted to uint64 in the products, size_t elem_size),
compared over edge values and random samples.

Checks:
 1. B1 vs upstream read check: differ only when start > 0 (the B1 change).
 2. B2 read check vs B1 read check: differ only when the old expression
    offset * es + count wraps (>= 2**64).
 3. B2 write check vs upstream write check: the same.
 4. In every case where the B2 checks let an access through, its byte range
    (start + offset) * es .. + count lies within (start + elems) * es, with
    exact integers (no wrap).
 5. Every write the B2 check sends to set_size_internal with a wrapping old
    expression asks for n = offset + count > the size limit 2**63 / es, so
    set_size_internal throws.
Inputs: es in 1, 2, 4, 8; elems and start with start + elems <= 2**63 / es
(what set_size_internal allows); offset in 0 .. 2**63 - 1; count 0 .. 8.
"""
import random
M = 2**64
def u(x): return x % M
def up_read(es, start, elems, off, cnt):   # upstream: passes?
    return off >= 0 and not (u((start + elems) * es) < u(u(off * es) + cnt))
def b1_read(es, start, elems, off, cnt):
    return off >= 0 and not (u(elems * es) < u(u(off * es) + cnt))
def b2_read(es, start, elems, off, cnt):
    return off >= 0 and not (off > elems or u((elems - off) * es) < cnt)
def up_grow(es, elems, off, cnt):
    return u(elems * es) < u(u(off * es) + cnt)
def b2_grow(es, elems, off, cnt):
    return off > elems or u((elems - off) * es) < cnt
def wraps(es, off, cnt): return off * es + cnt >= M
random.seed(4)
edges_off = [0, 1, 2, 3, 7, 8, 9, 2**31, 2**32, 2**60 - 1, 2**60, 2**60 + 5, 2**61 - 1, 2**61, 2**61 + 1,
             2**62 - 1, 2**62, 2**62 + 1, 2**63 - 9, 2**63 - 8, 2**63 - 2, 2**63 - 1]
n = 0; bad = []
for es in (1, 2, 4, 8):
    L = 2**63 // es
    sizes = [0, 1, 2, 3, 5, 8, 9, 100, 2**20, L // 2, L - 1, L]
    cases = []
    for elems in sizes:
        for start in [0, 1, 3, 2**20, L // 2, L]:
            if start + elems > L: continue
            for off in edges_off + [elems, elems - 1, elems + 1, elems + 2]:
                if 0 <= off < 2**63:
                    for cnt in range(0, 9): cases.append((start, elems, off, cnt))
    for _ in range(200000):
        elems = random.choice([random.randrange(0, 64), random.randrange(0, L + 1)])
        start = random.randrange(0, L - elems + 1) if random.random() < .5 else random.randrange(0, min(8, L - elems) + 1)
        off = random.choice([random.randrange(0, 2**63), random.randrange(0, elems + 4), random.choice(edges_off)])
        cases.append((start, elems, off, random.randrange(0, 9)))
    for start, elems, off, cnt in cases:
        n += 1
        a, b, c = up_read(es, start, elems, off, cnt), b1_read(es, start, elems, off, cnt), b2_read(es, start, elems, off, cnt)
        if a != b and start == 0: bad.append(('1: B1 differs with start 0', es, start, elems, off, cnt))
        if b != c and not wraps(es, off, cnt): bad.append(('2: B2 read differs without wrap', es, start, elems, off, cnt))
        g0, g1 = up_grow(es, elems, off, cnt), b2_grow(es, elems, off, cnt)
        if g0 != g1 and not wraps(es, off, cnt): bad.append(('3: B2 write differs without wrap', es, start, elems, off, cnt))
        if c and not ((start + off) * es + cnt <= (start + elems) * es): bad.append(('4: read let through out of range', es, start, elems, off, cnt))
        if not g1 and not ((start + off) * es + cnt <= (start + elems) * es): bad.append(('4: write in place out of range', es, start, elems, off, cnt))
        if g1 and wraps(es, off, cnt) and not (off + cnt > L): bad.append(('5: wrapping write under the limit', es, start, elems, off, cnt))
print('cases: %d, violations: %d' % (n, len(bad)))
for x in bad[:20]: print(x)
