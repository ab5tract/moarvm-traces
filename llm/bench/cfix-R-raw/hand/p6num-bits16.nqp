# What a VMArray compose does with an element type whose own compose was
# refused (P6num with bits 16: "Unsupported num size"): the P6num keeps its
# default storage spec (64 bits), so the array type gets num64, before and
# after the fix; spec_to_repr_data's "Unsupported num size" is not reached.
my $n := nqp::newtype(nqp::null(), 'P6num');
try { nqp::composetype($n, nqp::hash('float', nqp::hash('bits', 16))); CATCH { say('P6num compose: ' ~ nqp::getmessage($!)) } }
my $t := nqp::newtype(nqp::null(), 'VMArray');
my $r := 'returned';
try { nqp::composetype($t, nqp::hash('array', nqp::hash('type', $n))); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("VMArray compose with it: $r");
my $a := nqp::create($t);
nqp::push_n($a, 1.5);
say("push_n 1.5, read back: " ~ nqp::atpos_n($a, 0) ~ "");
