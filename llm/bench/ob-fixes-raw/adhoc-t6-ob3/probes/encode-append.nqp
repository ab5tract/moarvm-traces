sub inttype(int $bits, int $unsigned) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    my $h := nqp::hash('bits', $bits);
    if $unsigned { $h<unsigned> := 1 }
    nqp::composetype($t, nqp::hash('integer', $h));
    $t
}
for (8, 16, 32) -> $bits {
    my $at := nqp::newtype(nqp::null(), 'VMArray');
    nqp::composetype($at, nqp::hash('array', nqp::hash('type', inttype($bits, 1))));
    my $b := nqp::create($at); nqp::push_i($b, 7);
    my int $i := 0;
    while $i < 20000 { nqp::encode("abc", "utf8", $b); $i++ }
    my $parts := nqp::list_s(); my int $j := 0;
    while $j < 7 { nqp::push_s($parts, ~nqp::atpos_i($b, $j)); $j++ }
    say("uint$bits: append 20000 x abc to [7]: elems " ~ nqp::elems($b) ~ ", first " ~ nqp::join(" ", $parts));
}
