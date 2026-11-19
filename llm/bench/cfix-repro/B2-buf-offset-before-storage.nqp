# B2, the sum: for a 2-byte kind, offset * 2 does not wrap for any offset
# below 2**63, but offset * elem_size + count does. With offset 2**63 - 1,
# offset * 2 = 2**64 - 2, and adding count 4 wraps to 2: the checks of
# read_buf (VMArray.c:1026) and write_buf (1006) see an access of the first
# two bytes, while the access goes to slots + (start + offset) * 2 =
# slots - 2 (start 0): two bytes before the allocation, then the first
# element's two bytes.
#
# The program: an int16 array 1 2 3 4 5 6 7 8 (ssize 8: 16 bytes), then
#   readint  4 bytes at 2**63 - 1
#   writeint 4 bytes (0x22221111) at 2**63 - 1, then the array is printed.
# A correct VM prints
#     read: DIED MVMArray: read_buf out of bounds ...
#     write: DIED (an out-of-bounds or "Unable to allocate" error)
#     after: elems 8: 1 2 3 4 5 6 7 8
# The bug: the read returns two bytes from before the allocation and element
# 0; the write changes element 0 to 0x2222 = 8738 and writes 0x1111 before
# the allocation (AddressSanitizer: heap-buffer-overflow, 2 bytes before the
# 16-byte region, at the read).

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
    'elems ' ~ nqp::elems($a) ~ ': ' ~ nqp::join(' ', @p)
}

my $a := nqp::create(arrtype(inttype(16, 0)));
my int $i := 1; while $i <= 8 { nqp::push_i($a, $i); $i++ }
t('read',  { ~nqp::readuint($a, 9223372036854775807, 8) });
t('write', { nqp::writeuint($a, 9223372036854775807, 0x22221111, 8); 'returned' });
say('after: ' ~ show($a));
