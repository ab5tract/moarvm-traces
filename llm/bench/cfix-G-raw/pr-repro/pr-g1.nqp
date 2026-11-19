my $a := nqp::list_i();
nqp::setelems($a, 8192);
my $r;
try { nqp::setelems($a, -4096); $r := 'returned, elems ' ~ nqp::elems($a); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("setelems(2**64 - 4096): $r");
say("still alive: elems " ~ nqp::elems($a));
say("element 1000000000: " ~ nqp::atpos_i($a, 1000000000));
