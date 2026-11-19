sub u32_array() {
    my $int := nqp::newtype(nqp::null(), 'P6int');
    nqp::composetype($int, nqp::hash('integer', nqp::hash('bits', 32, 'unsigned', 1)));
    my $t := nqp::newtype(nqp::null(), 'VMArray');
    nqp::composetype($t, nqp::hash('array', nqp::hash('type', $int)));
    $t
}
sub rss_kb() {
    for nqp::split("\n", slurp('/proc/self/status')) {
        return +nqp::substr($_, 6) if nqp::eqat($_, 'VmRSS:', 0);
    }
    0
}
my $u32 := u32_array();

# normalizecodes: e, combining acute, a -> NFC é a
my $in := nqp::create($u32);
nqp::push_i($in, 101); nqp::push_i($in, 769); nqp::push_i($in, 97);
my $out := nqp::create($u32);
nqp::normalizecodes($in, nqp::const::NORMALIZE_NFC, $out);
say("normalized: " ~ nqp::elems($out) ~ " elements: " ~ nqp::atpos_i($out, 0) ~ " " ~ nqp::atpos_i($out, 1));
my int $i := 0;
while $i < 300 { nqp::push_i($out, $i); $i++ }
my int $ok := 1;
$i := 0;
while $i < 300 { $ok := 0 unless nqp::atpos_i($out, $i + 2) == $i; $i++ }
say("after 300 pushes: " ~ nqp::elems($out) ~ " elements, " ~ ($ok ?? "all read back" !! "some read back wrong"));

# strtocodes into an array that already has storage
my $a := nqp::create($u32);
nqp::force_gc();
my int $before := rss_kb();
$i := 0;
while $i < 100 {
    nqp::setelems($a, 1000000);
    nqp::strtocodes('abc', nqp::const::NORMALIZE_NFC, $a);
    nqp::force_gc();
    $i++;
}
say("strtocodes: " ~ nqp::elems($a) ~ " elements; 100 rounds grew RSS by " ~ nqp::div_i(rss_kb() - $before, 1024) ~ " MB");
