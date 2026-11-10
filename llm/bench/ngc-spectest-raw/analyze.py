#!/usr/bin/env python3
# ngc Task 9: per-run numbers, medians of three per side, TODO-passed lists and failures
# of the spectest A/B (z017-spectest.txt's shape). Usage: spectest-analyze.py RAWDIR BASELINE_DIR
import re, sys, os, statistics
raw, ref = sys.argv[1], sys.argv[2]
def wall(s):
    m = re.search(r'Elapsed \(wall clock\) time \(h:mm:ss or m:ss\): (\S+)', s).group(1).split(':')
    return float(m[-1]) + 60 * float(m[-2]) + (3600 * float(m[0]) if len(m) == 3 else 0), ':'.join(m)
def summary(log):
    i = log.find('Test Summary Report')
    block = log[i:] if i >= 0 else ''
    todo, fails = [], []
    cur = None
    for line in block.split('\n'):
        m = re.match(r'^(t/\S+)\s+\(Wstat: (\d+)(?: \([^)]*\))? Tests: (\d+) Failed: (\d+)\)', line)
        if m:
            cur = m.groups()
            if cur[1] != '0' or cur[3] != '0': fails.append(line.strip())
            continue
        if cur and 'TODO passed' in line: todo.append(cur[0])
        if cur and line.strip().startswith('Failed test'): fails.append('  ' + line.strip())
    return sorted(set(todo)), fails
runs = []
for f in sorted(os.listdir(raw), key=lambda x: (len(x), x)):
    m = re.match(r'run(\d+)-(base|head)\.time$', f)
    if not m: continue
    n, side = int(m.group(1)), m.group(2)
    t = open(os.path.join(raw, f)).read(); log = open(os.path.join(raw, f'run{n}-{side}.log'), errors='replace').read()
    w, ws = wall(t)
    rss = int(re.search(r'Maximum resident set size \(kbytes\): (\d+)', t).group(1))
    user = float(re.search(r'User time \(seconds\): ([\d.]+)', t).group(1))
    ex = re.search(r'Exit status: (\d+)', t).group(1)
    files = re.search(r'^(Files=\d+, Tests=\d+.*)$', log, re.M)
    res = re.search(r'^Result: (\S+)', log, re.M)
    todo, fails = summary(log)
    runs.append((n, side, w, ws, rss, user, ex, files.group(1) if files else '?', res.group(1) if res else '?', todo, fails))
runs.sort()
reflog = open(os.path.join(ref, 'run1-base.log'), errors='replace').read()
reftodo, _ = summary(reflog)
reffiles = re.search(r'^Files=(\d+), Tests=(\d+)', reflog, re.M).groups()
print('## per run')
for r in runs:
    n, side, w, ws, rss, user, ex, files, res, todo, fails = r
    print(f'run {n} {side}: wall {w:.2f} ({ws}) RSS {rss} user {user:.2f} exit {ex} Result: {res} todo {len(todo)} todo-list-equal-to-z017 {todo == reftodo}')
    print(f'  {files}')
    for x in fails: print(f'  FAIL {x}')
print()
med = {}
for side in ('base', 'head'):
    rs = [r for r in runs if r[1] == side]
    W = [r[2] for r in rs]; S = [r[4] for r in rs]; U = [r[5] for r in rs]
    med[side] = (statistics.median(W), statistics.median(S), statistics.median(U))
    print(f'{side}: wall {W} median {med[side][0]:.2f} spread {min(W):.2f}-{max(W):.2f} ({(max(W)-min(W))/med[side][0]:.4f}); RSS {S} median {med[side][1]:.0f} spread {min(S)}-{max(S)} ({(max(S)-min(S))/med[side][1]:.4f}); user median {med[side][2]:.2f}')
print(f"ratio head/base: wall {med['head'][0]/med['base'][0]:.3f} RSS {med['head'][1]/med['base'][1]:.3f} user {med['head'][2]/med['base'][2]:.3f}")
print(f'z017 reference: Files={reffiles[0]} Tests={reffiles[1]}, {len(reftodo)} TODO-passed files')
