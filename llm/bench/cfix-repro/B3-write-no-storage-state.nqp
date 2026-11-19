# B3, the array's state after each write: writeint on arrays of a kind
# without storage (uint4: elem_size 0), and what the array then holds.
#
# Two cases:
#   live   an int8 array 1 4 7 whose type is recomposed to uint4 while it is
#          alive (the only way such an array has storage), then three
#          8-byte writes (at 0, at 8, at 0 again) as in
#          B3-writeint-no-storage-kind.nqp;
#   fresh  a type composed with uint4 from the start: an empty array without
#          storage, two 8-byte writes at 0.
# After every write the program prints the write's result, elems, and for
# each index below elems what atpos_i says (uint4 has no element access, so
# "DIED MVMArray: Unhandled slot type" is the expected reading).
#
# A correct VM refuses every write with an exception and leaves elems as it
# was (live: 3; fresh: 0). Upstream: live, the first write returns and sets
# elems to 8, the second dies "Unhandled slot type" after reallocating the
# storage to 0 bytes, the third writes through the pointer that realloc left
# (SIGSEGV on NULL under AddressSanitizer); fresh, each write dies
# "Unhandled slot type" (after allocating 0 bytes) and elems stays 0.

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
sub state($a) {
    my @p; my int $i := 0;
    while $i < nqp::elems($a) {
        my $r;
        try { $r := ~nqp::atpos_i($a, $i); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
        nqp::push(@p, "[$i] $r");
        $i++;
    }
    'elems ' ~ nqp::elems($a) ~ (nqp::elems(@p) ?? '; ' ~ nqp::join('; ', @p) !! '')
}
sub w($name, $a, int $off) {
    my $r;
    try { nqp::writeint($a, $off, 0x1122334455667788, 12); $r := 'returned';
          CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
    say("$name: $r");
    say("  after: " ~ state($a));
}

sub MAIN($prog, $which = 'live') {
    if $which eq 'live' {
        my $ty := arrtype(inttype(8, 0));
        my $a := nqp::create($ty);
        nqp::push_i($a, 1); nqp::push_i($a, 4); nqp::push_i($a, 7);
        say("before recompose: " ~ state($a));
        nqp::composetype($ty, nqp::hash('array', nqp::hash('type', inttype(4, 1))));
        say("recomposed to uint4: elems " ~ nqp::elems($a));
        w('write 8 bytes at 0', $a, 0);
        w('write 8 bytes at 8', $a, 8);
        w('write 8 bytes at 0 again', $a, 0);
    }
    else {
        my $a := nqp::create(arrtype(inttype(4, 1)));
        say("fresh uint4 array: " ~ state($a));
        w('write 8 bytes at 0', $a, 0);
        w('write 8 bytes at 0 again', $a, 0);
    }
    say("survived");
}
