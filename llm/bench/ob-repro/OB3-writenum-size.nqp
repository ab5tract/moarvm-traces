# OB3 (c): writenum has no size check: every size but 4 takes the default arm,
# which hands `size` bytes of an 8-byte double to write_buf (sizes over 8
# over-read the stack; sizes 1 and 2 write the low bytes of the double).
# From cfix-B-raw/hand/writenum-size16.nqp, one case per size. graph.c has no
# writenum case, so this is the interpreter with or without the JIT.
# Before: every size returns (elems = size). Fixed: sizes other than 4 and 8
# die with "Cannot write a num of N bytes"; readnum, the model, does not
# refuse (flags & 3) == 3, so flags 15 (8 bytes, native order) is written.
sub inttype(int $bits, int $unsigned) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    my $h := nqp::hash('bits', $bits);
    if $unsigned { $h<unsigned> := 1 }
    nqp::composetype($t, nqp::hash('integer', $h));
    $t
}
my $at := nqp::newtype(nqp::null(), 'VMArray');
nqp::composetype($at, nqp::hash('array', nqp::hash('type', inttype(8, 1))));
for (16, 0, 3, 4, 8, 12, 15) -> $flags {
    my $a := nqp::create($at);
    my $r := 'returned';
    try { nqp::writenum($a, 0, 1.5, $flags); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
    say("writenum flags $flags (size " ~ nqp::bitshiftl_i(1, nqp::bitshiftr_i($flags, 2)) ~ "): $r; elems " ~ nqp::elems($a));
}
my $b := nqp::create($at);
nqp::writenum($b, 0, 1.5, 12);
my $r := 'returned';
try { $r := 'returned ' ~ nqp::readnum($b, 0, 12); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("readnum flags 12 of the 1.5 written with flags 12 (control): $r");
$r := 'returned';
try { $r := 'returned ' ~ nqp::readnum($b, 0, 16); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("readnum flags 16 (control): $r");
