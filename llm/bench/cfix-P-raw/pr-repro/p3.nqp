sub try-splice($name, $target, $source) {
    my $r;
    try { nqp::splice($target, $source, 0, 0); $r := 'returned'; CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
    say("$name: $r, elems " ~ nqp::elems($target));
}
my $i := nqp::list_i();
try-splice('obj into int', $i, nqp::list(nqp::hash()));
say("  element 0: " ~ nqp::atpos_i($i, 0)) if nqp::elems($i);
my $n := nqp::list_n();
try-splice('int into num', $n, nqp::list_i(4607182418800017408));
say("  element 0: " ~ nqp::atpos_n($n, 0)) if nqp::elems($n);
my $s := nqp::list_s();
try-splice('obj into str', $s, nqp::list(nqp::hash()));
nqp::setelems($s, 0);
# kept as they are
my $o := nqp::list();
try-splice('str into obj', $o, nqp::list_s('x'));
say("  element 0: " ~ nqp::reprname(nqp::atpos($o, 0)));
my $u8t := nqp::newtype(nqp::null(), 'P6int');
nqp::composetype($u8t, nqp::hash('integer', nqp::hash('bits', 8, 'unsigned', 1)));
my $buft := nqp::newtype(nqp::null(), 'VMArray');
nqp::composetype($buft, nqp::hash('array', nqp::hash('type', $u8t)));
my $buf := nqp::create($buft);
try-splice('int into uint8', $buf, nqp::list_i(65, 300));
say("  elements: " ~ nqp::atpos_i($buf, 0) ~ ' ' ~ nqp::atpos_i($buf, 1));
my $strs := nqp::list_s('a', 'b', 'c');
nqp::splice($strs, nqp::list(), 1, 1);
say("delete from str through an empty obj list: " ~ nqp::join(' ', $strs));
nqp::splice($buf, nqp::list_n(), 0, 1);
say("delete from uint8 through an empty num list: elems " ~ nqp::elems($buf));
# last, because before the change the collector crashes on it
my $o2 := nqp::list();
try-splice('int into obj', $o2, nqp::list_i(280267669825));
nqp::force_gc();
say("survived a collection");
