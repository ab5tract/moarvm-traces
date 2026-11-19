# T1: a rejected pop has already dropped the element, and the slot it leaves
# still holds a pointer the collector no longer tracks.
#
# pop (VMArray.c:648-725) decrements elems (658) before it checks the
# register kind, and the kind check throws before zero_slots (723) clears
# the slot. So nqp::pop_i on an object array dies with "pop expected object
# register" and the array has lost its last element; the slot still holds
# the object pointer, but VMArray_gc_mark only marks the first elems slots,
# so a collection frees or moves the object without updating the slot.
# Growing back within ssize (set_size_internal, VMArray.c:431-435: no
# zeroing when n <= ssize) makes the stale pointer an element again.
#
# The program: an object array of two lists, the second referenced only by
# the array; a rejected pop_i; two collections (the second reuses the
# nursery half the dead list lived in) and some allocation; setelems back to
# 2; then element 1 is inspected.
#
# Run with no argument for the case, or with "control" to drop the element
# with nqp::setelems($a, 1) instead (which clears the slot) and do the same
# steps: element 1 is then null and the run ends normally, which shows the
# crash below comes from the stale slot.
#
# A correct VM prints
#     pop_i: DIED MVMArray: pop expected object register
#     elems now: 2
#     collections done
#     grown back: elems 2
#     element 1: VMArray, elems 3, first "second"
# The bug: elems is 1 after the rejected pop, and element 1 after growing
# back is whatever the stale pointer now points at: here a SIGSEGV when it is
# used (ASAN: a SEGV in MVM_interp_run near address zero; ASAN cannot see
# the stale read itself, the nursery being one MoarVM-managed allocation).

sub MAIN($prog, $mode = 'case') {
my $a := nqp::list();
nqp::push($a, nqp::list('first', 1, 2));
nqp::push($a, nqp::list('second', 3, 4));
my $r;
if $mode eq 'control' { nqp::setelems($a, 1); say("control: setelems 1") }
else {
    try { nqp::pop_i($a); $r := 'returned'; CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
    say("pop_i: $r");
}
say("elems now: " ~ nqp::elems($a));
nqp::force_gc();
my @keep; my int $i := 0;
while $i < 2000 { nqp::push(@keep, nqp::list('filler', $i, $i)); $i++ }
nqp::force_gc();
$i := 0;
while $i < 2000 { nqp::push(@keep, nqp::hash('h', $i)); $i++ }
say("collections done");
nqp::setelems($a, 2);
say("grown back: elems " ~ nqp::elems($a));
my $e := nqp::atpos($a, 1);
if nqp::isnull($e) { say("element 1: null") }
else {
    my $desc := nqp::reprname($e);
    if $desc eq 'VMArray' { $desc := $desc ~ ', elems ' ~ nqp::elems($e) ~ ', first "' ~ nqp::atpos($e, 0) ~ '"' }
    say("element 1: $desc");
}
}
