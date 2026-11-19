# E2: nqp::encode into an array that already has storage grows it by the
# rounded-DOWN element count but copies every byte.
#
# MVM_string_encode_to_buf_config (src/strings/ops.c:1906-1911), append
# branch: MVM_repr_pos_set_elems(elems + output_size / elem_size), then
# memmove(..., encoded, output_size). When output_size is not a multiple of
# elem_size the last output_size % elem_size bytes have no element, and when
# the storage is exactly full they land past the allocation.
# (Found by the Task 1 review; independent of E1's offset error: here
# prev_elems is 0 and start is 0, so E1's wrong offset happens to be right.)
#
# The program: a uint16 array grown to 8 elements (ssize 8: 16 bytes) and
# set back to 0 elements (the storage stays), then 17 bytes of utf8 encoded
# into it: set_elems(0 + 17 / 2 = 8) needs no growth, and the memmove writes
# 17 bytes into the 16-byte buffer.
# A correct VM prints "elems 9" (17 bytes need 9 two-byte elements, the
# last half zero) or refuses a byte count that is not a multiple of the
# element size. The bug: the 17-byte memmove writes 1 byte past the 16-byte
# buffer. The plain build dies with SIGSEGV before printing (every one of
# four runs; presumably the byte lands in mimalloc's free-list pointer of the
# neighbouring block, not verified); the AddressSanitizer build reports
# heap-buffer-overflow WRITE of size 17, 0 bytes after the 16-byte region, in
# MVM_string_encode_to_buf_config (memmove). Even without the overrun the
# array would say elems 8 and drop the 17th byte.

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
my $a := nqp::create(arrtype(inttype(16, 1)));
nqp::setelems($a, 8); nqp::setelems($a, 0);
nqp::encode('abcdefghijklmnopq', 'utf8', $a);
say("elems " ~ nqp::elems($a));
