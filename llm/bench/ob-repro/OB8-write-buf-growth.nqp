# OB8: write_buf grows the array to offset + count elements, count being in
# bytes. Program from cfix-open-bugs.md OB8. Before: a uint16 array of 3 with
# an 8-byte write at element 1 has elems 9 (1 1800 1286 772 258 0 0 0 0); an
# empty int64 array with an 8-byte write has elems 8. Fixed: elems 5
# (1 1800 1286 772 258) and elems 1 (7).
sub int_array_type(int $bits, int $unsigned) {
    my $e := nqp::newtype(nqp::null(), "P6int");
    nqp::composetype($e, nqp::hash("integer", nqp::hash("bits", $bits, "unsigned", $unsigned)));
    my $t := nqp::newtype(nqp::null(), "VMArray"); nqp::composetype($t, nqp::hash("array", nqp::hash("type", $e)));
    $t
}
sub show($a) {
    my $parts := nqp::list_s(); my int $i := 0;
    while $i < nqp::elems($a) { nqp::push_s($parts, nqp::coerce_is(nqp::atpos_i($a, $i))); $i++ }
    "elems " ~ nqp::elems($a) ~ ": " ~ nqp::join(" ", $parts)
}
sub case($name, $a, int $offset, int $value, int $flags) {
    my $r := 'returned';
    try { nqp::writeint($a, $offset, $value, $flags); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
    say("$name: $r; " ~ show($a));
}
my $a := nqp::create(int_array_type(16, 1)); nqp::push_i($a, 1); nqp::push_i($a, 2); nqp::push_i($a, 3);
case('uint16 array 1 2 3, writeint offset 1, 8 bytes (flags 13)', $a, 1, 0x0102030405060708, 13);
case('empty int64 array, writeint offset 0, 8 bytes (flags 13)', nqp::list_i(), 0, 7, 13);
my $c := nqp::create(int_array_type(32, 1)); nqp::push_i($c, 1);
case('uint32 array 1, writeint offset 1, 2 bytes (flags 5)', $c, 1, 0x0102, 5);
my $d := nqp::create(int_array_type(16, 1)); nqp::push_i($d, 1); nqp::push_i($d, 2); nqp::push_i($d, 3);
case('uint16 array 1 2 3, writeint offset 1, 4 bytes, no growth needed (control)', $d, 1, 0x01020304, 9);
