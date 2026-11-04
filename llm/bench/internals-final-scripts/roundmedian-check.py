import sys,statistics as st,collections
f=sys.argv[1]
d=collections.defaultdict(list)
for l in open(f):
    p=l.rstrip('\n').split('\t')
    if len(p)<8 or not p[5].replace('.','').isdigit(): continue
    var,rnd,eng,size,op,ns=p[0],p[1],p[2],int(p[3]),p[4],float(p[5])
    d[(op,size,var)].append(ns)
out=[]
cells=sorted({(o,s) for o,s,v in d})
for o,s in cells:
    b=d[(o,s,'base')];h=d[(o,s,'head')]
    r=st.median(h)/st.median(b)
    ov=min(h)<=max(b) and min(b)<=max(h)
    out.append((o,s,r,ov,(min(b),max(b)),(min(h),max(h))))
for o,s,r,ov,b,h in out:
    if r>1.05: print(('PASS-overlap' if ov else 'OUTSIDE'),o,s,'%.3f'%r,b,h)
print(len(out),'cells; max ratio %.3f'%max(x[2] for x in out), 'min %.3f'%min(x[2] for x in out))
