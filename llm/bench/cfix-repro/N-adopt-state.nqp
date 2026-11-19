# N1/N2: the caller-visible state of the output array after
# nqp::normalizecodes and nqp::strtocodes (src/strings/normalize.c), for
# output arrays that are fresh, already hold elements, or have start > 0
# (elements shifted off the front), and that the array keeps working
# afterwards.
#
# For each op and target it prints the array right after the op (elems and
# every element), then pushes the numbers 1000 .. 1299 (300 elements: past
# both the old byte-count ssize and the real buffer) and prints elems, the
# element at index elems - 1 and whether the 300 pushed values read back.
# Inputs: normalizecodes of 101 769 97 (e, combining acute, a) to NFC
# gives 233 97; strtocodes of "\x[e9]a" to NFD gives 101 769 97.
# Last, "empty input": normalizecodes of an empty array into an array that
# holds 10 20 30 (MVM_unicode_normalize_codepoints returns early for an
# empty input and leaves the output as it was; strtocodes of '' empties it).
# A correct VM prints, for every target, the op's result alone (start 0,
# the old elements gone) and "read back ok" with elems = result + 300; and
# no AddressSanitizer report. The normalizecodes cases overrun the buffer
# on a build where ssize is set in bytes (ASAN: heap-buffer-overflow in
# MVM_VMArray_push); strtocodes leaks the old storage (not visible here:
# see N2-strtocodes-leak.nqp).

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
sub show($a) {
    my @p; my int $i := 0;
    while $i < nqp::elems($a) { nqp::push(@p, ~nqp::atpos_i($a, $i)); $i++ }
    "elems " ~ nqp::elems($a) ~ ": " ~ nqp::join(' ', @p)
}
my $u32 := arrtype(inttype(32, 1));
sub target($how) {
    my $a := nqp::create($u32);
    if $how ne 'fresh' {
        for 10, 20, 30, 40, 50 { nqp::push_i($a, $_) }
        if $how eq 'shifted' { nqp::shift_i($a); nqp::shift_i($a) }
    }
    $a
}
sub grow($a) {
    my int $n := nqp::elems($a);
    my int $i := 0; while $i < 300 { nqp::push_i($a, 1000 + $i); $i++ }
    my int $ok := 1; $i := 0;
    while $i < 300 { $ok := 0 if nqp::atpos_i($a, $n + $i) != 1000 + $i; $i++ }
    "after 300 pushes: elems " ~ nqp::elems($a) ~ ", last " ~ nqp::atpos_i($a, nqp::elems($a) - 1)
        ~ ", read back " ~ ($ok ?? 'ok' !! 'WRONG')
}
my $in := nqp::create($u32);
for 101, 769, 97 { nqp::push_i($in, $_) }
for <fresh filled shifted> -> $how {
    my $out := target($how);
    say("normalizecodes into $how (before: " ~ show($out) ~ ")");
    nqp::normalizecodes($in, nqp::const::NORMALIZE_NFC, $out);
    say("  " ~ show($out)); say("  " ~ grow($out));
}
for <fresh filled shifted> -> $how {
    my $out := target($how);
    say("strtocodes into $how (before: " ~ show($out) ~ ")");
    nqp::strtocodes(nqp::chr(233) ~ 'a', nqp::const::NORMALIZE_NFD, $out);
    say("  " ~ show($out)); say("  " ~ grow($out));
}
{
    my $out := nqp::create($u32);
    for 10, 20, 30 { nqp::push_i($out, $_) }
    nqp::normalizecodes(nqp::create($u32), nqp::const::NORMALIZE_NFC, $out);
    say("normalizecodes of empty input into 10 20 30: " ~ show($out));
    $out := nqp::create($u32);
    for 10, 20, 30 { nqp::push_i($out, $_) }
    nqp::strtocodes('', nqp::const::NORMALIZE_NFC, $out);
    say("strtocodes of '' into 10 20 30: " ~ show($out));
}
