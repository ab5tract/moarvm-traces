# G1: growth to 2**64 - 4096 or more wraps the rounded slot count to zero.
#
# set_size_internal (VMArray.c:441-448): once ssize >= 8192 the new size is
# (n + 0x1000) & ~0xfff. For n >= 2**64 - 4096 the addition wraps and ssize
# becomes 0, which passes the limit check (VMArray.c:458), so the slots are
# MVM_realloc'ed to 0 bytes and zero_slots then clears from elems (8192) to
# ssize (0): memset over (0 - 8192) * 8 bytes.
#
# nqp::setelems takes the count as a 64-bit integer and passes it on
# unchecked (interp.c, setelemspos), so a count of -4096 is n = 2**64 - 4096.
# Before the faulty step the program allocates only the 8192 slots (64 KiB).
#
# A correct VM prints
#     ssize 8192 reached: elems 8192
#     setelems(2**64 - 4096): DIED Unable to allocate an array of ... elements
#     still alive: elems 8192
#     element 1000000000: 0
# (the same exception every other size above the limit gets; reading past
# elems gives 0). The bug: the AddressSanitizer build stops in zero_slots
# ("negative-size-param", the memset over (0 - 8192) * 8 bytes, on the NULL
# that realloc(p, 0) returned). On the plain build (mimalloc: realloc to 0
# bytes returns a minimal block) the memset's end pointer wraps below its
# start, so it returns after writing a few bytes around the block; setelems
# "succeeds" with elems = 2**64 - 4096 over a 0-slot buffer, and the read of
# element 10**9 goes to unmapped memory (SIGSEGV).

my $a := nqp::list_i();
nqp::setelems($a, 8192);
say("ssize 8192 reached: elems " ~ nqp::elems($a));
my $r;
try { nqp::setelems($a, -4096); $r := 'returned, elems ' ~ nqp::elems($a); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("setelems(2**64 - 4096): $r");
say("still alive: elems " ~ nqp::elems($a));
say("element 1000000000: " ~ nqp::atpos_i($a, 1000000000));
