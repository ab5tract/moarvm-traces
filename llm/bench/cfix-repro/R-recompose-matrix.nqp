# R1/X1, every pair: a VMArray type composed with element kind A (or never
# composed with an element type: "none"), an array of it alive with two
# elements, then a second compose with element kind B.
#
# Kinds: none, obj (BOOTHash type object), obj2 (another object type: a
# P6opaque class from nqp::newtype), int8, uint8, int64, uint64, num64, str.
# Elements pushed before the second compose: obj/obj2 two lists holding 5
# and 6, int kinds 5 and 6, num64 5.5 and 6.5, str "x" and "y"; for "none"
# two lists are pushed, then setelems 0 (empty, with storage). The fresh
# array's element is 7 (list, int, 7.5 or "z").
#
# For each pair the program prints the second compose's result ("allowed" or
# DIED <message>), then
#   live:  elems and each element of the live array, read in the kind the
#          type has now (for an allowed none -> B compose the array is empty);
#   fresh: a new array of the type, one element of the kind it has now
#          pushed and read back.
# For the type's kind "now" the program uses B when the compose returned,
# A when it died.
#
# The fix (option b): once an element type has been composed, a compose that
# changes the slot type or the element size dies with "MVMArray: Type ... is
# already composed with another element kind" and the live array and the
# type are unchanged; same-kind recomposes (A == B, obj <-> obj2) and every
# compose of a "none" type are allowed. Upstream allows every pair: arrays
# alive at the recompose are read as the new kind (X1 when it is wider:
# reads past the storage; this program avoids those reads, see below), and a
# recompose to an object type keeps the old native kind (R1: the fresh array
# refuses an object).
#
# To stay memory-safe on upstream, each pair is first tried on a probe type
# with no arrays. If that compose is allowed and changes the element class
# or size (on upstream: every such pair), the live array is made empty (two
# elements pushed, then setelems 0, so it has storage but nothing to read or
# mark), and the live line shows "elems 0". Otherwise it holds the two
# elements. Every read is in a try, so a read the array refuses prints DIED.
# Arrays are kept referenced until the end.

sub inttype(int $bits, int $unsigned) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    my $h := nqp::hash('bits', $bits);
    if $unsigned { $h<unsigned> := 1 }
    nqp::composetype($t, nqp::hash('integer', $h));
    $t
}
sub numtype(int $bits) {
    my $t := nqp::newtype(nqp::null(), 'P6num');
    nqp::composetype($t, nqp::hash('float', nqp::hash('bits', $bits)));
    $t
}
sub strtype() {
    my $t := nqp::newtype(nqp::null(), 'P6str');
    nqp::composetype($t, nqp::hash());
    $t
}
my $obj2 := nqp::newtype(nqp::null(), 'P6opaque');
nqp::composetype($obj2, nqp::hash('attribute', nqp::list()));

my @kinds := nqp::list('none', 'obj', 'obj2', 'int8', 'uint8', 'int64', 'uint64', 'num64', 'str');
my %elem := nqp::hash(
    'obj', nqp::what(nqp::hash()), 'obj2', $obj2,
    'int8', inttype(8, 0), 'uint8', inttype(8, 1), 'int64', inttype(64, 0),
    'uint64', inttype(64, 1), 'num64', numtype(64), 'str', strtype());
my %class := nqp::hash('none', 'o', 'obj', 'o', 'obj2', 'o', 'int8', 'i', 'uint8', 'i',
    'int64', 'i', 'uint64', 'i', 'num64', 'n', 'str', 's');
my %size := nqp::hash('none', 8, 'obj', 8, 'obj2', 8, 'int8', 1, 'uint8', 1,
    'int64', 8, 'uint64', 8, 'num64', 8, 'str', 8);

sub push1($a, $c, int $v) {
    if    $c eq 'o' { nqp::push($a, nqp::list($v)) }
    elsif $c eq 'i' { nqp::push_i($a, $v) }
    elsif $c eq 'n' { nqp::push_n($a, nqp::add_n($v, 0.5)) }
    else            { nqp::push_s($a, nqp::chr(115 + $v)) }
}
sub read1($a, $c, int $i) {
    if    $c eq 'o' { my $e := nqp::atpos($a, $i); nqp::isnull($e) ?? 'null' !! nqp::reprname($e) ~ '(' ~ nqp::atpos($e, 0) ~ ')' }
    elsif $c eq 'i' { ~nqp::atpos_i($a, $i) }
    elsif $c eq 'n' { ~nqp::atpos_n($a, $i) }
    else            { nqp::atpos_s($a, $i) }
}
sub show($a, $c) {
    my @p; my int $i := 0;
    while $i < nqp::elems($a) { nqp::push(@p, read1($a, $c, $i)); $i++ }
    'elems ' ~ nqp::elems($a) ~ (nqp::elems(@p) ?? ': ' ~ nqp::join(' ', @p) !! '')
}

my @keep;
sub compose2($ty, $ka, $kb) {
    nqp::composetype($ty, nqp::hash('array', nqp::hash('type', %elem{$ka}))) unless $ka eq 'none';
    my $r;
    try { nqp::composetype($ty, nqp::hash('array', nqp::hash('type', %elem{$kb}))); $r := 'allowed';
          CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
    $r
}
for @kinds -> $ka {
    for @kinds -> $kb {
        next if $kb eq 'none';
        my $ca := %class{$ka};
        my $cb := %class{$kb};
        my int $changes := $ka eq 'none' || $ca ne $cb || %size{$ka} != %size{$kb};
        my $probe := compose2(nqp::newtype(nqp::null(), 'VMArray'), $ka, $kb);
        my int $empty := $ka eq 'none' || ($probe eq 'allowed' && $changes);
        my $ty := nqp::newtype(nqp::null(), 'VMArray');
        nqp::composetype($ty, nqp::hash('array', nqp::hash('type', %elem{$ka}))) unless $ka eq 'none';
        my $a := nqp::create($ty);
        nqp::push(@keep, $a);
        push1($a, $ca, 5); push1($a, $ca, 6);
        if $empty { nqp::setelems($a, 0) }
        my $r;
        try { nqp::composetype($ty, nqp::hash('array', nqp::hash('type', %elem{$kb}))); $r := 'allowed';
              CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
        my $cn := %class{$r eq 'allowed' ?? $kb !! $ka};
        my $live;
        try { $live := show($a, $cn); CATCH { $live := 'DIED ' ~ nqp::getmessage($!) } }
        my $f := nqp::create($ty);
        nqp::push(@keep, $f);
        my $fr;
        try { push1($f, $cn, 7); $fr := show($f, $cn); CATCH { $fr := 'DIED ' ~ nqp::getmessage($!) } }
        say("$ka -> $kb: $r; live $live; fresh $fr");
    }
}
say("done");
