sub inttype(int $bits, int $unsigned) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    my $h := nqp::hash('bits', $bits);
    if $unsigned { $h<unsigned> := 1 }
    nqp::composetype($t, nqp::hash('integer', $h));
    $t
}
sub MAIN($program, $case) {
    my $at := nqp::newtype(nqp::null(), 'VMArray');
    nqp::composetype($at, nqp::hash('array', nqp::hash('type', inttype(8, 1))));
    my $a := nqp::create($at);
    my int $i := 0; while $i < 4 { nqp::push_i($a, $i); $i++ }
    my int $flags := nqp::radix(10, $case, 0, 0)[0];
    try { nqp::writeint($a, 0, 1, $flags); say("writeint $flags: returned; elems " ~ nqp::elems($a)); CATCH { say("writeint $flags: DIED " ~ nqp::getmessage($!)) } }
    try { my $v := nqp::readuint($a, 0, $flags); say("readuint $flags: returned $v"); CATCH { say("readuint $flags: DIED " ~ nqp::getmessage($!)) } }
    try { my $v := nqp::readint($a, 0, $flags); say("readint $flags: returned $v"); CATCH { say("readint $flags: DIED " ~ nqp::getmessage($!)) } }
}
