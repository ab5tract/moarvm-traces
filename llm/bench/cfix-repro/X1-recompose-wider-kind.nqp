# X1 (not on the plan's list; seen on the way, reported, not to be fixed by
# this campaign without a decision): recomposing an array type to a wider
# element kind while an array of it is alive makes the array read and write
# past its storage.
#
# compose (VMArray.c:1320-1333) rewrites slot_type and elem_size in the
# STable's REPR data; live arrays keep their slots and ssize, which were
# sized for the old element size. An int8 array of 3 elements has 8 slots
# = 8 bytes; after a recompose to int64 its ssize of 8 now means 64 bytes.
# (The differential's recomposed.i8.u8 and recomposed.i64.n64 cases are the
# same-size variants: a wrong reading, no overrun.) Rakudo composes each
# type once (REPRComposeProtocol.nqp, $!composed_repr); P6opaque refuses a
# second compose ("Type ... is already composed", P6opaque.c:735-737).
#
# A correct VM prints either an exception at the second composetype, or
# elems 3 and in-bounds values. The bug: atpos_i at 7 reads bytes 56..63 of
# the 8-byte buffer (AddressSanitizer: heap-buffer-overflow in
# MVM_VMArray_at_pos), and bindpos_i at 7 writes there.

sub inttype(int $bits, int $unsigned) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    my $h := nqp::hash('bits', $bits);
    if $unsigned { $h<unsigned> := 1 }
    nqp::composetype($t, nqp::hash('integer', $h));
    $t
}
my $ty := nqp::newtype(nqp::null(), 'VMArray');
nqp::composetype($ty, nqp::hash('array', nqp::hash('type', inttype(8, 0))));
my $a := nqp::create($ty);
nqp::push_i($a, 1); nqp::push_i($a, 4); nqp::push_i($a, 7);
nqp::composetype($ty, nqp::hash('array', nqp::hash('type', inttype(64, 0))));
say("recomposed to int64: elems " ~ nqp::elems($a));
nqp::setelems($a, 8);
say("element 7: " ~ nqp::atpos_i($a, 7));
nqp::bindpos_i($a, 7, 42);
say("bound element 7: " ~ nqp::atpos_i($a, 7));
