my $t := nqp::list(1,2,3);
try { nqp::splice($t, nqp::null(), 1, 0); say('spliced ' ~ nqp::elems($t)); CATCH { say('DIED ' ~ nqp::getmessage($!) ~ ' elems ' ~ nqp::elems($t)) } }
my $t2 := nqp::list(1,2,3);
try { nqp::splice($t2, nqp::null(), 1, 2); say('spliced ' ~ nqp::elems($t2)); CATCH { say('DIED ' ~ nqp::getmessage($!) ~ ' elems ' ~ nqp::elems($t2)) } }
my $t3 := nqp::list_i(1,2,3);
try { nqp::splice($t3, nqp::null(), 0, 0); say('spliced ' ~ nqp::elems($t3)); CATCH { say('DIED ' ~ nqp::getmessage($!) ~ ' elems ' ~ nqp::elems($t3)) } }
try { my $s := nqp::slice(nqp::null(), 0, 0); say('sliced'); CATCH { say('DIED slice ' ~ nqp::getmessage($!)) } }
say('done');
