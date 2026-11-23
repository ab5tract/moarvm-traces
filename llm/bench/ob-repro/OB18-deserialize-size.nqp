# OB18 (first half): deserialize allocates elems * elem_size with no limit;
# the product wraps for elems >= 2**61 (8-byte kinds). cfix-open-bugs.md gives
# no crafted blob, so this program makes one: it serializes an SC holding an
# int64 array of three elements, the first a value that needs the 9-byte
# varint form (0x7EADBEEFCAFEF00D), then patches the bytes: the 1-byte count
# (3) and the 9-byte first element become a 9-byte count 2**61 + 1 and a
# 1-byte element 0, so the blob keeps its length. 2**61 + 1 elements of 8
# bytes is 2**64 + 8 bytes: the product wraps to 8.
# Before: an 8-byte block is allocated and every element read is stored past
# it (a heap overflow, silent without ASAN) until the reader runs out of
# data ("Read past end ..."), or a crash. Fixed: deserialize refuses the
# count before allocating ("Unable to allocate an array of
# 2305843009213693953 elements"). An unpatched round trip is the control.
sub uint8_buf_type() {
    my $e := nqp::newtype(nqp::null(), 'P6int');
    nqp::composetype($e, nqp::hash('integer', nqp::hash('bits', 8, 'unsigned', 1)));
    my $t := nqp::newtype(nqp::null(), 'VMArray');
    nqp::composetype($t, nqp::hash('array', nqp::hash('type', $e)));
    $t
}
sub encode_as_base64($buf) {   # as nqp's t/serialization/01-basic.t
    my @base64 := nqp::split('', "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/");
    my @str; my int $i := 0; my int $size := nqp::elems($buf);
    while $i < $size {
        my int $c := nqp::atpos_i($buf, $i++);
        $c := $c * 256; if $i < $size { $c := $c + nqp::atpos_i($buf, $i) }; $i++;
        $c := $c * 256; if $i < $size { $c := $c + nqp::atpos_i($buf, $i) }; $i++;
        nqp::push(@str, @base64[nqp::bitshiftr_i($c +& 0x00fc0000, 18)]);
        nqp::push(@str, @base64[nqp::bitshiftr_i($c +& 0x0003f000, 12)]);
        if $i > $size + 1 { nqp::push(@str, '=') } else { nqp::push(@str, @base64[nqp::bitshiftr_i($c +& 0x00000fc0, 6)]) };
        if $i > $size { nqp::push(@str, '=') } else { nqp::push(@str, @base64[$c +& 0x0000003f]) }
    }
    nqp::join('', @str)
}
my @original_bytes := (0x84, 0x00, 0x0D, 0xF0, 0xFE, 0xCA, 0xEF, 0xBE, 0xAD, 0x7E);
my @patched_bytes  := (0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x20, 0x81);
sub find_bytes($buf, @pattern) {
    my int $n := nqp::elems($buf) - nqp::elems(@pattern); my int $i := 0; my int $found := -1;
    while $i <= $n {
        my int $j := 0;
        while $j < nqp::elems(@pattern) && nqp::atpos_i($buf, $i + $j) == @pattern[$j] { $j++ }
        if $j == nqp::elems(@pattern) { if $found >= 0 { return -2 }; $found := $i }
        $i++;
    }
    $found
}
sub serialized_array($name) {
    my $sc := nqp::createsc($name);
    my $sh := nqp::list_s();
    my $a := nqp::list_i(0x7EADBEEFCAFEF00D, 1, 2);
    nqp::scsetobj($sc, 0, $a); nqp::setobjsc($a, $sc);
    nqp::list(nqp::serializetobuf($sc, $sh, uint8_buf_type()), $sh)
}
sub deserialize_and_report($label, $name, $buf, $sh) {
    my $r := 'returned';
    try {
        my $dsc := nqp::createsc($name);
        nqp::deserialize(encode_as_base64($buf), $dsc, $sh, nqp::list(), nqp::null());
        my $obj := nqp::scgetobj($dsc, 0);
        $r := 'returned, elems ' ~ nqp::elems($obj);
        if nqp::elems($obj) <= 3 { $r := $r ~ ', elements ' ~ nqp::atpos_i($obj, 0) ~ ' ' ~ nqp::atpos_i($obj, 1) ~ ' ' ~ nqp::atpos_i($obj, 2) }
        CATCH { $r := 'DIED ' ~ nqp::getmessage($!) }
    }
    say("$label: $r");
}
my $control := serialized_array('OB18_CONTROL_IN');
deserialize_and_report('unpatched round trip (control)', 'OB18_CONTROL_OUT', $control[0], $control[1]);
my $crafted := serialized_array('OB18_CRAFTED_IN');
my $buf := $crafted[0];
my int $at := find_bytes($buf, @original_bytes);
if $at < 0 {
    say("count and first element not found once in the blob (find_bytes $at); nothing patched");
}
else {
    say("count 3 and first element found once in the blob");
    my int $j := 0;
    while $j < nqp::elems(@patched_bytes) { nqp::bindpos_i($buf, $at + $j, @patched_bytes[$j]); $j++ }
    say("patched: count 2**61 + 1 (9-byte form), first element 0 (1-byte form)");
    deserialize_and_report('deserialize of the patched blob', 'OB18_CRAFTED_OUT', $buf, $crafted[1]);
}
say("done");
