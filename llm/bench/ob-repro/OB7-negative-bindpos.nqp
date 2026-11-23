# OB7, bind_pos with a negative index and the wrong register kind (Task 3,
# area Q, Review Focus 3): the negative index is resolved first, so -1 on
# three elements gets the kind message and -5 (still negative) gets "Index
# out of bounds", before and after the fix; the array keeps 3 elements.
sub case($name, $array, $code) {
    my $outcome := 'returned';
    try { $code($array); CATCH { $outcome := 'DIED ' ~ nqp::getmessage($!) } }
    say("$name: $outcome; elems " ~ nqp::elems($array));
}
case('obj array of 3, bindpos_i -1', nqp::list(1, 2, 3), -> $array { nqp::bindpos_i($array, -1, 7) });
case('obj array of 3, bindpos_i -5', nqp::list(1, 2, 3), -> $array { nqp::bindpos_i($array, -5, 7) });
case('int array of 3, bindpos -1', nqp::list_i(1, 2, 3), -> $array { nqp::bindpos($array, -1, nqp::hash()) });
case('int array of 3, bindpos -5', nqp::list_i(1, 2, 3), -> $array { nqp::bindpos($array, -5, nqp::hash()) });
