# B3 without a recompose (from the Task 4 review): a VMArray type that has an
# array (object slots, 3 elements, 8 slots of storage) before its *first*
# compose with an element type, then composed with uint4 (elem_size 0), then
# three 8-byte writeint calls (at 0, 8, 0). A first compose is allowed
# whatever the kind, so this array has storage under a storage-less kind
# with or without the recompose refusal.
# A correct VM refuses every write and keeps elems 3. Upstream (and any build
# without the write_buf kind check): the first write returns (elems 8), the
# second dies "Unhandled slot type" after reallocating the slots to 0 bytes,
# the third writes through the pointer realloc left (SIGSEGV on address 0
# under AddressSanitizer).
sub int_type(int $bits, int $u) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    nqp::composetype($t, nqp::hash('integer', nqp::hash('bits', $bits, 'unsigned', $u)));
    $t
}
# Type used before its first compose: live array with object slots.
my $t := nqp::newtype(nqp::null(), 'VMArray');
my $a := nqp::create($t);
nqp::push($a, nqp::hash()); nqp::push($a, nqp::hash()); nqp::push($a, nqp::hash());
my $r := 'returned';
try { nqp::composetype($t, nqp::hash('array', nqp::hash('type', int_type(4, 1)))); CATCH { $r := 'died: ' ~ nqp::getmessage($!) } }
say("first compose to uint4 with live array: $r");
sub try_write($a, int $off) {
    my $r := 'returned';
    try { nqp::writeint($a, $off, 1, 12); CATCH { $r := 'died: ' ~ nqp::getmessage($!) } }
    say("write at $off: $r; elems " ~ nqp::elems($a));
}
try_write($a, 0); try_write($a, 8); try_write($a, 0);
