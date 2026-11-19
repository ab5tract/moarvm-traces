# N1: nqp::normalizecodes stores a byte count as the output array's ssize.
#
# MVM_unicode_normalize_codepoints (src/strings/normalize.c:37-91) builds the
# result in a buffer of result_alloc 32-bit elements (malloc of
# input_codes * 4, grown 32 elements at a time by maybe_grow_result) and
# then adopts it into the output array with
#     out_body->ssize = result_pos * sizeof(MVMuint32);        (line 90)
# a byte count: about four times the allocation. set_size_internal
# (VMArray.c:431-435) trusts ssize, so a push, bindpos or setelems on the
# result anywhere between result_alloc and ssize elements writes past the
# buffer without reallocating.
#
# The program: 100 code points 'a' (already NFC) in a uint32 array,
# normalizecodes into a fresh uint32 array (result_pos 100, result_alloc
# 132: a 528-byte buffer; ssize 400), then 200 pushes (elements 100..299,
# bytes 400..1199) and a read-back.
# A correct VM prints
#     normalized: elems 100
#     pushed: elems 300, element 299 = 299, sum ok
# The bug: the pushes write up to 672 bytes past the 528-byte buffer: the
# AddressSanitizer build reports heap-buffer-overflow WRITE in
# MVM_VMArray_push at element 132; the plain build overwrites whatever
# follows the buffer (silently in the recorded run, or a crash later).
# Reached from nqp, or from Raku only through nqp ops: Rakudo's own callers
# (Uni.NFC/NFD/NFKC/NFKD, src/core.c/Uni.rakumod:70-84) pass a fresh NFx
# object and never grow it.

sub inttype(int $bits, int $unsigned) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    my $h := nqp::hash('bits', $bits);
    if $unsigned { $h<unsigned> := 1 }
    nqp::composetype($t, nqp::hash('integer', $h));
    $t
}
sub arrtype($elem) {
    my $t := nqp::newtype(nqp::null(), 'VMArray');
    nqp::composetype($t, nqp::hash('array', nqp::hash('type', $elem)));
    $t
}

my $u32 := arrtype(inttype(32, 1));
my $in := nqp::create($u32);
my int $i := 0; while $i < 100 { nqp::push_i($in, 97); $i++ }
my $out := nqp::create($u32);
nqp::normalizecodes($in, nqp::const::NORMALIZE_NFC, $out);
say("normalized: elems " ~ nqp::elems($out));
$i := 100; while $i < 300 { nqp::push_i($out, $i); $i++ }
my int $sum := 0; $i := 100; while $i < 300 { $sum := $sum + nqp::atpos_i($out, $i); $i++ }
say("pushed: elems " ~ nqp::elems($out) ~ ", element 299 = " ~ nqp::atpos_i($out, 299) ~ ", sum " ~ ($sum == 39900 ?? 'ok' !! "wrong ($sum)"));
