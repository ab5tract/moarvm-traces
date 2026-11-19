# T3: a self-splice at offset 0 on an array with start > 0 makes the
# shifted-off slots elements again.
#
# asplice at offset 0 (VMArray.c:1065-1082) moves start back by up to
# elems1 - count slots and widens count to match, so the incoming elements
# will overwrite the slots in front of the old start. When the source is the
# array itself, the copy (copy_elements(root, root, 0, 0, elems1),
# VMArray.c:1120) reads from the new start, i.e. from the slots shift left
# behind, and copies them onto themselves: they become elements 0 .. n-1.
# For OBJ and STR those slots hold pointers the collector stopped tracking
# when they were shifted off (shift does not clear them).
#
# The program: an object array of four lists a b c d; two shifts (the
# returned a and b are dropped); two collections with allocation in between;
# nqp::splice($a, $a, 0, 0) (prepend the array to itself); then the
# elements are inspected. Run with "control" to splice from nqp::clone($a)
# instead: the same start adjustment, but the copy comes from another array.
#
# A correct VM prints
#     elems 4: c d c d
# The bug: elements 0 and 1 are the stale pointers to the dead a and b:
# a SIGSEGV (or other objects) when they are used. The control prints
# "c d c d" on both builds.

sub MAIN($prog, $mode = 'case') {
    my $a := nqp::list();
    for <a b c d> { nqp::push($a, nqp::list($_, 1)) }
    nqp::shift($a); nqp::shift($a);
    nqp::force_gc();
    my @keep; my int $i := 0;
    while $i < 2000 { nqp::push(@keep, nqp::list('filler', $i, $i)); $i++ }
    nqp::force_gc();
    $i := 0;
    while $i < 2000 { nqp::push(@keep, nqp::hash('h', $i)); $i++ }
    say("collections done");
    nqp::splice($a, $mode eq 'control' ?? nqp::clone($a) !! $a, 0, 0);
    say("spliced: elems " ~ nqp::elems($a));
    my @p;
    $i := 0;
    while $i < nqp::elems($a) {
        my $e := nqp::atpos($a, $i);
        nqp::push(@p, nqp::isnull($e) ?? 'null' !! nqp::reprname($e) eq 'VMArray' ?? nqp::atpos($e, 0) !! nqp::reprname($e));
        $i++
    }
    say("elems " ~ nqp::elems($a) ~ ": " ~ nqp::join(' ', @p));
}
