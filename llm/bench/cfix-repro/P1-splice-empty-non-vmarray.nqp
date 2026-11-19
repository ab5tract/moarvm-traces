# P1 control: a splice from an EMPTY source that is not a VMArray must keep
# working, before and after the P1 fix.
#
# asplice (VMArray.c:1040) takes the source's element count through the
# source's own REPR; with 0 elements copy_elements copies nothing (it only
# copies when elems > 0), so an empty source of any REPR is a plain deletion
# (or a no-op). The P1 fix throws only for a non-VMArray source that has
# elements. The sources here: an empty hash (MVMHash, elems 0), with count 1
# (a deletion) and count 0 (nothing to do).
#
# A correct VM, before and after the fix, prints
#     delete one through an empty hash: elems 2: 1 3
#     nothing through an empty hash: elems 2: 1 3

sub show($a) {
    my @s := nqp::list_s();
    my int $i := 0;
    while $i < nqp::elems($a) { nqp::push_s(@s, ~nqp::atpos($a, $i)); $i++ }
    'elems ' ~ nqp::elems($a) ~ ': ' ~ nqp::join(' ', @s)
}

my $a := nqp::list(1, 2, 3);
my $r;
try { nqp::splice($a, nqp::hash(), 1, 1); $r := show($a); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("delete one through an empty hash: $r");
try { nqp::splice($a, nqp::hash(), 1, 0); $r := show($a); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("nothing through an empty hash: $r");
