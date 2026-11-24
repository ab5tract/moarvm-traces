# OB21 through a reallocation (Task 5 fix round 1; the review's
# /tmp/claude-1000/rv5/prog/Zgap-shift-realloc.nqp). A splice at offset 0
# removing every element leaves the removed elements in their slots; a push
# and a shift then leave start 1, elems 0. A growth past ssize first moves
# the window to start 0 (zeroing only the slots the old window held) and
# then reallocates, zeroing the new room only from the old ssize, so the slots
# between the old window's end and the old ssize kept the removed elements,
# which became elements again (for the object array, pointers the
# collector no longer marks).
# Before: int `0 22 33 44 0 0 0 0` twice; obj `<null> b c <null>`.
# Fixed: zeros and <null> everywhere.
my $ints := nqp::list_i(11, 22, 33, 44);
nqp::splice($ints, nqp::list_i(), 0, 4);
nqp::push_i($ints, 5);
nqp::shift_i($ints);
say("int: elems " ~ nqp::elems($ints));
nqp::setelems($ints, 20);
my $s := "int: setelems 20:";
my int $i := 0;
while $i < 8 { $s := $s ~ " " ~ nqp::atpos_i($ints, $i); $i++ }
say($s);
# bindpos variant
my $b := nqp::list_i(11, 22, 33, 44);
nqp::splice($b, nqp::list_i(), 0, 4);
nqp::push_i($b, 5);
nqp::shift_i($b);
nqp::bindpos_i($b, 19, 7);
$s := "int: bindpos 19:";
$i := 0;
while $i < 8 { $s := $s ~ " " ~ nqp::atpos_i($b, $i); $i++ }
say($s);
sub shown($o) { nqp::isnull($o) ?? '<null>' !! $o }
my $objs := nqp::list('a', 'b', 'c');
nqp::splice($objs, nqp::list(), 0, 3);
nqp::push($objs, 'p');
nqp::shift($objs);
nqp::setelems($objs, 20);
say("obj: setelems 20: " ~ shown(nqp::atpos($objs, 0)) ~ " " ~ shown(nqp::atpos($objs, 1)) ~ " " ~ shown(nqp::atpos($objs, 2)) ~ " " ~ shown(nqp::atpos($objs, 3)));
