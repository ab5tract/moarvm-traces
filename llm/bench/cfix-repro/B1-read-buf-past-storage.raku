# B1 from plain Raku (no nqp ops): Blob.read-uint8 / read-uint32 call
# nqp::readuint with no bounds check of their own (src/core.c/Buf.rakumod),
# so read_buf's check is the only one, and after shifts it lets reads past
# the end through (see B1-read-buf-past-storage.nqp for the C).
#
# A Buf of 8 bytes 1..8 (8 bytes of storage), two shifts (elements 3..8).
# A correct VM prints
#     elems 6
#     last: 8
#     past1: DIED ... read_buf out of bounds ...
#     past4: DIED ... read_buf out of bounds ...
# The bug: past1 and past4 return bytes from beyond the 8-byte allocation
# (AddressSanitizer: heap-buffer-overflow in read_buf at past1).

$*OUT.out-buffer = False;   # keep every line if the VM dies
my $b = Buf.new(1..8);
$b.shift for ^2;
say "elems {$b.elems}";
for <last 5 1> , <past1 6 1>, <past4 4 4> -> ($name, $off, $size) {
    my $r = try { $size == 1 ?? $b.read-uint8($off.Int) !! $b.read-uint32($off.Int) } // "DIED {$!.message}";
    say "$name: $r";
}
