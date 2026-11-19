my $a := nqp::list();
for <a b c d> { nqp::push($a, nqp::list($_)) }
nqp::shift($a); nqp::shift($a);
nqp::force_gc();
my @keep; my int $i := 0;
while $i < 2000 { nqp::push(@keep, nqp::list('filler', $i)); $i++ }
nqp::force_gc();
nqp::splice($a, $a, 0, 0);
my @p; for $a { nqp::push(@p, nqp::atpos($_, 0)) }
say(nqp::join(' ', @p));
