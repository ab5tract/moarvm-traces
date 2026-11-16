#!/usr/bin/env python3
# messages.py VMArray.c OUTPUT...: for every distinct message format of the
# MVM_exception_throw_adhoc sites in VMArray.c, the number of sites that use
# it and the number of output lines (over all OUTPUT files) that carry it,
# with one case name as an example.
import re, sys
src = open(sys.argv[1]).read()
fmts = {}
for m in re.finditer(r'MVM_exception_throw_adhoc\(tc,\s*((?:"(?:[^"\\]|\\.)*"\s*(?:PRI[a-z0-9]+\s*)?)+)', src):
    raw = m.group(1)
    pieces = re.findall(r'"((?:[^"\\]|\\.)*)"|(PRI[a-z0-9]+)', raw)
    fmt = ''.join(p[0] if p[0] else 'N' for p in pieces)   # a PRI macro stands for a number conversion
    fmt = fmt.replace("\\'", "'")
    fmts[fmt] = fmts.get(fmt, 0) + 1
lines = []
for f in sys.argv[2:]:
    for l in open(f, errors='replace'):
        if 'DIED' in l or 'Unhandled' in l or "Can't" in l: lines.append(l.rstrip('\n'))
print("sites\toutput lines\tmessage format\texample case")
reached = 0
for fmt in sorted(fmts):
    rx = re.escape(fmt)
    rx = re.sub(r'%N|%u|%d', r'-?[0-9]+', rx)
    rx = rx.replace('%s', r'[A-Za-z0-9_]+')
    rx = re.compile(rx + r'($| \||;| /)')
    hits = [l for l in lines if rx.search(l)]
    if hits: reached += 1
    print("%d\t%d\t%s\t%s" % (fmts[fmt], len(hits), fmt, hits[0].split(': ')[0] if hits else '-'))
print("# %d sites, %d distinct message formats, %d formats seen in the outputs" % (sum(fmts.values()), len(fmts), reached))
distinct = set()
for l in lines:
    m = re.search(r'DIED (.*)', l)
    if m: distinct.add(m.group(1))
print("# %d distinct DIED messages in the outputs (every message of every case, VMArray's and others')" % len(distinct))
