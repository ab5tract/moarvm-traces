# B2: write_buf and read_buf compute offset * elem_size in 64 bits, which
# wraps for offsets >= 2**61 (8-byte kinds) or 2**62 (4-byte kinds): the
# bounds check passes and the access lands at the aliased position.
#
# read_buf (VMArray.c:1026) checks (start + elems) * elem_size against
# offset * elem_size + count, write_buf (VMArray.c:1006) checks
# elems * elem_size against the same sum, and both then address
# slots + (start + offset) * elem_size. With offset = 2**61 + 1 and 8-byte
# elements, offset * 8 is 2**64 + 8 = 8 (mod 2**64): the check sees a read
# or write at byte 8 and the access goes to element 1.
#
# The program: an int64 array 1 2 3 4 and an int32 array 1 2 3 4.
#   readint  at 2**61 + 1 (int64, 8 bytes) and 2**62 + 1 (int32, 4 bytes)
#   writeint 99 at the same offsets, then the arrays are printed
# Flags: 12 = 8 bytes, 8 = 4 bytes, native endianness.
# A correct VM prints
#     i64 read: DIED MVMArray: read_buf out of bounds ...
#     i64 write: DIED (an out-of-bounds or "Unable to allocate" error)
#     i64 after: 1 2 3 4
# and the same for i32. The bug: the read returns element 1 (2), the write
# "succeeds" and element 1 becomes 99. No memory is touched outside the
# array, so the AddressSanitizer build prints the same as the plain build.

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
sub t($name, &code) {
    my $r;
    try { $r := code(); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
    say("$name: $r");
}
sub show($a) {
    my @p; my int $i := 0;
    while $i < nqp::elems($a) { nqp::push(@p, ~nqp::atpos_i($a, $i)); $i++ }
    nqp::join(' ', @p)
}

for ((64, 2305843009213693953, 12), (32, 4611686018427387905, 8)) -> $c {
    my int $bits := $c[0]; my int $off := $c[1]; my int $flags := $c[2];
    my $a := nqp::create(arrtype(inttype($bits, 0)));
    nqp::push_i($a, 1); nqp::push_i($a, 2); nqp::push_i($a, 3); nqp::push_i($a, 4);
    t("i$bits read at $off",  { ~nqp::readint($a, $off, $flags) });
    t("i$bits write at $off", { nqp::writeint($a, $off, 99, $flags); 'returned' });
    say("i$bits after: " ~ show($a));
}
