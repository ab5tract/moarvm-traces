my $a := nqp::list('a', 'b', 'c');
try { nqp::pop_i($a); CATCH { say('pop_i: ' ~ nqp::getmessage($!)) } }
say('after: elems ' ~ nqp::elems($a) ~ ': ' ~ nqp::join(' ', $a));
my $b := nqp::list('a', 'b', 'c', 'd');
my $shifted := nqp::shift($b);
try { nqp::unshift_i($b, 7); CATCH { say('unshift_i: ' ~ nqp::getmessage($!)) } }
say('after: elems ' ~ nqp::elems($b) ~ ': ' ~ nqp::join(' ', $b));
