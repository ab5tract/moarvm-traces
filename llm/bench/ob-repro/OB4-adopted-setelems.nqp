# OB4: normalizecodes adopts a malloc'd buffer whose room past elems was never
# written; setelems inside that room exposes the bytes. From
# cfix-E-raw/hand-unwritten-slot.nqp: input 101 769 97 gives a 3-slot (12-byte)
# result buffer holding 2 elements (233 97). On a fresh heap the unwritten
# slot can be zero by chance (it was on both port builds, unlike the record's
# run on cfix-base), so the heap is prepared first: 200 normalizecodes results
# of 97 98 99 (12-byte buffers, all three slots written, 99 in the third) are
# made garbage and freed by two full collections, so that the next 12-byte
# malloc is likely to reuse one of them.
# Before: element 2 holds bytes never written for this array (often 99,
# varies). Only zero/non-zero is printed. Fixed: element 2 = 0.
my $t := nqp::newtype(nqp::null(), 'VMArray');
my $e := nqp::newtype(nqp::null(), 'P6int');
nqp::composetype($e, nqp::hash('integer', nqp::hash('bits', 32, 'unsigned', 1)));
nqp::composetype($t, nqp::hash('array', nqp::hash('type', $e)));
sub codes(*@cps) { my $a := nqp::create($t); for @cps { nqp::push_i($a, $_) }; $a }
my $filler_input := codes(97, 98, 99);
my @garbage;
my int $i := 0;
while $i < 200 { my $g := nqp::create($t); nqp::normalizecodes($filler_input, nqp::const::NORMALIZE_NFC, $g); nqp::push(@garbage, $g); $i++ }
say("heap prepared: 200 results of 97 98 99, element 2 of the last = " ~ nqp::atpos_i(@garbage[199], 2));
@garbage := nqp::list();
nqp::force_gc(); nqp::force_gc();
my $in := codes(101, 769, 97);
my $a := nqp::create($t);
nqp::normalizecodes($in, nqp::const::NORMALIZE_NFC, $a);
say("normalized 101 769 97: elems " ~ nqp::elems($a) ~ ": " ~ nqp::atpos_i($a, 0) ~ " " ~ nqp::atpos_i($a, 1));
my $r := 'returned';
try { nqp::setelems($a, 3); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("setelems 3: $r; elems " ~ nqp::elems($a));
if nqp::elems($a) == 3 {
    say("element 2 " ~ (nqp::atpos_i($a, 2) == 0 ?? "= 0" !! "!= 0 (bytes never written for this array)"));
}
