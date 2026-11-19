sub inttype(int $bits, int $unsigned) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    my $h := nqp::hash('bits', $bits);
    if $unsigned { $h<unsigned> := 1 }
    nqp::composetype($t, nqp::hash('integer', $h));
    $t
}
my $ty := nqp::newtype(nqp::null(), 'VMArray');
nqp::composetype($ty, nqp::hash('array', nqp::hash('type', inttype(8, 0))));
my $a := nqp::create($ty);
nqp::push_i($a, 1); nqp::push_i($a, 4); nqp::push_i($a, 7);
nqp::composetype($ty, nqp::hash('array', nqp::hash('type', inttype(4, 1))));
my $r;
try { nqp::splice($a, nqp::list_i(), 1, 1); $r := 'returned'; CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("delete one with an empty source: $r, elems " ~ nqp::elems($a));
