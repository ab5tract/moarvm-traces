import gdb
gdb.execute("set pagination off"); gdb.execute("set confirm off"); gdb.execute("set debuginfod enabled off")
gdb.execute("handle SIGSEGV nostop noprint pass")
hits = set()
class B(gdb.Breakpoint):
    def __init__(self, spec, tag):
        super().__init__(spec, internal=True)
        self.tag = tag
    def stop(self):
        hits.add(self.tag)
        self.enabled = False
        return False
gdb.execute("catch load libmoar")
gdb.execute("run")
tags = []
for l in range(1, 1696):
    try:
        sals = gdb.decode_line("VMArray.c:%d" % l)[1]
    except gdb.error:
        continue
    if not sals or all(s.line != l for s in sals):
        continue
    try:
        B("VMArray.c:%d" % l, l); tags.append(l)
    except gdb.error:
        pass
gdb.execute("continue")
with open(COVOUT, "w") as o:
    for t in tags: o.write(("HIT " if t in hits else "MISS ") + str(t) + "\n")
