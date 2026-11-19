# A VMArray type object as the splice source: asplice does not check that
# `from` is concrete, and elems reads the "body" of a type object.
my $a := nqp::list(1, 2, 3);
my $t := nqp::what(nqp::list());
say("source is concrete: " ~ nqp::isconcrete($t));
my $r;
try { nqp::splice($a, $t, 1, 0); $r := 'returned, elems ' ~ nqp::elems($a); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("splice from a type object: $r");
