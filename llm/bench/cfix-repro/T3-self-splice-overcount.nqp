# T3 (area S), the other direction: a self-splice at offset 0 with a count
# larger than the array drops elements of the source before they are copied.
#
# asplice at offset 0 (VMArray.c:1065-1082) computes n = elems1 - count;
# when count > elems1, n is negative and the adjustment moves start forward
# by -n (elems0 and count shrink to match). When the source is the array
# itself, copy_elements(root, root, 0, 0, elems1) then reads from the new
# start, so the first -n elements are lost and the last slots are past the
# old elements. No shift is needed beforehand.
#
# The program: an OBJ array of eight strings 1 4 7 .. 22 (in the nursery),
# and nqp::splice($a, $a, 0, $count) for count 9, 10, 11, 12, each on a fresh
# array. Run with "control" to splice from nqp::clone($a) instead.
#
# A correct VM prints for every count
#     count N: elems 8: 1 4 7 10 13 16 19 22
# (replace everything with the array itself). The bug: count 9 gives
# "4 7 10 13 16 19 22 null"; larger counts lose more. The control prints the
# correct line.

sub MAIN($prog, $mode = 'case') {
    for (9, 10, 11, 12) -> $count {
        my $a := nqp::list();
        my int $i := 0;
        while $i < 8 { nqp::push($a, ~($i * 3 + 1)); $i++ }
        nqp::splice($a, $mode eq 'control' ?? nqp::clone($a) !! $a, 0, $count);
        my @p;
        $i := 0;
        while $i < nqp::elems($a) {
            my $e := nqp::atpos($a, $i);
            nqp::push(@p, nqp::isnull($e) ?? 'null' !! ~$e);
            $i++
        }
        say("count $count: elems " ~ nqp::elems($a) ~ ": " ~ nqp::join(' ', @p));
    }
}
