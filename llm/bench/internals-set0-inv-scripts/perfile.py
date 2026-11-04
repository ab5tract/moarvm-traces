import re,sys,statistics as st
V='/tmp/claude-1000/inv/'
pat=re.compile(r'^\[[\d:]+\] (t/spec\S+) \.+ \S+\s+(\d+) ms \(.*\+\s*([\d.]+) cusr\s+([\d.]+) csys')
def load(f):
    d={}
    for l in open(V+f):
        m=pat.match(l)
        if m: d[m[1]]=(int(m[2]), float(m[3])+float(m[4]))
    return d
b=[load('s1-1-base.log'),load('s1-4-base.log')]
h=[load('s1-2-head.log'),load('s1-3-head.log')]
files=sorted(set(b[0])&set(b[1])&set(h[0])&set(h[1]))
rows=[]
for f in files:
    bw=st.mean(x[f][0] for x in b); hw=st.mean(x[f][0] for x in h)
    bc=st.mean(x[f][1] for x in b); hc=st.mean(x[f][1] for x in h)
    # noise: base-vs-base and head-vs-head diff
    rows.append((f,bw,hw,hw-bw,hw/bw if bw else 0,bc,hc,hc-bc,abs(b[0][f][0]-b[1][f][0]),abs(h[0][f][0]-h[1][f][0])))
tot=sum(r[3] for r in rows); totc=sum(r[7] for r in rows)
print(f"files {len(rows)} sum wall delta {tot:.0f} ms (base sum {sum(r[1] for r in rows):.0f}); sum cpu delta {totc:.1f} s (base {sum(r[5] for r in rows):.1f})")
bn=sum(abs(r[8]) for r in rows); hn=sum(abs(r[9]) for r in rows)
print(f"sum |base1-base2| {bn:.0f} ms, sum |head1-head2| {hn:.0f} ms")
def tbl(title,rs):
    print("\n"+title); print("| file | base ms | head ms | delta ms | ratio | cpu delta s | base spread ms | head spread ms |\n|---|---:|---:|---:|---:|---:|---:|---:|")
    for r in rs: print(f"| {r[0]} | {r[1]:.0f} | {r[2]:.0f} | {r[3]:+.0f} | {r[4]:.2f} | {r[7]:+.2f} | {r[8]:.0f} | {r[9]:.0f} |")
bydelta=sorted(rows,key=lambda r:-r[3])[:20]
tbl("Top 20 by wall delta (mean of 2 runs per side)",bydelta)
print(f"sum of top-20 deltas {sum(r[3] for r in bydelta):.0f} ms of total {tot:.0f}")
big=[r for r in rows if r[1]>=500]
byratio=sorted(big,key=lambda r:-r[4])[:20]
tbl("Top 20 by ratio (base >= 500 ms)",byratio)
print(f"sum of top-20 ratio deltas {sum(r[3] for r in byratio):.0f} ms")
tbl("Top 20 by cpu delta",sorted(rows,key=lambda r:-r[7])[:20])
pos=sum(r[3] for r in rows if r[3]>0); neg=sum(r[3] for r in rows if r[3]<0)
print(f"\npositive deltas sum {pos:.0f}, negative {neg:.0f}, files slower {sum(1 for r in rows if r[3]>0)}")
