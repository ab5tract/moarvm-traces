# OB7: a push with the wrong register kind throws, but only after the array
# has grown by one element. Program from cfix-open-bugs.md OB7, one case per
# register kind. Before: elems 3 (int and num array cases: 3 too).
# Fixed: the same messages, elems 2 in every case.
sub case($name, $a, $code) {
    my $r := 'returned';
    try { $code($a); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
    say("$name: $r; elems " ~ nqp::elems($a));
}
case('obj array, push_i', nqp::list(1, 2), -> $a { nqp::push_i($a, 7) });
case('obj array, push_n', nqp::list(1, 2), -> $a { nqp::push_n($a, 7.5) });
case('obj array, push_s', nqp::list(1, 2), -> $a { nqp::push_s($a, 'x') });
case('int array, push', nqp::list_i(1, 2), -> $a { nqp::push($a, nqp::hash()) });
case('num array, push_i', nqp::list_n(1.5, 2.5), -> $a { nqp::push_i($a, 7) });
case('str array, push_i', nqp::list_s('a', 'b'), -> $a { nqp::push_i($a, 7) });
