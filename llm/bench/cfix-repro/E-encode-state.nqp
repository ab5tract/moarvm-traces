# E1/E2: what nqp::encode leaves in the target array, for every integer
# element kind and every shape of target (src/strings/ops.c,
# MVM_string_encode_to_buf_config). Self-checking.
#
# Kinds: uint8 int8 uint16 int16 uint32 int32 uint64 int64. Targets:
#   fresh    a new array (no storage: the adopting branch)
#   filled   holds 1 2 (the appending branch, start 0)
#   shifted  held 1 2 3, one shift_i (start 1: holds 2 3)
#   popped   held 1 2 3, one pop_i (holds 1 2; the slot of the 3 still
#            holds 3)
#   emptied  setelems 8, then setelems 0 (storage for 8 elements, none in
#            use: the storage is exactly full after 8 elements)
#   normalized (32-bit kinds only) the result of nqp::normalizecodes of
#            101 769 97 to NFC: holds 233 97, in a buffer the normalizer
#            allocated for 3 elements, whose third slot was never written
#            (AddressSanitizer's allocator fills new blocks with 0xbe);
#            only the strings of at most 4 bytes, which stay in that slot
#            (a longer one would reach past the 12-byte buffer on a build
#            whose normalizecodes still sets ssize in bytes)
# Strings (ASCII, so every byte is below 0x80): '' (0 bytes), 'a' (1),
# 'ab' (2), 'abc' (3), 'abcde' (5), and for 'emptied' also a string of
# 8 * element size + 1 bytes (one byte more than the storage). Encoding
# utf8, plus 'ab' as utf16 (4 bytes).
# Expected (what a VM that appends after the last element in whole
# elements gives): the target's elements as they were, then the encoded
# bytes packed into elements in memory order (little-endian here), the
# last element padded with zero bytes. Each line prints the kind, target,
# encoding, byte count, then "ok" or "MISMATCH want <list>", and the
# array (elems and every element).
# An argument restricts the run to one kind (for builds that crash).

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
sub elems_of($a) {
    my @p; my int $i := 0;
    while $i < nqp::elems($a) { nqp::push(@p, ~nqp::atpos_i($a, $i)); $i++ }
    @p
}
my $u8t := arrtype(inttype(8, 1));
sub bytes_of($str, $enc) { elems_of(nqp::encode($str, $enc, nqp::create($u8t))) }

sub MAIN($prog, $only = '') {
    my @kinds := nqp::list(
        nqp::list('uint8', 8, 1), nqp::list('int8', 8, 0),
        nqp::list('uint16', 16, 1), nqp::list('int16', 16, 0),
        nqp::list('uint32', 32, 1), nqp::list('int32', 32, 0),
        nqp::list('uint64', 64, 1), nqp::list('int64', 64, 0));
    for @kinds -> @k {
        my $name := @k[0]; my int $es := nqp::div_i(@k[1], 8);
        next if $only ne '' && $only ne $name;
        my $type := arrtype(inttype(@k[1], @k[2]));
        my @hows := nqp::list('fresh', 'filled', 'shifted', 'popped', 'emptied');
        nqp::push(@hows, 'normalized') if $es == 4;
        for @hows -> $how {
            my @cases := nqp::list(
                nqp::list('', 'utf8'), nqp::list('a', 'utf8'), nqp::list('ab', 'utf8'),
                nqp::list('abc', 'utf8'), nqp::list('abcde', 'utf8'), nqp::list('ab', 'utf16'));
            nqp::push(@cases, nqp::list(nqp::x('x', 8 * $es + 1), 'utf8')) if $how eq 'emptied';
            for @cases -> @c {
                next if $how eq 'normalized' && nqp::chars(@c[0]) > 3;
                my $a := nqp::create($type);
                if $how eq 'filled' { nqp::push_i($a, 1); nqp::push_i($a, 2) }
                elsif $how eq 'shifted' { nqp::push_i($a, 1); nqp::push_i($a, 2); nqp::push_i($a, 3); nqp::shift_i($a) }
                elsif $how eq 'popped' { nqp::push_i($a, 1); nqp::push_i($a, 2); nqp::push_i($a, 3); nqp::pop_i($a) }
                elsif $how eq 'emptied' { nqp::setelems($a, 8); nqp::setelems($a, 0) }
                elsif $how eq 'normalized' {
                    my $in := nqp::create($type);
                    nqp::push_i($in, 101); nqp::push_i($in, 769); nqp::push_i($in, 97);
                    nqp::normalizecodes($in, nqp::const::NORMALIZE_NFC, $a);
                }
                my @want := elems_of($a);
                my @b := bytes_of(@c[0], @c[1]);
                my int $nb := nqp::elems(@b);
                my int $i := 0;
                while $i < $nb {
                    my int $v := 0; my int $j := $es - 1;
                    while $j >= 0 {
                        $v := $v * 256 + ($i + $j < $nb ?? +@b[$i + $j] !! 0);
                        $j--;
                    }
                    nqp::push(@want, ~$v);
                    $i := $i + $es;
                }
                nqp::encode(@c[0], @c[1], $a);
                my @got := elems_of($a);
                my $w := nqp::join(' ', @want); my $g := nqp::join(' ', @got);
                say("$name $how " ~ @c[1] ~ " $nb bytes: " ~ ($w eq $g ?? 'ok' !! "MISMATCH want $w")
                    ~ "; elems " ~ nqp::elems($a) ~ ": $g");
            }
        }
    }
    say("done");
}
