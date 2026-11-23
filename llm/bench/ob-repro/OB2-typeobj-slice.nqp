# OB2, the slice side (Task 3, area Y): nqp::slice does not check that the
# array sliced from is concrete (interp.c OP(slice)), and aslice read the
# type object's elems from the memory after it.
# Before: a segfault. Fixed: "DIED MVMArray: Cannot slice from a type object".
my $array_type := nqp::what(nqp::list(1, 2, 3));
my $outcome := 'returned';
try { my $sliced := nqp::slice($array_type, 0, 0); $outcome := 'returned, elems ' ~ nqp::elems($sliced); CATCH { $outcome := 'DIED ' ~ nqp::getmessage($!) } }
say("slice of a type object: $outcome");
