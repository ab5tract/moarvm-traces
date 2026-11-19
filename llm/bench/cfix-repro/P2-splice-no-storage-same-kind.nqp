# P2, the cases next to P2-splice-no-storage-kind.nqp: a splice where BOTH
# sides have a kind without storage, and splices with an empty source.
#
# The six 1/2/4-bit element types compose to kinds U4 .. I1 with elem_size 0.
# As in P2-splice-no-storage-kind.nqp, arrays of such a kind with elements
# exist only after recomposing a live array's type: here an int8 type with
# arrays a = 1 4 7 (storage of 8 slots) and b, recomposed to a 4-bit unsigned
# element type. Then, with both of kind U4, copy_elements takes its fast path
# (same kind, same elem_size 0) and copies 0 bytes, so nothing aborts; what
# happens depends on the growth:
#   same-fit   splice(a, b = [9], 1, 0): 4 <= ssize 8, set_size_internal only
#              sets elems: upstream returns with elems 4 and nothing copied.
#   same-grow  splice(a, b = [9 x 6], 1, 0): 9 > ssize 8: set_size_internal
#              reallocs the slots to 0 bytes (9 * elem_size 0), stores the
#              pointer, and zero_slots throws "Unhandled slot type" before
#              ssize is updated: a's slots are gone while ssize stays 8.
# To show what a's storage holds afterwards, the type is then recomposed back
# to int8 (elem_size 1) and a's elements are read.
#   empty-src  an empty array of the uint4 type (made after recomposing, no
#              elements) as the source of a deletion from an int array:
#              splice(list_i(5, 6, 7), empty, 1, 1) -> 5 7.
#   empty-into splice(a, list_i(), 1, 0) into the recomposed a: nothing to
#              copy or remove, asplice returns early.
#
# A correct VM (the fix: refuse a splice with elements to copy when either
# side has no storage, "MVMArray: Unhandled slot type", before anything is
# changed) prints
#     same-fit: DIED MVMArray: Unhandled slot type
#     back to int8: elems 3: 1 4 7
#     same-grow: DIED MVMArray: Unhandled slot type
#     back to int8: elems 3: 1 4 7
#     empty-src: returned, elems 2: 5 7
#     empty-into: returned, elems 3
# Upstream: same-fit returns with elems 4 ("1 4 7 0" read back); same-grow
# dies as above but a's slots were realloc'ed to 0 bytes: reading them back
# reads freed memory (mimalloc: a minimal block; ASAN/glibc: NULL, a SEGV).

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
sub show_i($a) {
    my @s := nqp::list_s();
    my int $i := 0;
    while $i < nqp::elems($a) { nqp::push_s(@s, ~nqp::atpos_i($a, $i)); $i++ }
    'elems ' ~ nqp::elems($a) ~ ': ' ~ nqp::join(' ', @s)
}

sub MAIN($prog, $case) {
    my $i8 := inttype(8, 0);
    my $u4 := inttype(4, 1);
    my $ty := arrtype($i8);
    my $r;
    if $case eq 'same-fit' || $case eq 'same-grow' {
        my $a := nqp::create($ty);
        nqp::push_i($a, 1); nqp::push_i($a, 4); nqp::push_i($a, 7);
        my $b := nqp::create($ty);
        nqp::push_i($b, 9);
        if $case eq 'same-grow' { my int $k := 1; while $k < 6 { nqp::push_i($b, 9); $k++ } }
        nqp::composetype($ty, nqp::hash('array', nqp::hash('type', $u4)));
        try { nqp::splice($a, $b, 1, 0); $r := 'returned, elems ' ~ nqp::elems($a); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
        say("$case: $r");
        nqp::composetype($ty, nqp::hash('array', nqp::hash('type', $i8)));
        say("back to int8: " ~ show_i($a));
    }
    elsif $case eq 'empty-src' {
        my $uty := arrtype($u4);
        my $empty := nqp::create($uty);
        my $t := nqp::list_i(5, 6, 7);
        try { nqp::splice($t, $empty, 1, 1); $r := 'returned, ' ~ show_i($t); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
        say("$case: $r");
    }
    elsif $case eq 'empty-into' {
        my $a := nqp::create($ty);
        nqp::push_i($a, 1); nqp::push_i($a, 4); nqp::push_i($a, 7);
        nqp::composetype($ty, nqp::hash('array', nqp::hash('type', $u4)));
        try { nqp::splice($a, nqp::list_i(), 1, 0); $r := 'returned, elems ' ~ nqp::elems($a); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
        say("$case: $r");
    }
    else { nqp::die("case: same-fit, same-grow, empty-src or empty-into") }
}
