# M1: VMArray_gc_mark presizes the worklist with a 32-bit count.
#
# VMArray_gc_mark (VMArray.c:68-109) calls
#     MVM_gc_worklist_presize_for(tc, worklist, elems);       (83, 97)
# with elems a MVMuint64, but the parameter is MVMint32
# (src/gc/worklist.c:24, worklist.h:113), and the worklist's items and
# alloc are MVMuint32 (worklist.h:21-25). The loops that follow add up to
# elems entries with the unchecked MVM_gc_worklist_add_*_nocheck macros
# (worklist.h:83-101). Once items + elems reaches 2**32 the presize
# computes a short (wrapped) alloc and the adds write past the list.
#
# NOT RUN. Reaching it needs an OBJ or STR array of about 2**32 elements:
# 2**32 * 8 bytes = 32 GiB of slots alone, on a 32 GB machine without swap,
# plus a worklist of the same size (another 32 GiB) for the collection to
# overflow. Classified by argument (cfix-baseline.md). The program below is
# what would show it on a machine with well over 64 GiB of memory; it refuses
# to run unless given the argument "really".
#
# A correct VM would print "marked" (the collection completes); the bug
# would corrupt the heap past the worklist during nqp::force_gc.

sub MAIN($prog, $really = '') {
    nqp::die("M1 needs ~64 GiB; not run on this machine (pass 'really' to override)") unless $really eq 'really';
    my $a := nqp::list();
    nqp::setelems($a, 4294967296 + 16);    # 2**32 + 16 null slots
    my $o := nqp::list();
    my int $i := 0;
    while $i < 4294967296 + 16 { nqp::bindpos($a, $i, $o); $i++ }
    nqp::force_gc();
    say("marked");
}
