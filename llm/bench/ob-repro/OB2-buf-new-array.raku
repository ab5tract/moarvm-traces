# OB2, the Raku route (cfix-P.md section 5 table, row Buf.new(array[int])):
# Buf.new with an array type object reaches nqp::splice with a type object as
# the source (Buf.rakumod, the `int @values` candidate).
# Before: "MoarVM panic: Memory allocation failed" (not catchable) or a
# garbage copy. Fixed: an exception with the splice message.
say "Buf.new(array[int]):";
try {
    my $b = Buf.new(array[int]);
    say "returned, elems {$b.elems}";
    CATCH { default { say "DIED {.message}" } }
}
say "done";
