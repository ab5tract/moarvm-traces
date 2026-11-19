# B3, the zero-byte write: writeint with flags 32 (size 1 << 8, which the
# op's unsigned char truncates to 0) on an array of a storage-less kind
# (uint4, fresh type), and on a uint8 array for comparison.
sub int_type(int $bits) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    nqp::composetype($t, nqp::hash('integer', nqp::hash('bits', $bits, 'unsigned', 1)));
    $t
}
sub arr($bits) {
    my $t := nqp::newtype(nqp::null(), 'VMArray');
    nqp::composetype($t, nqp::hash('array', nqp::hash('type', int_type($bits))));
    nqp::create($t)
}
for (4, 8) -> $bits {
    my $a := arr($bits);
    my $r := 'returned';
    try { nqp::writeint($a, 0, 1, 32); CATCH { $r := 'died: ' ~ nqp::getmessage($!) } }
    say("uint$bits, zero-byte write at 0: $r; elems " ~ nqp::elems($a));
}
