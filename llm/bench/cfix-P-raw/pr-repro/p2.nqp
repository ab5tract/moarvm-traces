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
# recompose the live array's type to a 4-bit element type (elem_size 0)
nqp::composetype($ty, nqp::hash('array', nqp::hash('type', inttype(4, 1))));
my $r;
try { nqp::splice($a, nqp::list_i(9), 1, 0); $r := 'returned'; CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("splice into it: $r, elems " ~ nqp::elems($a));
try { nqp::splice(nqp::list_i(5, 6), $a, 1, 0); $r := 'returned'; CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("splice from it: $r");
