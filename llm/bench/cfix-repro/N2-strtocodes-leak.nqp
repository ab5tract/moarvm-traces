# N2: nqp::strtocodes overwrites the output array's slots without freeing
# them.
#
# MVM_unicode_string_to_codepoints (src/strings/normalize.c:156-204) puts
# its result buffer into `out` (lines 200-203) without freeing what
# out->body.slots held; MVM_unicode_normalize_codepoints, the sibling at
# lines 82-84, does free it. Whatever storage the array had is leaked.
#
# The program: one uint32 array, 100 rounds of setelems(out, 1000000)
# (grows its storage to 4 MB and zeroes it, so the pages are resident)
# followed by strtocodes('abc', NFC, out) and a collection (so that, in the
# control, the dropped arrays are freed and their storage can be reused
# before the next round). It prints VmRSS (from
# /proc/self/status) before and after. Run with "control" to replace the
# array by a fresh one between the setelems and the strtocodes: the 4 MB
# array is then dropped and the collector frees its storage (gc_free), so
# the next round reuses it; that is what a correct VM's case run does too.
# A correct VM prints, in both modes, a growth of a few tens of MB at most:
#     case: elems 3, RSS grew by <small> MB
# The bug (case run): RSS grows by about 400 MB (100 leaked 4 MB buffers);
# recorded: case 416 MB, control 18 MB on the plain build. Under
# AddressSanitizer (detect_leaks=0 for every run: MoarVM does not free
# everything at exit) the case grows 396 MB and the control 280 MB, because
# ASAN's quarantine (256 MB by default) holds freed blocks back from reuse;
# the plain build is the evidence here.

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
sub rss_kb() {
    for nqp::split("\n", slurp('/proc/self/status')) {
        if nqp::eqat($_, 'VmRSS:', 0) { return +nqp::substr($_, 6) }
    }
    -1
}

sub MAIN($prog, $mode = 'case') {
    my $u32 := arrtype(inttype(32, 1));
    my $out := nqp::create($u32);
    nqp::force_gc();
    my int $before := rss_kb();
    my int $i := 0;
    while $i < 100 {
        nqp::setelems($out, 1000000);
        $out := nqp::create($u32) if $mode eq 'control';
        nqp::strtocodes('abc', nqp::const::NORMALIZE_NFC, $out);
        nqp::force_gc();
        $i++
    }
    nqp::force_gc();
    my int $after := rss_kb();
    say("$mode: elems " ~ nqp::elems($out) ~ ", RSS grew by " ~ nqp::div_i($after - $before, 1024) ~ " MB");
}
