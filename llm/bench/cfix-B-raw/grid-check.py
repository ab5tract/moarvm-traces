#!/usr/bin/env python3
"""grid-check.py OLD NEW: compares two outputs of cfix-repro/B-buf-grid.nqp
(OLD from an unmodified build, NEW from the fixed one) line by line.

For each case it computes, with exact integers, what the old checks and the
fixed checks decide:
  read:  old passes iff offset >= 0 and not ((start + elems) * es mod 2**64
         < (offset * es + size) mod 2**64); new passes iff offset >= 0 and
         offset <= elems and (elems - offset) * es >= size;
  write: old grows iff elems * es mod 2**64 < (offset * es + size) mod 2**64;
         new grows iff offset > elems or (elems - offset) * es < size
         (a negative offset throws first in both).
A line may differ only where the old and the new decision differ. Where
they are equal the line must be identical. It also checks what the fixed
build printed where the decisions differ: a read the new check refuses must
print "DIED MVMArray: read_buf out of bounds", and a write the new check
grows for at a large offset must print "DIED Unable to allocate an array of"
and the array as it was made (the state the off=-1
write of the same case prints). Prints counts per category and every violation; exit
status 1 if there is any.

grid-check.py OLD NEW --unchanged: both outputs from builds without the
buffer fix (an unmodified build, a rerun of it, or another area's branch).
Then a line may differ only if it is a read the old check lets through
although it ends past the elements (it prints bytes from outside the array,
which vary run to run); every other line must be identical.
"""
import re, sys
M = 2**64
ES = {'int8': 1, 'uint8': 1, 'int16': 2, 'uint16': 2, 'int32': 4, 'uint32': 4,
      'int64': 8, 'uint64': 8, 'num32': 4, 'num64': 8}
pat = re.compile(r'^([RW]) kind=(\S+) start=(\d+) elems=(\d+) off=(-?\d+) size=(\d+): (.*)$')
def load(p):
    d = {}
    for line in open(p, errors='replace'):
        m = pat.match(line.rstrip('\n'))
        if m:
            d[m.group(1, 2, 3, 4, 5, 6)] = m.group(7)
    return d
unchanged = len(sys.argv) > 3 and sys.argv[3] == '--unchanged'
old, new = load(sys.argv[1]), load(sys.argv[2])
if set(old) != set(new):
    print('case sets differ:', len(old), len(new)); sys.exit(1)
cnt = {}; bad = []
def add(k): cnt[k] = cnt.get(k, 0) + 1
for key in sorted(old):
    rw, kind, start, elems, off, size = key
    es = ES[kind]; start, elems, off, size = int(start), int(elems), int(off), int(size)
    o, n = old[key], new[key]
    if unchanged:
        oldp = rw == 'R' and off >= 0 and not (((start + elems) * es) % M < (off * es + size) % M)
        outside = rw == 'R' and oldp and not (off <= elems and (elems - off) * es >= size)
        k = ('R outside the elements' if outside else rw + ' other') + (', identical' if o == n else ', differs')
        add(k)
        if o != n and not outside: bad.append(('differs outside the noise class', key, o, n))
        continue
    if rw == 'R':
        oldp = off >= 0 and not (((start + elems) * es) % M < (off * es + size) % M)
        newp = off >= 0 and off <= elems and (elems - off) * es >= size
        if oldp == newp:
            add('R same decision, ' + ('identical' if o == n else 'DIFFERS'))
            if o != n: bad.append(('R decision equal but output differs', key, o, n))
        else:
            add('R decision changed (old %s, new %s)' % ('passes' if oldp else 'refuses', 'passes' if newp else 'refuses'))
            if newp or not n.startswith('DIED MVMArray: read_buf out of bounds'):
                bad.append(('R changed decision, unexpected new output', key, o, n))
    else:
        if o.startswith('skipped'):
            add('W skipped'); continue
        if off < 0:
            add('W negative, ' + ('identical' if o == n else 'DIFFERS'))
            if o != n: bad.append(('W negative differs', key, o, n))
            continue
        oldg = (elems * es) % M < (off * es + size) % M
        newg = off > elems or (elems - off) * es < size
        if oldg == newg:
            add('W same decision, ' + ('identical' if o == n else 'DIFFERS'))
            if o != n: bad.append(('W decision equal but output differs', key, o, n))
        else:
            add('W decision changed (old %s, new %s)' % ('grows' if oldg else 'in place', 'grows' if newg else 'in place'))
            if not newg or not n.startswith('DIED Unable to allocate an array of'):
                bad.append(('W changed decision, unexpected new output', key, o, n))
            # the array after the rejected write must be the array as made:
            # the state printed after the off=-1 write of the same case
            ref = new[(rw, kind, str(start), str(elems), '-1', str(size))]
            if n[n.index(', elems '):] != ref[ref.index(', elems '):]:
                bad.append(('W rejected write changed the array', key, ref, n))
for k in sorted(cnt): print('%6d  %s' % (cnt[k], k))
for b in bad: print('VIOLATION', b)
print('violations: %d' % len(bad))
sys.exit(1 if bad else 0)
