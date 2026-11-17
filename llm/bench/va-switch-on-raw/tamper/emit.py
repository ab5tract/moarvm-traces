# emit.py NAME...: the memmove model's line for each NAME (diff-nqp).
import importlib.util, sys
spec = importlib.util.spec_from_file_location('m', '/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM/tools/bench/repr/memmove-model.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
for n in sys.argv[1:]:
    print('%s: %s' % (n, m.expected('diff-nqp', n)))
