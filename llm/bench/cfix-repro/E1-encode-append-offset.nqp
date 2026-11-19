# E1: nqp::encode into an array that already has storage appends at the
# wrong place.
#
# MVM_string_encode_to_buf_config (src/strings/ops.c:1871-1921), when the
# target's slots are not NULL, grows the array by output_size / elem_size
# elements and then copies with
#     memmove(buf->body.slots.i8 + prev_elems, encoded, output_size);  (1910)
# prev_elems is an element count used as a byte offset: it ignores the
# element size and `start`, so the bytes land inside the existing elements
# and the last new elements stay zero. prev_elems is also a MVMuint32
# (1908), truncating elems above 2**32 (not driven: a 4 GiB array).
#
# The program, each case on a fresh array:
#   u16  a uint16 array 1 2, encode 'ab' as utf16 (4 bytes, 2 elements)
#   u8s  a uint8 array 1 2 3 with one shift_i (start 1: elements 2 3),
#        encode 'ab' as utf8
#   u8   a uint8 array 1 2 (start 0), encode 'ab' as utf8: the one shape
#        the code gets right, for reference
# A correct VM prints
#     u16: 1 2 97 98
#     u8s: 2 3 97 98
#     u8:  1 2 97 98
# The bug: "u16: 1 97 98 0" (element 1 overwritten, the last zero) and
# "u8s: 2 97 98 0". No memory outside the arrays is touched in these
# cases, so the AddressSanitizer build prints the same.
# Reached from nqp (and from Raku only through nqp ops): Rakudo's encoders
# pass a fresh buffer (src/core.c/Encoding/Encoder/Builtin.rakumod), which
# takes the other branch (adoption, 1913-1918).

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
sub show($name, $a) {
    my @p; my int $i := 0;
    while $i < nqp::elems($a) { nqp::push(@p, ~nqp::atpos_i($a, $i)); $i++ }
    say("$name: " ~ nqp::join(' ', @p));
}

my $u16 := nqp::create(arrtype(inttype(16, 1)));
nqp::push_i($u16, 1); nqp::push_i($u16, 2);
nqp::encode('ab', 'utf16', $u16);
show('u16', $u16);

my $u8t := arrtype(inttype(8, 1));
my $u8s := nqp::create($u8t);
nqp::push_i($u8s, 1); nqp::push_i($u8s, 2); nqp::push_i($u8s, 3);
nqp::shift_i($u8s);
nqp::encode('ab', 'utf8', $u8s);
show('u8s', $u8s);

my $u8 := nqp::create($u8t);
nqp::push_i($u8, 1); nqp::push_i($u8, 2);
nqp::encode('ab', 'utf8', $u8);
show('u8', $u8);
