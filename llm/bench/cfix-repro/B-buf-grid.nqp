# B1/B2/B3 grid: readint/writeint over every element kind that read_buf and
# write_buf accept, with start 0, 1 and 3, every offset from -1 to two past
# the end, every access size (1, 2, 4, 8 bytes, and 0: flags 32 give
# 1 << 8, which the ops' unsigned char size truncates to 0), and the large
# offsets 2**60 + 5 (over the size limit for 8-byte kinds without wrapping),
# 2**61 + 1, 2**62 + 1 (wrap offset * elem_size for 8- and 4-byte kinds)
# and 2**63 - 1.
#
# Each line names the case (R = read, W = write; kind, start, elems, offset,
# size) and prints the result: a read prints the value or DIED <message>; a
# write prints "ok" or DIED <message>, then elems and every element of the
# array after it. Each write runs on a fresh array.
#
# Use: the same program on an unmodified and a fixed build, then
# cfix-B-raw/grid-check.py compares the two outputs line by line and checks
# that every differing line is a case the fix is meant to change: a read
# that ends past elems (B1: it passed the old check because the check
# counted start) or an offset whose byte position wraps (B2). Every other
# line must be identical. Large write offsets that would reach malloc
# (n <= the size limit) are left out: they panic on both builds (out of
# memory), which is the documented behaviour for such sizes.
#
# The kinds: int8 uint8 int16 uint16 int32 uint32 int64 uint64 num32 num64.
# Elements: 8 pushed (k * 0x11 + 1 for k = 0..7, or k + 0.5 for the num
# kinds), then `start` shifts; so elems is 8 - start and ssize is 8.

sub inttype(int $bits, int $unsigned) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    my $h := nqp::hash('bits', $bits);
    if $unsigned { $h<unsigned> := 1 }
    nqp::composetype($t, nqp::hash('integer', $h));
    $t
}
sub numtype(int $bits) {
    my $t := nqp::newtype(nqp::null(), 'P6num');
    nqp::composetype($t, nqp::hash('float', nqp::hash('bits', $bits)));
    $t
}
sub arrtype($elem) {
    my $t := nqp::newtype(nqp::null(), 'VMArray');
    nqp::composetype($t, nqp::hash('array', nqp::hash('type', $elem)));
    $t
}

my @kinds := nqp::list(
    nqp::list('int8',   arrtype(inttype(8, 0)),  1, 0),
    nqp::list('uint8',  arrtype(inttype(8, 1)),  1, 0),
    nqp::list('int16',  arrtype(inttype(16, 0)), 2, 0),
    nqp::list('uint16', arrtype(inttype(16, 1)), 2, 0),
    nqp::list('int32',  arrtype(inttype(32, 0)), 4, 0),
    nqp::list('uint32', arrtype(inttype(32, 1)), 4, 0),
    nqp::list('int64',  arrtype(inttype(64, 0)), 8, 0),
    nqp::list('uint64', arrtype(inttype(64, 1)), 8, 0),
    nqp::list('num32',  arrtype(numtype(32)),    4, 1),
    nqp::list('num64',  arrtype(numtype(64)),    8, 1));

sub make($k, int $shifts) {
    my $a := nqp::create($k[1]);
    my int $i := 0;
    while $i < 8 {
        if $k[3] { nqp::push_n($a, nqp::add_n($i, 0.5)) } else { nqp::push_i($a, $i * 17 + 1) }
        $i++;
    }
    $i := 0;
    while $i < $shifts {
        if $k[3] { nqp::shift_n($a) } else { nqp::shift_i($a) }
        $i++;
    }
    $a
}
sub show($a, $k) {
    my @p; my int $i := 0;
    while $i < nqp::elems($a) {
        nqp::push(@p, $k[3] ?? ~nqp::atpos_n($a, $i) !! ~nqp::atpos_i($a, $i));
        $i++;
    }
    'elems ' ~ nqp::elems($a) ~ ': ' ~ nqp::join(' ', @p)
}

my @sizes := nqp::list(1, 2, 4, 8, 0);
my @flags := nqp::list(0, 4, 8, 12, 32);
my @big := nqp::list(1152921504606846981, 2305843009213693953, 4611686018427387905, 9223372036854775807);
for @kinds -> $k {
    my int $es := $k[2];
    for (0, 1, 3) -> int $shifts {
        my int $elems := 8 - $shifts;
        my @offs;
        my int $o := -1;
        while $o <= $elems + 2 { nqp::push(@offs, $o); $o++ }
        for @big -> $b { nqp::push(@offs, $b) }
        for @offs -> int $off {
            my int $si := 0;
            while $si < 5 {
                my int $size := @sizes[$si];
                my int $flags := @flags[$si];
                my $case := "kind=" ~ $k[0] ~ " start=$shifts elems=$elems off=$off size=$size";
                # read
                my $a := make($k, $shifts);
                my $r;
                try { $r := ~nqp::readuint($a, $off, $flags); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
                say("R $case: $r");
                # write, unless the offset is large and would reach malloc
                # (limit: 2**(64 - a) elements, a = 4, 3, 2, 1 for 8, 4, 2, 1 bytes)
                my int $limitbits := $es == 8 ?? 60 !! $es == 4 ?? 61 !! $es == 2 ?? 62 !! 63;
                my int $isbig := $off > 1000;
                my int $skip := 0;
                if $isbig {
                    # off + size > 2**limitbits, computed without overflow:
                    # off > 2**limitbits - size
                    if $limitbits == 63 {
                        # 2**63 does not fit: off + size > 2**63
                        # iff off - 1 > (2**63 - 1) - size
                        $skip := !($off - 1 > 9223372036854775807 - $size);
                    }
                    else {
                        $skip := !($off > nqp::bitshiftl_i(1, $limitbits) - $size);
                    }
                }
                if $skip {
                    say("W $case: skipped (would reach malloc)");
                }
                else {
                    my $w := make($k, $shifts);
                    my $res;
                    try { nqp::writeuint($w, $off, 0x7766554433221100, $flags); $res := 'ok';
                          CATCH { $res := 'DIED ' ~ nqp::getmessage($!) } }
                    # a write that grows far would make show() long: print elems only then
                    if nqp::elems($w) > 64 { say("W $case: $res, elems " ~ nqp::elems($w)) }
                    else { say("W $case: $res, " ~ show($w, $k)) }
                }
                $si++;
            }
        }
    }
}
say("done");
