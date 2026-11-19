# P3, every direction: a splice of a one-element source of each kind into an
# empty target of each kind, and a deletion through an empty source of each
# kind from a two-element target of each kind.
#
# Kinds: obj (nqp::list), str (nqp::list_s), int (nqp::list_i, int64), int8,
# uint8, uint64, num (nqp::list_n, num64), num32. Source elements: obj a list
# ("VMArray"), str "x", the int kinds 7, the num kinds 1.5.
#
# Part 1 (non-empty source): nqp::splice(target, source, 0, 0), then:
#   - for the pairs the P3 rule keeps (same register kind, str into obj, any
#     int/uint width into any other), prints "returned, <element 0 read in the
#     target's kind>" (obj: the element's REPR name);
#   - for the other pairs prints only "returned, elems N" and empties the
#     target with setelems (which zeroes the slot) before anything else can
#     run, so that a reinterpreted value is never read or marked;
#   - "DIED <message>" if the splice throws, then the target's elems.
# Part 2 (empty source): nqp::splice(target of 2 elements, empty source, 0, 1)
#   prints "elems 1" for every pair, before and after the fix.
#
# A correct VM (the P3 fix) prints, in part 1, "DIED MVMArray: Cannot splice
# <source register kind> elements into an array of <target register kind>
# elements" (elems 0) for: obj or str to or from any int/uint/num kind; obj
# into str; any int/uint kind to or from any num kind; and "returned" with
# the value for the others. Upstream returns for every pair.

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
sub arrtype($elem) {
    my $t := nqp::newtype(nqp::null(), 'VMArray');
    nqp::composetype($t, nqp::hash('array', nqp::hash('type', $elem)));
    $t
}

my @kinds := nqp::list('obj', 'str', 'int', 'int8', 'uint8', 'uint64', 'num', 'num32');
my %class := nqp::hash('obj', 'obj', 'str', 'str', 'int', 'i', 'int8', 'i', 'uint8', 'i',
    'uint64', 'i', 'num', 'n', 'num32', 'n');
my %type := nqp::hash('int8', arrtype(inttype(8, 0)), 'uint8', arrtype(inttype(8, 1)),
    'uint64', arrtype(inttype(64, 1)), 'num32', arrtype(numtype(32)));

sub make($k) {
    $k eq 'obj' ?? nqp::list() !! $k eq 'str' ?? nqp::list_s() !! $k eq 'int' ?? nqp::list_i()
        !! $k eq 'num' ?? nqp::list_n() !! nqp::create(%type{$k})
}
sub add($a, $k) {
    my $c := %class{$k};
    if $c eq 'obj' { nqp::push($a, nqp::list('o')) }
    elsif $c eq 'str' { nqp::push_s($a, 'x') }
    elsif $c eq 'i' { nqp::push_i($a, 7) }
    else { nqp::push_n($a, 1.5) }
}
sub read0($a, $k) {
    my $c := %class{$k};
    $c eq 'obj' ?? nqp::reprname(nqp::atpos($a, 0)) !! $c eq 'str' ?? nqp::atpos_s($a, 0)
        !! $c eq 'i' ?? ~nqp::atpos_i($a, 0) !! ~nqp::atpos_n($a, 0)
}
sub kept($s, $d) {
    my $cs := %class{$s}; my $cd := %class{$d};
    $cs eq $cd || ($cs eq 'str' && $cd eq 'obj')
}

say("part 1: one element, splice(target, source, 0, 0)");
for @kinds -> $s {
    for @kinds -> $d {
        my $src := make($s); add($src, $s);
        my $t := make($d);
        my $r;
        try {
            nqp::splice($t, $src, 0, 0);
            if kept($s, $d) { $r := 'returned, ' ~ read0($t, $d) }
            else { $r := 'returned, elems ' ~ nqp::elems($t); nqp::setelems($t, 0) }
            CATCH { $r := 'DIED ' ~ nqp::getmessage($!) ~ ' (elems ' ~ nqp::elems($t) ~ ')' }
        }
        say("$s -> $d: $r");
    }
}
nqp::force_gc();
say("part 2: empty source, splice(target of 2, empty, 0, 1)");
for @kinds -> $s {
    for @kinds -> $d {
        my $t := make($d); add($t, $d); add($t, $d);
        my $r;
        try { nqp::splice($t, make($s), 0, 1); $r := 'elems ' ~ nqp::elems($t); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
        say("$s -> $d: $r");
    }
}
say("done");
