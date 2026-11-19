# E (fresh target): nqp::encode into an array that has no storage yet
# adopts the encoded buffer with elems = bytes / element size, rounded
# down (src/strings/ops.c, MVM_string_encode_to_buf_config, the else
# branch), so the bytes of a last partial element are dropped. Reached from
# plain Raku with an encoder built for a buffer type wider than the
# encoding's unit: Encoding::Encoder::Builtin.new($enc, $type) creates a
# fresh $type for every encode-chars.
# A VM that keeps whole elements prints, for 'abc' into blob16, 2 elements
# 6261 63 (the 'c' in the low byte of the second); upstream prints 1
# element 6261.
for (blob16, 'abc'), (blob16, 'abcd'), (blob32, 'abcde'), (blob64, 'abc'), (blob8, 'abc') -> ($type, $str) {
    my $b = Encoding::Encoder::Builtin.new('utf8', $type).encode-chars($str);
    say "{$type.^name} '$str': elems {$b.elems}: {$b.list.map(*.base(16))}";
}
