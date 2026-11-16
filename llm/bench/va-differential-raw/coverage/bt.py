import gdb
gdb.execute("set pagination off"); gdb.execute("set debuginfod enabled off")
class B(gdb.Breakpoint):
    def stop(self):
        print("HIT %s index=%s" % (self.location, gdb.parse_and_eval("index")))
        return False
gdb.execute("catch load libmoar"); gdb.execute("run")
B("VMArray.c:1592"); B("VMArray.c:1568")
gdb.execute("continue")
