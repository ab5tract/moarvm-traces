# OB9: normalizecodes of an empty input leaves the output array as it was
# (strtocodes of an empty string empties its output). Program from
# cfix-open-bugs.md OB9. Before: "elems 3: 10 20 30". Fixed: "elems 0:".
sub u32_array_type() {
    my $t := nqp::newtype(nqp::null(), "VMArray"); my $e := nqp::newtype(nqp::null(), "P6int");
    nqp::composetype($e, nqp::hash("integer", nqp::hash("bits", 32, "unsigned", 1)));
    nqp::composetype($t, nqp::hash("array", nqp::hash("type", $e)));
    $t
}
sub show($a) {
    my $parts := nqp::list_s(); my int $i := 0;
    while $i < nqp::elems($a) { nqp::push_s($parts, nqp::coerce_is(nqp::atpos_i($a, $i))); $i++ }
    "elems " ~ nqp::elems($a) ~ ":" ~ (nqp::elems($a) ?? " " ~ nqp::join(" ", $parts) !! "")
}
my $t := u32_array_type();
my $in := nqp::create($t); my $out := nqp::create($t);
nqp::push_i($out, 10); nqp::push_i($out, 20); nqp::push_i($out, 30);
my $r := 'returned';
try { nqp::normalizecodes($in, nqp::const::NORMALIZE_NFC, $out); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("normalizecodes of empty input into 10 20 30: $r; " ~ show($out));
my $o2 := nqp::create($t); nqp::push_i($o2, 10);
$r := 'returned';
try { nqp::strtocodes("", nqp::const::NORMALIZE_NFC, $o2); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("strtocodes of empty string into 10 (control): $r; " ~ show($o2));
my $in3 := nqp::create($t); nqp::push_i($in3, 101); nqp::push_i($in3, 769);
my $o3 := nqp::create($t); nqp::push_i($o3, 10); nqp::push_i($o3, 20); nqp::push_i($o3, 30);
$r := 'returned';
try { nqp::normalizecodes($in3, nqp::const::NORMALIZE_NFC, $o3); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("normalizecodes of 101 769 into 10 20 30 (control): $r; " ~ show($o3));
