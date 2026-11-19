# B1: read_buf's bounds check counts start, so with start > 0 a read past the
# last element passes, and it can lie beyond the storage.
#
# read_buf (VMArray.c:1014-1036) checks
#     (start + elems) * elem_size < offset * elem_size + count
# and then reads from slots + (start + offset) * elem_size. The check should
# compare against elems * elem_size: as written it lets a read end up to
# start * elem_size bytes past the last element, and past the allocation
# when ssize == start + elems.
#
# The program: a uint8 array of 8 elements 1..8 (ssize 8: 8 bytes of
# storage), two shift_i (start 2, elems 6, elements 3..8). Then
#   readuint(offset 5, 1 byte)  the last element (8): in bounds
#   readuint(offset 6, 1 byte)  one past the last element: storage byte 8,
#                               the first byte after the 8-byte allocation
#   readuint(offset 4, 4 bytes) storage bytes 6..9: two bytes past it
# A correct VM prints
#     last: 8
#     past1: DIED MVMArray: read_buf out of bounds ...
#     past4: DIED MVMArray: read_buf out of bounds ...
# The bug: both pass the check and read past the allocation: the plain build
# prints whatever bytes follow the block (past1: 8, past4: 526343 =
# 0x080807 in the recorded run); the AddressSanitizer build stops at past1
# with heap-buffer-overflow "0 bytes after 8-byte region" in read_buf.
# Flags: size is 1 << (flags >> 2): 0 is 1 byte, 8 is 4 bytes; endianness
# native (0) here, little-endian forced with 1.

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

my $a := nqp::create(arrtype(inttype(8, 1)));
my int $i := 1; while $i <= 8 { nqp::push_i($a, $i); $i++ }
nqp::shift_i($a); nqp::shift_i($a);
say("elems " ~ nqp::elems($a));
t('last',  { ~nqp::readuint($a, 5, 0) });
t('past1', { ~nqp::readuint($a, 6, 0) });
t('past4', { ~nqp::readuint($a, 4, 9) });
