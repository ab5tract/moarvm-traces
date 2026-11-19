# B3: writeint on an array whose type was recomposed to a kind without
# storage writes into the old storage, and a growing write frees it.
#
# write_buf (VMArray.c:988-1012) refuses only slot kinds below I64 (OBJ,
# STR), so the six no-storage kinds U4 .. I1 (elem_size 0) pass. With
# elem_size 0 its size check reads elems * 0 < offset * 0 + count, always
# true, so it calls set_size_internal(offset + count):
#   - within the old ssize, that only sets elems, and the memcpy writes
#     count bytes at the start of the old buffer;
#   - beyond it, set_size_internal reallocs the buffer to ssize * 0 = 0
#     bytes, stores the result in slots, and dies in zero_slots
#     ("Unhandled slot type") before it updates ssize; realloc(p, 0) has
#     freed the buffer (glibc and ASAN return NULL; mimalloc returns a
#     minimal block), and the next write within the stale ssize copies to it.
# A no-storage array has storage only after its type was recomposed while it
# was alive (as for P2): an int8 array 1 4 7 (8 bytes), recomposed to uint4.
#
# A correct VM prints
#     write 8 bytes at 0: DIED <an exception: no storage for this kind>
#     elems 3
#     write 8 bytes at 8: DIED <the same>
#     write 8 bytes at 0 again: DIED <the same>
#     survived
# The bug: the first write returns and sets elems to 8; the second dies with
# "MVMArray: Unhandled slot type" after the realloc to 0 bytes; the third
# writes 8 bytes through the pointer that realloc left: SIGSEGV on a NULL
# pointer under AddressSanitizer (on the plain build mimalloc's minimal
# block takes the 8 bytes silently).

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

my $ty := arrtype(inttype(8, 0));
my $a := nqp::create($ty);
nqp::push_i($a, 1); nqp::push_i($a, 4); nqp::push_i($a, 7);
nqp::composetype($ty, nqp::hash('array', nqp::hash('type', inttype(4, 1))));
t('write 8 bytes at 0', { nqp::writeint($a, 0, 0x1122334455667788, 12); 'returned' });
say("elems " ~ nqp::elems($a));
t('write 8 bytes at 8', { nqp::writeint($a, 8, 0x1122334455667788, 12); 'returned' });
t('write 8 bytes at 0 again', { nqp::writeint($a, 0, 0x1122334455667788, 12); 'returned' });
say("survived");
