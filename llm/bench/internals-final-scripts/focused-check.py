import statistics as st,collections,sys
d=collections.defaultdict(list)
for l in open(sys.argv[1]+'/capi.raw'):
    p=l.rstrip('\n').split('\t')
    if p[4] in('delete','iterate'): d[(p[4],int(p[3]),p[0])].append(float(p[5]))
for o,s in sorted({(a,b) for a,b,c in d}):
    b=d[(o,s,'base')];h=d[(o,s,'head')]
    print(o,s,'%.3f'%(st.median(h)/st.median(b)),(min(b),max(b)),(min(h),max(h)))
