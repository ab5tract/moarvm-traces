# S1: a splice from the array itself copies overlapping ranges with memcpy.
#
# nqp::splice($a, $a, $offset, $count) ends in copy_elements(from = $a,
# dest = $a, 0, $offset, elems1) (VMArray.c:1120). For a kind copied on the
# fast path (every kind but STR, and OBJ unless the array is in gen2) that is
# memcpy(slots + offset, slots + 0, elems1 * elem_size) (VMArray.c:951): when
# 0 < offset < elems1 the ranges overlap, which is undefined behaviour.
#
# Each case fills a 10-element array with 1 4 7 ... 28 and splices it into
# itself: ($offset, $count) = (1, 0), (2, 3), (5, 0). What a correct VM prints
# (memmove semantics: the copy reads the array as it stands after the tail
# has been moved, and every element arrives as it was):
#     1,0  -> 1 1 4 7 10 13 16 19 22 25 28 4 7 10 13 16 19 22 25 28
#     2,3  -> 1 4 1 4 7 10 13 16 19 22 25 28 16 19 22 25 28
#     5,0  -> 1 4 7 10 13 1 4 7 10 13 16 19 22 25 28 16 19 22 25 28
# The "str" lines are the STR kind, which is copied element by element going
# forward (defined, not memcpy): it repeats the leading elements instead, and
# is printed for comparison only (see the report: whether that path should
# also copy as memmove does is a separate choice).
# The bug: the fast-path kinds print what this libc's memcpy leaves, which
# differs by element size (the plain build printed patterns that are neither
# the memmove result nor a forward copy, e.g. "1 1 4 4 7 10 10 10 19 22 28 ..."
# for i8 in campaign 8); the AddressSanitizer build stops at the first case
# with "memcpy-param-overlap" in copy_elements.

sub inttype(int $bits, int $unsigned) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    my $h := nqp::hash('bits', $bits);
    if $unsigned { $h<unsigned> := 1 }
    nqp::composetype($t, nqp::hash('integer', $h));
    $t
}
sub arrtype($elem) {
    my $t := nqp::newtype(nqp::null(), 'VMArray');
    nqp::composetype($t, nqp::hash('array', nqp::hash('type', $elem)));
    $t
}

sub show($name, $a) {
    my @p;
    my int $i := 0;
    while $i < nqp::elems($a) { nqp::push(@p, ~nqp::atpos($a, $i)); $i++ }
    say("$name: " ~ nqp::join(' ', @p));
}
sub showi($name, $a) {
    my @p;
    my int $i := 0;
    while $i < nqp::elems($a) { nqp::push(@p, ~nqp::atpos_i($a, $i)); $i++ }
    say("$name: " ~ nqp::join(' ', @p));
}

sub fill($a, $set) { my int $i := 0; while $i < 10 { $set($a, $i * 3 + 1); $i++ } }
for ((1, 0), (2, 3), (5, 0)) -> $c {
    my int $off := $c[0]; my int $cnt := $c[1];
    my $s := nqp::list_s();
    fill($s, -> $a, $v { nqp::push_s($a, ~$v) });
    nqp::splice($s, $s, $off, $cnt);
    my @p; my int $i := 0;
    while $i < nqp::elems($s) { nqp::push(@p, nqp::atpos_s($s, $i)); $i++ }
    say("str $off,$cnt: " ~ nqp::join(' ', @p));
    for (64, 32, 16, 8) -> $bits {
        my $a := nqp::create(arrtype(inttype($bits, 0)));
        fill($a, -> $a, $v { nqp::push_i($a, $v) });
        nqp::splice($a, $a, $off, $cnt);
        showi("i$bits $off,$cnt", $a);
    }
}

# Large arrays (other memcpy strategies): 9000 elements 0..8999, splice at
# offset 1, 3 and 4500 with count 0. Prints whether the result equals the
# memmove result (computed here element by element from a copy): a correct
# VM prints "same" on every line.
for (1, 3, 4500) -> $off {
    for (64, 32, 16, 8) -> $bits {
        my $a := nqp::create(arrtype(inttype($bits, 0)));
        my int $i := 0; while $i < 9000 { nqp::push_i($a, $i); $i++ }
        my $want := nqp::create(arrtype(inttype($bits, 0)));
        $i := 0; while $i < $off { nqp::push_i($want, nqp::atpos_i($a, $i)); $i++ }
        $i := 0; while $i < 9000 { nqp::push_i($want, nqp::atpos_i($a, $i)); $i++ }
        $i := $off; while $i < 9000 { nqp::push_i($want, nqp::atpos_i($a, $i)); $i++ }
        nqp::splice($a, $a, $off, 0);
        my int $bad := 0; my int $first := -1;
        $i := 0;
        while $i < nqp::elems($want) {
            if nqp::atpos_i($a, $i) != nqp::atpos_i($want, $i) { $first := $i if $first < 0; $bad++ }
            $i++
        }
        say("big i$bits off $off: " ~ ($bad ?? "differs in $bad elements, first at $first" !! 'same'));
    }
}
