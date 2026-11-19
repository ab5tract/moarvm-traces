#!/usr/bin/env python3
"""matrix-check.py BASE FIXED: checks the output of cfix-repro/R-recompose-matrix.nqp
on a fixed build (FIXED) against the rule and against the unmodified build (BASE):
 - allowed exactly when the first kind is "none" or both kinds have the same
   slot type and size (obj and obj2 are one kind);
 - every allowed pair prints exactly what BASE prints;
 - every refused pair leaves the live array as pushed and the type with its
   first kind (the fresh array takes an element of the first kind)."""
import re, sys
def load(p):
    d = {}
    for l in open(p):
        m = re.match(r'^(\S+) -> (\S+): (allowed|DIED [^;]*); live (.*); fresh (.*)$', l.rstrip())
        if m: d[(m[1], m[2])] = (m[3], m[4], m[5])
    return d
b, r = load(sys.argv[1]), load(sys.argv[2])
exp_live = {'obj': 'elems 2: VMArray(5) VMArray(6)', 'obj2': 'elems 2: VMArray(5) VMArray(6)', 'int8': 'elems 2: 5 6',
            'uint8': 'elems 2: 5 6', 'int64': 'elems 2: 5 6', 'uint64': 'elems 2: 5 6', 'num64': 'elems 2: 5.5 6.5', 'str': 'elems 2: x y'}
exp_fresh = {'obj': 'elems 1: VMArray(7)', 'obj2': 'elems 1: VMArray(7)', 'int8': 'elems 1: 7', 'uint8': 'elems 1: 7',
             'int64': 'elems 1: 7', 'uint64': 'elems 1: 7', 'num64': 'elems 1: 7.5', 'str': 'elems 1: z'}
kind = {'none': 'o', 'obj': 'o', 'obj2': 'o', 'int8': 'i8', 'uint8': 'u8', 'int64': 'i64', 'uint64': 'u64', 'num64': 'n64', 'str': 's'}
bad = 0; allowed = 0
for k, (res, live, fresh) in sorted(r.items()):
    a, bb = k
    if (a == 'none' or kind[a] == kind[bb]) != (res == 'allowed'): print('RULE', k, res); bad += 1
    if res == 'allowed':
        allowed += 1
        if b[k] != r[k]: print('ALLOWED PAIR DIFFERS', k, b[k], r[k]); bad += 1
    elif live != exp_live[a] or fresh != exp_fresh[a]: print('STATE', k, live, fresh); bad += 1
print('pairs %d, allowed %d, refused %d, violations %d' % (len(r), allowed, len(r) - allowed, bad))
sys.exit(1 if bad else 0)
