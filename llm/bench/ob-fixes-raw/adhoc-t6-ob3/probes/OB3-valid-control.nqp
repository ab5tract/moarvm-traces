sub inttype(int $bits, int $unsigned) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    my $h := nqp::hash('bits', $bits);
    if $unsigned { $h<unsigned> := 1 }
    nqp::composetype($t, nqp::hash('integer', $h));
    $t
}
sub MAIN($program) {
    my $at := nqp::newtype(nqp::null(), 'VMArray');
    nqp::composetype($at, nqp::hash('array', nqp::hash('type', inttype(8, 1))));
    my $a := nqp::create($at);
    my int $i := 0; while $i < 64 { nqp::push_i($a, $i); $i++ }
    sub write_flags_9($a, int $v) { nqp::writeint($a, 4, $v, 9) }
    sub read_flags_9($a) { nqp::readuint($a, 4, 9) }
    my int $sum := 0;
    $i := 0;
    while $i < 200000 { write_flags_9($a, $i); $sum := $sum + read_flags_9($a); $i++ }
    say("valid flags 9 (4 bytes, little endian): sum $sum, bytes 4-7 " ~ nqp::atpos_i($a, 4) ~ " " ~ nqp::atpos_i($a, 5) ~ " " ~ nqp::atpos_i($a, 6) ~ " " ~ nqp::atpos_i($a, 7));
}
