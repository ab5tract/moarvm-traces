# OB22 probe (Task 7): nqp::slice of a P6opaque whose positional delegate is a
# VMArray. OP(slice) allocates dest from the P6opaque source's type; oslice
# hands that P6opaque dest to VMArray's aslice, which treats its body as an
# MVMArrayBody and its REPR data as MVMArrayREPRData. Run with ulimit -c 0 and
# a memory cap; the output is whatever happens.
class Holder {
    has @!list is positional_delegate;
    method init() { @!list := nqp::list('a', 'b', 'c', 'd'); self }
}
my $h := Holder.new.init;
say("elems through the delegate: " ~ nqp::elems($h));
say("atpos 1 through the delegate: " ~ nqp::atpos($h, 1));
my $r;
try { my $s := nqp::slice($h, 1, 2); $r := 'returned, result REPR ' ~ nqp::reprname($s) ~ ', how ' ~ $s.HOW.name($s); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("slice 1..2: $r");
say("delegate after: elems " ~ nqp::elems($h) ~ ", atpos 1 " ~ nqp::atpos($h, 1));
nqp::force_gc();
say("after a full collection: elems " ~ nqp::elems($h));
say("done");
