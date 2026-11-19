# P2 qualification: a storage-less target that has to grow (a fresh uint4
# array, ssize 0) dies in set_size_internal's zero_slots before copy_elements,
# so it never reached abort() (the case that does is a storage-less target
# within its storage, after recomposing a live array: P2-splice-no-storage-kind.nqp).
sub inttype(int $bits, int $unsigned) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    my $h := nqp::hash('bits', $bits);
    if $unsigned { $h<unsigned> := 1 }
    nqp::composetype($t, nqp::hash('integer', $h));
    $t
}
my $ty := nqp::newtype(nqp::null(), 'VMArray');
nqp::composetype($ty, nqp::hash('array', nqp::hash('type', inttype(4, 1))));
my $a := nqp::create($ty);
my $r;
try { nqp::splice($a, nqp::list_i(9), 0, 0); $r := 'returned'; CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("splice into a fresh uint4 array: $r");
