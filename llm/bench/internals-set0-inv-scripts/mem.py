def rh(n):
    size=8
    while size*3//4<n: size*=2
    lim=min(255,size//4*3); a=size+lim-1
    return 16*a+32+((a+1-1+8)&~7)
def sw(n):
    s=16
    while s-s//8<n: s*=2
    return 32+s+16*s
print("| entries | RH slots-block bytes | Swiss bytes | Swiss/RH |\n|---:|---:|---:|---:|")
for n in (65,80,96,97,112,113,128,129,192,193,224,225,256,384,385,448,449,1024,16384):
    print(f"| {n} | {rh(n)} | {sw(n)} | {sw(n)/rh(n):.2f} |")
# W3 s5 demolish bins rung1: <=65:213 <=128:80532 <=256:4686 <=1024:3574 <=16384:6
bins={'65':(213,[65]),'66-128':(80532,[66,80,96,112,128]),'129-256':(4686,[129,192,256]),'257-1024':(3574,[300,512,1024]),'1025-16384':(6,[2000,16384])}
tot_rh=tot_sw=0
print("\n| bin | tables demolished (W3) | RH bytes/table range | Swiss bytes/table range | total RH | total Swiss (mid-range sample, mean over sample sizes) |")
for k,(cnt,ns) in bins.items():
    r=sum(rh(n) for n in ns)/len(ns); s=sum(sw(n) for n in ns)/len(ns)
    tot_rh+=cnt*r; tot_sw+=cnt*s
    print(f"| {k} | {cnt} | {min(rh(n) for n in ns)}-{max(rh(n) for n in ns)} | {min(sw(n) for n in ns)}-{max(sw(n) for n in ns)} | {cnt*r/1e6:.1f} MB | {cnt*s/1e6:.1f} MB |")
print(f"cumulative bytes allocated by final-size blocks over the whole spectest: RH {tot_rh/1e6:.1f} MB, Swiss {tot_sw/1e6:.1f} MB")
