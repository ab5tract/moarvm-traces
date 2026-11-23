# Found in Task 5 (area Z): a splice at offset 0 that removes every element
# (count >= elems) resets the window to start 0, elems 0, without clearing
# the slots the elements were in (asplice's offset-0 adjustment), so growth
# within the storage afterwards (setelems, a bindpos past the end) brings the
# removed elements back. For an object array they are pointers the collector
# no longer tracks; the program does not collect, and prints them right away.
# Before: 11 22 33 44, and a b. Fixed (area Z zeroes what growth within the
# storage exposes): 0 0 0 0, and <null> <null>.
my $ints := nqp::list_i(11, 22, 33, 44);
nqp::splice($ints, nqp::list_i(), 0, 4);
say("int: after splice(0, 4) elems " ~ nqp::elems($ints));
nqp::setelems($ints, 4);
say("int: setelems 4: " ~ nqp::atpos_i($ints, 0) ~ " " ~ nqp::atpos_i($ints, 1) ~ " " ~ nqp::atpos_i($ints, 2) ~ " " ~ nqp::atpos_i($ints, 3));
sub shown($o) { nqp::isnull($o) ?? '<null>' !! $o }
my $objs := nqp::list('a', 'b', 'c');
nqp::splice($objs, nqp::list(), 0, 3);
say("obj: after splice(0, 3) elems " ~ nqp::elems($objs));
nqp::bindpos($objs, 2, 'z');
say("obj: bindpos 2: " ~ shown(nqp::atpos($objs, 0)) ~ " " ~ shown(nqp::atpos($objs, 1)) ~ " " ~ shown(nqp::atpos($objs, 2)));
