# Area K: the six integer kinds narrower than 8 bits (elem_size 0) can be
# composed into an array type, but no operation can store an element.
# Before: compose returns, push_i dies "MVMArray: Unhandled slot type".
# Fixed: compose dies "MVMArray: Cannot compose an array of N-bit integers,
# element types need at least 8 bits"; the type stays an object array, so
# push_i then dies "MVMArray: push expected object register".
sub int_type(int $bits, int $unsigned) {
    my $t := nqp::newtype(nqp::null(), "P6int");
    nqp::composetype($t, nqp::hash("integer", nqp::hash("bits", $bits, "unsigned", $unsigned)));
    $t
}
for (4, 2, 1, 8) -> $bits {
    for (1, 0) -> $unsigned {
        my $name := "bits $bits unsigned $unsigned";
        my $t := nqp::newtype(nqp::null(), "VMArray");
        my $r := 'returned';
        try { nqp::composetype($t, nqp::hash("array", nqp::hash("type", int_type($bits, $unsigned)))); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
        say("$name: compose: $r");
        my $a := nqp::create($t);
        $r := 'returned';
        try { nqp::push_i($a, 1); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
        say("$name: push_i: $r; elems " ~ nqp::elems($a));
    }
}
