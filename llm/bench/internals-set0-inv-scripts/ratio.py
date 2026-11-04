import sys,statistics as st,collections
d=sys.argv[1]; ops=sys.argv[2].split(',')
for lvl in ('nqp','capi'):
    c=collections.defaultdict(lambda:collections.defaultdict(list))
    for l in open(f'{d}/{lvl}.raw'):
        p=l.split('\t'); v,r,_,s,op,ns=p[0],p[1],p[2],int(p[3]),p[4],float(p[5])
        c[(op,s)][v].append(ns)
    print(f"\n{lvl}: ratio head/base of median of round medians [base min-max | head min-max]")
    sizes=sorted({s for (_,s) in c})
    print("| op | "+" | ".join(map(str,sizes))+" |"); print("|---|"+"---:|"*len(sizes))
    for op in ops:
        row=[]
        for s in sizes:
            b=c[(op,s)]['base'];h=c[(op,s)]['head']
            if not b or not h: row.append('-'); continue
            row.append(f"{st.median(h)/st.median(b):.2f} [{min(b):.1f}-{max(b):.1f} / {min(h):.1f}-{max(h):.1f}]")
        print(f"| {op} | "+" | ".join(row)+" |")
