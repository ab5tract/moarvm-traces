# S1/T3 (area S): a splice of an array into itself compared with the same
# splice from a clone of the array, over many shapes.
#
# For every kind (obj in the nursery, obj promoted to gen2, str, int), 0 to 3
# elements shifted off first, offset 0..12 and count 0..12 on an 8-element
# array (2704 cases), the program does nqp::splice($a, $a, $off, $cnt) and
# nqp::splice($b, nqp::clone($b), $off, $cnt) on two equal arrays and prints
# a DIFF line for every case where the results differ, then the totals.
#
# Why they must agree once area S's fix is in: with the offset-0 start
# adjustment skipped for a self-splice (T3), nothing asplice does before the
# copy writes into the copied range [0, elems): when count > elems the tail
# is clamped to 0, so the shrinking memmove does not run; when the array
# grows, the tail move writes only at offset + elems and above; the
# compaction in set_size_internal moves the elements without changing them.
# The copy itself is memmove (fast path) or, for STR and gen2 OBJ, an
# element loop that runs backwards when the target lies above the source.
# So the copy reads the array as it was before the splice, as the clone does.
#
# A correct VM prints only
#     cases 2704, differing 0
# Unmodified upstream: DIFF lines (forward element copy for str and gen2 obj;
# the offset-0 adjustment for shifted arrays and for count > elems), and a
# SIGSEGV once a re-exposed dead OBJ slot is printed.
#
# Written by the reviewer of the area S fix; adopted unchanged below this
# header.
# For every kind (obj nursery, obj gen2, str, int), shift 0..3, offset 0..12, count 0..12:
# does nqp::splice($a, $a, off, cnt) give the same as nqp::splice($a, nqp::clone($a), off, cnt)?
sub mk($kind, int $shifts) {
    my $a := $kind eq 'str' ?? nqp::list_s() !! $kind eq 'int' ?? nqp::list_i() !! nqp::list();
    my int $i := 0;
    while $i < 8 + $shifts {
        if $kind eq 'str' { nqp::push_s($a, ~($i * 3 + 1)) }
        elsif $kind eq 'int' { nqp::push_i($a, $i * 3 + 1) }
        else { nqp::push($a, ~($i * 3 + 1)) }
        $i++;
    }
    $i := 0;
    while $i < $shifts {
        if $kind eq 'str' { nqp::shift_s($a) } elsif $kind eq 'int' { nqp::shift_i($a) } else { nqp::shift($a) }
        $i++;
    }
    $a
}
sub show($kind, $a) {
    my @p; my int $i := 0; my int $n := nqp::elems($a);
    while $i < $n {
        if $kind eq 'str' { my $s := nqp::atpos_s($a, $i); nqp::push(@p, nqp::isnull_s($s) ?? 'null' !! $s) }
        elsif $kind eq 'int' { nqp::push(@p, ~nqp::atpos_i($a, $i)) }
        else { my $o := nqp::atpos($a, $i); nqp::push(@p, nqp::isnull($o) ?? 'null' !! ~$o) }
        $i++;
    }
    nqp::join(' ', @p)
}
my int $bad := 0; my int $tot := 0;
for <obj gen2 str int> -> $kind {
    my $k := $kind eq 'gen2' ?? 'obj' !! $kind;
    my int $sh := 0;
    while $sh <= 3 {
        my int $off := 0;
        while $off <= 12 {
            my int $cnt := 0;
            while $cnt <= 12 {
                my $a := mk($k, $sh);
                my $b := mk($k, $sh);
                if $kind eq 'gen2' { nqp::force_gc(); nqp::force_gc(); }
                nqp::splice($a, $a, $off, $cnt);
                nqp::splice($b, nqp::clone($b), $off, $cnt);
                my $sa := show($k, $a); my $sb := show($k, $b);
                $tot++;
                if $sa ne $sb { $bad++; say("DIFF $kind sh=$sh off=$off cnt=$cnt self=[$sa] clone=[$sb]") }
                $cnt++;
            }
            $off++;
        }
        $sh++;
    }
}
say("cases $tot, differing $bad");
