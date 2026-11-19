#!/usr/bin/env python3
# prefix-cmp.py A B: the result lines ("<kind> <target> ...") of two
# E-encode-state outputs must agree line for line as far as both go
# (a build without the E fix may crash after an overrunning case, at a
# point that varies run to run). Prints "agree N lines (A: a, B: b)" or
# the first disagreement.
import sys
def res(p):
    return [l.rstrip('\n') for l in open(p) if ' bytes: ' in l]
a, b = res(sys.argv[1]), res(sys.argv[2])
n = min(len(a), len(b))
for i in range(n):
    if a[i] != b[i]:
        print("DISAGREE at result line %d:\n  %s\n  %s" % (i + 1, a[i], b[i])); sys.exit(1)
print("agree %d lines (%d, %d)" % (n, len(a), len(b)))
