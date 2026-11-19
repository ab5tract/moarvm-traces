# gc-model.py OUTPUT: the diff-nqp <kind>.gc.* lines that follow the self-splice
# of a promoted array, computed with memmove semantics for that splice
# (nqp::splice($old, $old, 5, 0): elements 0..4, then the whole array as it is,
# then elements 5..), compared with what OUTPUT prints. The array before it is
# simulated from gc_cases() in vmarray-diff.nqp and checked against the
# gc.barrier line first.
import hashlib, sys
def rendered(v):
    if len(v) <= 40:
        return 'elems=%d [%s]' % (len(v), ' '.join(v))
    sha = hashlib.sha1(' '.join(v).encode()).hexdigest().upper()
    return 'elems=%d sha1=%s head=[%s] tail=[%s]' % (len(v), sha, ' '.join(v[:3]), ' '.join(v[-3:]))
printed = {}
for line in open(sys.argv[1]):
    i = line.find(': ')
    if i > 0: printed[line[:i]] = line[i+2:].rstrip('\n')
bad = 0
for kn, p in (('obj', 'o'), ('str', 's')):
    v = lambda j: '%s%d' % (p, j)
    old = [v(j) for j in range(30)]          # fill_shifted(30, 7): the 7 extra are shifted off
    want = {'survive': rendered(old)}
    for j in range(40):
        old.append(v(j + 5)); old.insert(0, v(j + 6)); old[3] = v(j)
    want['barrier'] = rendered(old)
    src = [v(j) for j in range(20)]
    old = old[:4] + src + old[6:]            # splice($old, fill(20), 4, 2)
    old = old[:5] + list(old) + old[5:]      # splice($old, $old, 5, 0), memmove
    want['splice.promoted'] = rendered(old)
    want['slice.promoted'] = rendered(old[3:21])
    want['clone.promoted'] = rendered(old + [v(1)])
    for case, w in want.items():
        name = '%s.gc.%s' % (kn, case); got = printed.get(name)
        ok = got == w; bad += not ok
        print('%s %s' % ('memmove' if ok else 'MISMATCH', name) + ('' if ok else '\n    model:   %s\n    printed: %s' % (w, got)))
    sel = [v(j) for j in range(10)]; sel = sel[:5] + sel + sel[5:]
    name = '%s.gc.selfsplice.promoted' % kn; ok = printed.get(name) == rendered(sel); bad += not ok
    print('%s %s' % ('memmove' if ok else 'MISMATCH', name))
sys.exit(1 if bad else 0)
