# P2: a splice copying into or out of a kind without storage reaches abort().
#
# The six 1/2/4-bit element types compose to slot kinds U4, U2, U1, I4, I2,
# I1 with elem_size 0. copy_elements (VMArray.c:933) takes the element-wise
# path whenever source and target kinds differ, and slot_type_to_kind
# (VMArray.c:904-931) has no arm for these kinds: `default: abort();`
# ("never reached"). For the target (VMArray.c:957) and for the source
# (VMArray.c:958).
#
# Reaching it needs an array of such a kind with elements, and the only way
# to get one is to recompose the array's type while the array is alive: a
# fresh no-storage array cannot grow (every growth dies in zero_slots with
# "Unhandled slot type" before ssize or elems change), and a splice of 0
# elements copies nothing. So each case makes an int8 array 1 4 7 (storage
# of 8 slots) and recomposes its type to a 4-bit unsigned element type; the
# array keeps its slots and elems 3 and now has kind U4.
#
# Run with one argument: "target" splices a 1-element int64 array into the
# recomposed array (no growth: 4 <= ssize 8, so copy_elements is reached);
# "source" splices the recomposed array into a fresh int64 array.
#
# A correct VM prints, for either case,
#     <case>: DIED <an exception>
# and carries on to "survived". The bug: abort() (SIGABRT, exit 134), with
# no message, on both builds.

sub inttype(int $bits, int $unsigned) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    my $h := nqp::hash('bits', $bits);
    if $unsigned { $h<unsigned> := 1 }
    nqp::composetype($t, nqp::hash('integer', $h));
    $t
}
sub arrtype($elem) {
    my $t := nqp::newtype(nqp::null(), 'VMArray');
    nqp::composetype($t, nqp::hash('array', nqp::hash('type', $elem)));
    $t
}

sub MAIN($prog, $case) {
    my $ty := arrtype(inttype(8, 0));
    my $a := nqp::create($ty);
    nqp::push_i($a, 1); nqp::push_i($a, 4); nqp::push_i($a, 7);
    nqp::composetype($ty, nqp::hash('array', nqp::hash('type', inttype(4, 1))));
    say("recomposed to uint4: elems " ~ nqp::elems($a));
    my $r;
    if $case eq 'target' {
        try { nqp::splice($a, nqp::list_i(9), 1, 0); $r := 'returned, elems ' ~ nqp::elems($a); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
    }
    elsif $case eq 'source' {
        my $b := nqp::list_i(5, 6);
        try { nqp::splice($b, $a, 1, 0); $r := 'returned, elems ' ~ nqp::elems($b); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
    }
    else { nqp::die("case: target or source") }
    say("$case: $r");
    say("survived");
}
