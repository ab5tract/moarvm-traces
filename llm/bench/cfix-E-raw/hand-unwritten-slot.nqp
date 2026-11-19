my $t := nqp::newtype(nqp::null(), 'VMArray');
my $e := nqp::newtype(nqp::null(), 'P6int');
nqp::composetype($e, nqp::hash('integer', nqp::hash('bits', 32, 'unsigned', 1)));
nqp::composetype($t, nqp::hash('array', nqp::hash('type', $e)));
my $in := nqp::create($t); nqp::push_i($in, 101); nqp::push_i($in, 769); nqp::push_i($in, 97);
my $a := nqp::create($t);
nqp::normalizecodes($in, nqp::const::NORMALIZE_NFC, $a);
nqp::setelems($a, 3);
say("normalized 233 97, setelems 3: element 2 = " ~ nqp::atpos_i($a, 2));
