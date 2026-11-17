# gdb script: the Zig array's two JIT fast functions under vmarray-devirt.nqp
# (Task 8, ruling 3; the Zig counterpart of va-differential-raw/coverage/bt.py).
# A breakpoint on each function's entry counts its calls and prints those
# with an index below -10 (4th argument, rcx; the program's arrays have 10
# elements, so only those indices cannot resolve); a breakpoint on
# MVM_exception_throw_adhoc prints the message and the chain of frames that
# called it (inlined frames included: the build has DWARF), so a throw from
# inside one of the two (the inlined fromEnd's "MVMArray: Index out of
# bounds") is named with the function it is inlined into.
import gdb
gdb.execute("set pagination off"); gdb.execute("set debuginfod enabled off")
AT = "6model.reprs.vmarray.elements.Elements(6model.reprs.vmarray.storage.Storage(6model.reprs.VMArray.S__struct_0)).atPosKind(.i64).jit"
BIND = "6model.reprs.vmarray.elements.Elements(6model.reprs.vmarray.storage.Storage(6model.reprs.VMArray.S__struct_0)).bindPosKind(.i64).jit"
class Entry(gdb.Breakpoint):
    def __init__(self, spec, label):
        super().__init__(spec); self.label = label; self.n = 0
    def stop(self):
        self.n += 1
        idx = int(gdb.parse_and_eval("(long)$rcx"))
        if idx < -10:
            print("ENTER %s index=%d (call %d)" % (self.label, idx, self.n))
        return False
class Throw(gdb.Breakpoint):
    def stop(self):
        msg = gdb.parse_and_eval("(char *)$rsi").string()
        if "Index out of bounds" in msg:
            chain, f = [], gdb.selected_frame().older()
            while f is not None and len(chain) < 4:
                n = str(f.name())
                chain.append(n.replace("6model.reprs.vmarray.elements.Elements(6model.reprs.vmarray.storage.Storage(6model.reprs.VMArray.S__struct_0)).", "E."))
                f = f.older()
            print("THROW %r from %s" % (msg, " <- ".join(chain)))
        return False
gdb.execute("catch load libmoar"); gdb.execute("run")
at = Entry("'" + AT + "'", "at_pos_int64"); bind = Entry("'" + BIND + "'", "bind_pos_int64")
Throw("MVM_exception_throw_adhoc")
gdb.execute("delete 1")
gdb.execute("continue")
print("CALLS at_pos_int64=%d bind_pos_int64=%d" % (at.n, bind.n))
