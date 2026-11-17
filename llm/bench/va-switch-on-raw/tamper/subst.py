# subst.py LINES FILE: replace, in FILE, each line whose case name a line of LINES has.
import sys
new = {}
for l in open(sys.argv[1]):
    l = l.rstrip('\n'); new[l[:l.index(': ')]] = l
out = []
for l in open(sys.argv[2]):
    l = l.rstrip('\n'); i = l.find(': ')
    out.append(new.get(l[:i], l) if i > 0 else l)
open(sys.argv[2], 'w').write('\n'.join(out) + '\n')
