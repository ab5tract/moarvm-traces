# OB2: a VMArray type object as the splice source. asplice does not check that
# the source is concrete and reads elems (and later the slots pointer) from the
# memory after the type object. From cfix-P-raw/round1/typeobj/typeobj.nqp.
# Before: a huge growth (killed by the 2G cap) or a copy from garbage.
# Fixed: "DIED MVMArray: Cannot splice from a type object", target unchanged.
my $a := nqp::list(1, 2, 3);
my $t := nqp::what(nqp::list());
say("source is concrete: " ~ nqp::isconcrete($t));
my $r;
try { nqp::splice($a, $t, 1, 0); $r := 'returned'; CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("splice from a type object: $r");
say("target elems after: " ~ nqp::elems($a));
