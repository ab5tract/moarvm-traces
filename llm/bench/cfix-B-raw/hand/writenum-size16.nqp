# Seen on the way (not fixed here): writenum has no size check; its default
# arm (any size but 4) copies `size` bytes from an 8-byte local. flags 16:
# size 1 << 4 = 16. The interpreter path, no JIT needed.
sub inttype(int $bits, int $unsigned) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    my $h := nqp::hash('bits', $bits);
    if $unsigned { $h<unsigned> := 1 }
    nqp::composetype($t, nqp::hash('integer', $h));
    $t
}
my $at := nqp::newtype(nqp::null(), 'VMArray');
nqp::composetype($at, nqp::hash('array', nqp::hash('type', inttype(8, 1))));
my $a := nqp::create($at);
nqp::writenum($a, 0, 1.5, 16);
say("elems " ~ nqp::elems($a));
