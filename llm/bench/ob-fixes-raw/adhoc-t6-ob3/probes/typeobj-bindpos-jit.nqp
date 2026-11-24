sub inttype(int $bits, int $unsigned) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    my $h := nqp::hash('bits', $bits);
    if $unsigned { $h<unsigned> := 1 }
    nqp::composetype($t, nqp::hash('integer', $h));
    $t
}
sub MAIN($program, $case = 'read') {
    my $at := nqp::newtype(nqp::null(), 'VMArray');
    nqp::composetype($at, nqp::hash('array', nqp::hash('type', inttype(8, 1))));
    my $a := nqp::create($at);
    my int $i := 0; while $i < 64 { nqp::push_i($a, $i); $i++ }
    my $list := nqp::list($a, $at);
    my int $calls := 200000; my int $died := 0; my $msg := 'none'; my int $ret := 0; my $last := '';
    $i := 0;
    while $i < $calls {
        my int $k := $i >= $calls - 3 ?? 1 !! 0;
        try {
            if $case eq 'read' { $last := nqp::readuint(nqp::atpos($list, $k), 0, 0) }
            else { nqp::bindpos_i(nqp::atpos($list, $k), 0, 7) }
            $ret++;
            CATCH { $died++; $msg := nqp::getmessage($!) }
        }
        $i++;
    }
    say("$case: died $died returned $ret msg [$msg] last [$last]");
}
