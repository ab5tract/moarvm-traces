sub int_type(int $bits) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    nqp::composetype($t, nqp::hash('integer', nqp::hash('bits', $bits)));
    $t
}
sub compose($type, $elem, $what) {
    my $r := 'returned';
    try { nqp::composetype($type, nqp::hash('array', nqp::hash('type', $elem)));
          CATCH { $r := 'died: ' ~ nqp::getmessage($!) } }
    say("$what: $r");
}

# An int8 array alive when its type is recomposed to int64.
my $t1 := nqp::newtype(nqp::null(), 'VMArray');
nqp::setdebugtypename($t1, 'Bytes');
compose($t1, int_type(8), 'compose with int8');
my $a := nqp::create($t1);
nqp::push_i($a, 1); nqp::push_i($a, 4); nqp::push_i($a, 7);
compose($t1, int_type(64), 'recompose with int64');
nqp::setelems($a, 8);
say("elems " ~ nqp::elems($a) ~ ", element 2: " ~ nqp::atpos_i($a, 2) ~ ", element 7: " ~ nqp::atpos_i($a, 7));

# A type composed with int64, recomposed with an object type.
my $t2 := nqp::newtype(nqp::null(), 'VMArray');
nqp::setdebugtypename($t2, 'Ints');
compose($t2, int_type(64), 'compose with int64');
compose($t2, nqp::what(nqp::hash()), 'recompose with an object type');
my $b := nqp::create($t2);
my $r := 'returned';
try { nqp::push($b, nqp::hash()); CATCH { $r := 'died: ' ~ nqp::getmessage($!) } }
say("push an object: $r");

# Same kind again, and the first compose of a type without an element type.
compose($t2, int_type(64), 'recompose with another int64 type');
my $t3 := nqp::newtype(nqp::null(), 'VMArray');
compose($t3, int_type(8), 'first compose of a fresh type with int8');
