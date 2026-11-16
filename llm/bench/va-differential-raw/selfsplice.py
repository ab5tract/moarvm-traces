#!/usr/bin/env python3
# selfsplice.py OUTPUT: classify the *.selfsplice.* cases of a vmarray-diff.nqp
# output by what the final copy of asplice did: for every case the result is
# compared with a model of asplice whose last step is (a) a memmove and (b) a
# forward element-by-element copy.
import hashlib, re, sys
def ival(j, bits, signed):
    v = j * 3 + 1
    if bits == 0: return v
    v &= (1 << bits) - 1
    if signed and v >= 1 << (bits - 1): v -= 1 << bits
    return v
KINDS = {'obj': None, 'str': None, 'i64': (64, 1), 'i32': (32, 1), 'i16': (16, 1), 'i8': (8, 1),
         'u64': (64, 1), 'u32': (32, 0), 'u16': (16, 0), 'u8': (8, 0), 'n64': 'n', 'n32': 'n'}
def val(kind, j):
    k = KINDS[kind]
    if kind == 'obj': return 'o%d' % j
    if kind == 'str': return 's%d' % j
    if k == 'n': return ('%g' % (j + 0.25))
    return str(ival(j, k[0], k[1]))
CASES = {  # name: (len, extra, offset, count)
 'prepend': (10,0,0,0), 'append': (10,0,10,0), 'middle': (10,0,5,0), 'middle1': (10,0,1,0), 'middle9': (10,0,9,0),
 'replace.2.3': (10,0,2,3), 'replace.0.3': (10,0,0,3), 'replace.all': (10,0,0,10), 'replace.over': (10,0,0,20),
 'replace.tail': (10,0,7,3), 'replace.5.5': (10,0,5,5), 'replace.1.9': (10,0,1,9), 'replace.1.20': (10,0,1,20),
 'neg': (10,0,-3,1), 'past': (10,0,12,0), 'shifted.prepend': (10,4,0,0), 'shifted.prepend20': (10,20,0,0),
 'shifted.middle': (10,4,5,0), 'shifted.replace': (10,4,0,4), 'shifted.replace.2.3': (10,4,2,3),
 'shifted.append': (10,4,10,0), 'one': (1,0,0,0), 'one.replace': (1,0,0,1), 'empty': (0,0,0,0),
 'big.middle': (9000,0,4500,0), 'big.1': (9000,0,1,0), 'big.replace': (9000,0,100,5000), 'big.shifted': (9000,50,3,7)}
def model(kind, n, extra, offset, count, forward):
    zero = {'obj': '<null>', 'str': '<null>'}.get(kind, '0')
    slots = [val(kind, 90 + j) for j in range(extra)] + [val(kind, j) for j in range(n)]
    start, elems0, elems1 = extra, n, n
    if offset < 0: offset += elems0
    if offset == 0:
        d = elems1 - count
        if d > start: d = start
        if d <= -elems0: elems0 = 0; count = 0; start = 0
        elif d != 0: elems0 += d; count += d; start -= d
    if count == 0 and elems1 == 0: return slots[start:start + elems0]
    tail = max(elems0 - offset - count, 0)
    need = start + offset + elems1 + tail
    if tail > 0 and count > elems1:
        slots[start+offset+elems1:start+offset+elems1+tail] = slots[start+offset+count:start+offset+count+tail]
    new = offset + elems1 + tail
    if new < elems0:                       # set_size_internal clears what it gives up
        for i in range(start + new, start + elems0): slots[i] = zero
    slots += [zero] * max(0, need - len(slots))
    if tail > 0 and count < elems1:
        src = slots[start+offset+count:start+offset+count+tail]
        slots[start+offset+elems1:start+offset+elems1+tail] = src
    # the final copy: source is the array itself, elements [0, elems1) of the new view
    if forward:
        for i in range(elems1): slots[start + offset + i] = slots[start + i]
    else:
        src = slots[start:start + elems1]
        slots[start + offset:start + offset + elems1] = src
    return slots[start:start + new]
def shown(v):
    # What the program's dump prints: the elements, or above 40 of them their SHA-1.
    return v if len(v) <= 40 else ['sha1=' + hashlib.sha1(' '.join(v).encode()).hexdigest().upper()]
args = [a for a in sys.argv[1:] if a != '--list']
out = {}
for line in open(args[0]):
    m = re.match(r'(\w+)\.selfsplice\.([\w.]+): elems=(\d+) (?:\[(.*)\]|(sha1=\w+) head)', line.rstrip('\n'))
    if m and m.group(2) in CASES:
        out[(m.group(1), m.group(2))] = [m.group(5)] if m.group(5) else (m.group(4).split(' ') if m.group(4) else [])
rows = []
for name in CASES:
    for kind in KINDS:
        if (kind, name) not in out: continue
        got = out[(kind, name)]
        mm = shown(model(kind, *CASES[name], forward=False))
        fw = shown(model(kind, *CASES[name], forward=True))
        what = 'memmove and forward copy (no overlap that matters)' if got == mm == fw else 'memmove' if got == mm else 'forward copy' if got == fw else 'NEITHER'
        rows.append((name, kind, what, mm != fw))
if '--list' in sys.argv:
    # The lines whose value depends on how overlapping ranges are copied, for
    # the kinds the C copies with memcpy (every kind but STR).
    for name, kind, what, overlap in rows:
        if overlap and kind != 'str': print("diff-nqp %s.selfsplice.%s" % (kind, name))
else:
    print("case\tkind\tresult is")
    for name, kind, what, overlap in rows: print("%s\t%s\t%s" % (name, kind, what))
