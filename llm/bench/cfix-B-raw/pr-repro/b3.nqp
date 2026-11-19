sub int_type(int $bits) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    nqp::composetype($t, nqp::hash('integer', nqp::hash('bits', $bits, 'unsigned', 1)));
    $t
}
sub try_write($a, int $off) {
    my $r := 'returned';
    try { nqp::writeint($a, $off, 1, 12); CATCH { $r := 'died: ' ~ nqp::getmessage($!) } }
    say("write at $off: $r; elems " ~ nqp::elems($a));
}
my $type := nqp::newtype(nqp::null(), 'VMArray');
nqp::composetype($type, nqp::hash('array', nqp::hash('type', int_type(8))));
my $a := nqp::create($type);
nqp::push_i($a, 1); nqp::push_i($a, 4); nqp::push_i($a, 7);
nqp::composetype($type, nqp::hash('array', nqp::hash('type', int_type(4))));
try_write($a, 0);
try_write($a, 8);
try_write($a, 0);
