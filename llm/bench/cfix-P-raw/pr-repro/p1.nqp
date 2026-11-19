my $a := nqp::list('a', 'b', 'c');
my $r;
try { nqp::splice($a, nqp::hash('k', 1), 1, 0); $r := 'returned'; CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("splice from a hash: $r");
say("elems " ~ nqp::elems($a) ~ ": " ~ nqp::join(' ', $a));
nqp::splice($a, nqp::hash(), 1, 1);
say("delete through an empty hash: " ~ nqp::join(' ', $a));
