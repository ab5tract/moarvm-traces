# G2: a size at or just under the growth limit reaches malloc, which fails
# and panics the VM, instead of the catchable "Unable to allocate" error.
#
# set_size_internal's budget (VMArray.c:450-462) is
# 2**(64 - elem_addr_size) elements, elem_addr_size 4/3/2/1 for 8/4/2/1-byte
# elements: 2**60 eight-byte slots, 2**63 bytes. The check is `ssize > limit`,
# so ssize == 2**60 passes and MVM_malloc(2**63) fails; so does every size
# well below the limit that this machine cannot give (2**45 slots = 256 TiB).
# The question for G2 is whether `>` is the defect: with `>=` the boundary
# size would throw, but 2**60 - 1 and 2**45 would still panic, and the
# product ssize * elem_size cannot overflow at any size the check lets
# through (at most 2**63 bytes for every element size).
#
# Run with one argument, the case: limit (2**60, exactly at the limit),
# under (2**60 - 1), far (2**45), over (2**60 + 1). Each case is a fresh
# int64 array (ssize 0, so the "< 8192" branch takes n as the new size) and
# one setelems; malloc fails without touching the memory. (An earlier run
# used 2**40 for "far": mimalloc's mmap of 8 TiB succeeds under overcommit,
# zero_slots then writes the pages, and the 2G MemoryMax killed the plain
# run, exit 137; the ASAN run refused the size. Recorded in cfix-baseline.md;
# its output files were not kept.)
#
# What this VM prints (and what a correct VM prints, if the panic for an
# allocation the machine cannot satisfy is accepted, as everywhere else in
# MoarVM):
#     over:  DIED Unable to allocate an array of 1152921504606846977 elements
#     limit, under, far: "Memory allocation failed; could not allocate N bytes"
#            (MVM_panic, exit 1)

sub MAIN($prog, $case) {
    my int $n := $case eq 'limit' ?? 1152921504606846976
              !! $case eq 'under' ?? 1152921504606846975
              !! $case eq 'far'   ?? 35184372088832
              !! $case eq 'over'  ?? 1152921504606846977
              !! nqp::die("case: limit, under, far or over");
    my $a := nqp::list_i();
    my $r;
    try { nqp::setelems($a, $n); $r := 'returned, elems ' ~ nqp::elems($a); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
    say("$case: setelems($n): $r");
}
