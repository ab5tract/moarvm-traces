#!/usr/bin/env python3
# sites.py VMArray.c COVDIR: one row per MVM_exception_throw_adhoc site of
# VMArray.c with the function it is in, its message and the runs (program and
# spesh setting) whose line coverage hit it; then one row per function with
# the number of its lines that have code and that were hit by any run.
import re, sys, glob, os
src = open(sys.argv[1]).read().split('\n')
cov = {}
for f in sorted(glob.glob(os.path.join(sys.argv[2], 'cov-*.txt'))):
    name = os.path.basename(f)[4:-4]
    for l in open(f):
        st, n = l.split(); cov.setdefault(int(n), {})[name] = (st == 'HIT')
func = {}; cur = None
fre = re.compile(r'^(?:static |MVM_STATIC_INLINE )?[A-Za-z_][A-Za-z0-9_ \*]*?\b([A-Za-z_][A-Za-z0-9_]*) ?\(MVMThreadContext \*tc|^static MVMuint16 (slot_type_to_kind)\(')
for i, line in enumerate(src, 1):
    m = fre.match(line)
    if m and not line.rstrip().endswith(';'): cur = m.group(1) or m.group(2)
    func[i] = cur
    if line == '}': func[i] = cur; cur_end = cur
print("# throw sites\nline\tfunction\tmessage\thit by")
n_sites = n_hit = 0
for i, line in enumerate(src, 1):
    if 'MVM_exception_throw_adhoc' not in line: continue
    n_sites += 1
    j = i; text = line
    while '"' not in text: j += 1; text += src[j - 1]
    msg = re.search(r'"((?:[^"\\]|\\.)*)"', text).group(1)
    while text.rstrip().endswith('"') is False and ');' not in text: j += 1; text += src[j - 1]
    parts = re.findall(r'"((?:[^"\\]|\\.)*)"', text)
    msg = ' ... '.join(parts) if len(parts) > 1 else msg
    lines = [k for k in range(i, j + 1) if k in cov]
    hit = sorted({r for k in lines for r, h in cov[k].items() if h})
    if hit: n_hit += 1
    print("%d\t%s\t%s\t%s" % (i, func[i], msg, ' '.join(hit) if hit else ('NOT HIT' if lines else 'no code')))
print("# %d sites, %d hit" % (n_sites, n_hit))
print("# functions\nfunction\tlines with code\tlines hit by any run\tnever hit")
per = {}
for n, runs in cov.items():
    per.setdefault(func.get(n), []).append((n, any(runs.values())))
for fn in sorted(per, key=lambda f: min(n for n, _ in per[f])):
    ls = per[fn]
    miss = [str(n) for n, h in sorted(ls) if not h]
    print("%s\t%d\t%d\t%s" % (fn, len(ls), sum(1 for _, h in ls if h), ' '.join(miss)))
