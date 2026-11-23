# OB7: a bind_pos with the wrong register kind throws, but only after the
# array has grown to index + 1. Program from cfix-open-bugs.md OB7.
# Before: elems 6 after a rejected bind at index 5 (and elems 2 for a bind
# inside the array). Fixed: the same messages, elems 2 in every case.
sub case($name, $a, $code) {
    my $r := 'returned';
    try { $code($a); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
    say("$name: $r; elems " ~ nqp::elems($a));
}
my $b := nqp::list(1, 2);
case('obj array, bindpos_i 5', $b, -> $a { nqp::bindpos_i($a, 5, 7) });
say("obj array, element 5 isnull: " ~ (nqp::elems($b) > 5 ?? nqp::isnull(nqp::atpos($b, 5)) !! 'no element 5'));
case('obj array, bindpos_n 5', nqp::list(1, 2), -> $a { nqp::bindpos_n($a, 5, 7.5) });
case('obj array, bindpos_i 1', nqp::list(1, 2), -> $a { nqp::bindpos_i($a, 1, 7) });
case('int array, bindpos 5', nqp::list_i(1, 2), -> $a { nqp::bindpos($a, 5, nqp::hash()) });
case('str array, bindpos_i 5', nqp::list_s('a', 'b'), -> $a { nqp::bindpos_i($a, 5, 7) });
