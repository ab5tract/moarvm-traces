# R1: composing an array type a second time ignores an object element type.
#
# compose (VMArray.c:1320-1333) stores the new element type in elem_type and
# calls spec_to_repr_data (1224-1319), which sets slot_type and elem_size
# only for the boxed primitives INT/UINT64, NUM and STR; for an object
# element type (BP_NONE) it changes nothing. The OBJ default is set once, in
# type_object_for (33-34) and deserialize_repr_data (1352-1353). So a type
# first composed with a native element type and then recomposed with an
# object element type keeps the native kind while elem_type says "object".
#
# The program: a VMArray type composed with int64 elements, recomposed with
# an object element type (BOOTHash, the hash type object), and new arrays of it
# (created after the recompose, so no live array changes kind here).
# A correct VM prints
#     push an object: returned, elems 1
#     push_i: DIED MVMArray: push expected object register
#     composed once: push an object: returned, elems 1
# (the last line is a type composed once with that element type). The
# bug: the array is still an int64 array:
#     push an object: DIED MVMArray: push expected int register
#     push_i: returned, elems 1
# Not a memory error: both builds print the same.

sub inttype(int $bits, int $unsigned) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    my $h := nqp::hash('bits', $bits);
    if $unsigned { $h<unsigned> := 1 }
    nqp::composetype($t, nqp::hash('integer', $h));
    $t
}
sub t($name, &code) {
    my $r;
    try { $r := code(); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
    say("$name: $r");
}

my $obj := nqp::what(nqp::hash());   # BOOTHash: an object type (BP_NONE)
my $ty := nqp::newtype(nqp::null(), 'VMArray');
nqp::composetype($ty, nqp::hash('array', nqp::hash('type', inttype(64, 0))));
nqp::composetype($ty, nqp::hash('array', nqp::hash('type', $obj)));
my $a := nqp::create($ty);
t('push an object', { nqp::push($a, nqp::list()); 'returned, elems ' ~ nqp::elems($a) });
my $b := nqp::create($ty);
t('push_i', { nqp::push_i($b, 5); 'returned, elems ' ~ nqp::elems($b) });

my $once := nqp::newtype(nqp::null(), 'VMArray');
nqp::composetype($once, nqp::hash('array', nqp::hash('type', $obj)));
my $c := nqp::create($once);
t('composed once: push an object', { nqp::push($c, nqp::list()); 'returned, elems ' ~ nqp::elems($c) });
