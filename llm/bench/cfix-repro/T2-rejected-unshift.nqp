# T2: a rejected unshift after a shift has already moved start back over the
# shifted-off slot, which still holds a pointer the collector stopped
# tracking.
#
# shift (VMArray.c:826-902) moves start forward without clearing the slot it
# leaves. unshift (VMArray.c:727-824), when start > 0, decrements start
# (757) before it checks the register kind; the check throws before the
# store and before elems++ (822). So nqp::unshift_i on an object array dies
# with "unshift expected object register" and leaves the array one slot to
# the left: element 0 is the slot shift left behind, and the last element
# drops out of the window (and out of what VMArray_gc_mark marks).
#
# The program: an object array of three lists ("a", "b", "c"); shift (the
# returned "a" is dropped, so only the stale slot refers to it); two
# collections with allocation in between (the second reuses the nursery
# half "a" lived in); a rejected unshift_i; then element 0 is inspected.
# Run with "control" to skip the rejected unshift: the array is then b c.
#
# A correct VM prints
#     unshift_i: DIED MVMArray: unshift expected object register
#     elems 2, element 1 is "c"
#     element 0: VMArray, first "b"
# The bug: the window has moved: element 1 is "b", "c" is no longer an
# element, and element 0 is the stale pointer to the dead "a": a SIGSEGV
# or another object when it is used.

sub MAIN($prog, $mode = 'case') {
    my $a := nqp::list();
    nqp::push($a, nqp::list('a', 1)); nqp::push($a, nqp::list('b', 2)); nqp::push($a, nqp::list('c', 3));
    nqp::shift($a);
    nqp::force_gc();
    my @keep; my int $i := 0;
    while $i < 2000 { nqp::push(@keep, nqp::list('filler', $i, $i)); $i++ }
    nqp::force_gc();
    $i := 0;
    while $i < 2000 { nqp::push(@keep, nqp::hash('h', $i)); $i++ }
    say("collections done");
    if $mode ne 'control' {
        my $r;
        try { nqp::unshift_i($a, 7); $r := 'returned'; CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
        say("unshift_i: $r");
    }
    say("elems " ~ nqp::elems($a) ~ ', element 1 is "' ~ nqp::atpos(nqp::atpos($a, 1), 0) ~ '"');
    my $e := nqp::atpos($a, 0);
    say("element 0: " ~ (nqp::isnull($e) ?? 'null' !! nqp::reprname($e) ~ (nqp::reprname($e) eq 'VMArray' ?? ', first "' ~ nqp::atpos($e, 0) ~ '"' !! '')));
}
