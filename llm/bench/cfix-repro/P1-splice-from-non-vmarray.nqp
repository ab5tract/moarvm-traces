# P1: a splice from a non-empty object that is not a VMArray dereferences
# NULL REPR data.
#
# asplice (VMArray.c:1040) takes the source's element count through its own
# REPR (`elems`), so any REPR with a positional or associative count is let
# in. copy_elements (VMArray.c:933-938) then sets s_repr_data to NULL for a
# source that is not a VMArray, skips the fast path, and reads
# s_repr_data->slot_type for slot_type_to_kind (VMArray.c:958): a NULL
# dereference. Nothing on the way (the splice op, interp.c:2321) checks the
# source. The source here is a one-key hash (MVMHash, elems 1).
#
# A correct VM prints
#     before: 3 elements
#     splice from a hash: DIED <an exception naming the source>
#     after: 3 elements
# The bug: SIGSEGV in copy_elements (the AddressSanitizer build reports a
# SEGV on an unknown address near zero, in copy_elements). The array has
# already been grown by the time it dies.

my $a := nqp::list(1, 2, 3);
say("before: " ~ nqp::elems($a) ~ " elements");
my $r;
try { nqp::splice($a, nqp::hash('k', 1), 1, 0); $r := 'returned, ' ~ nqp::elems($a) ~ ' elements'; CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("splice from a hash: $r");
say("after: " ~ nqp::elems($a) ~ " elements");
