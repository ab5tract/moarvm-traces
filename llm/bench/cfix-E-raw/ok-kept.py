#!/usr/bin/env python3
# ok-kept.py FIXED BASE...: every "ok" result line of the upstream outputs
# (the cases upstream got right) must appear unchanged in the fixed build's
# output; prints the counts.
import sys
fixed = set(l.rstrip('\n') for l in open(sys.argv[1]) if ' bytes: ' in l)
ok = set()
for p in sys.argv[2:]:
    ok |= set(l.rstrip('\n') for l in open(p) if ' bytes: ok' in l)
missing = sorted(ok - fixed)
print("upstream ok lines: %d, present unchanged in the fixed output: %d" % (len(ok), len(ok) - len(missing)))
for l in missing: print("  NOT KEPT:", l)
