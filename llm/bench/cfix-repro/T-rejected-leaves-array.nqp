# T1 and T2: after a pop or unshift rejected for the register kind, is the
# array unchanged? Every element and elems are read before and after.
#
# pop (VMArray.c:648-725) decrements elems before the kind check; unshift
# (VMArray.c:727-824) decrements start before it (and, at start 0, first
# makes room at the front). A rejected shift (826-902) changes nothing, and
# is included as the reference.
#
# Each case builds a small array (some after one shift, so start > 0 and the
# shifted-off element is kept alive by the program, so nothing here depends
# on the collector), prints "before: elems N: e0 e1 ...", does the rejected
# op in a try, prints the message and "after: ..." the same way, and then
# does one valid op of the same kind and prints the array again.
#
# A correct VM prints, for every case, the same "after" line as "before",
# and the valid op then works on the unchanged array. Upstream: after a
# rejected pop the last element is missing (elems one less); after a
# rejected unshift the window is one slot to the left: element 0 is what was
# in front (after a shift, the shifted-off element; at start 0, a zeroed
# slot of the room just made: null / 0), the last element is missing, and
# the valid op works on that moved window.

sub inttype(int $bits, int $unsigned) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    my $h := nqp::hash('bits', $bits);
    if $unsigned { $h<unsigned> := 1 }
    nqp::composetype($t, nqp::hash('integer', $h));
    $t
}
my $u8t := nqp::newtype(nqp::null(), 'VMArray');
nqp::composetype($u8t, nqp::hash('array', nqp::hash('type', inttype(8, 1))));

sub show($a, $k) {
    my @s := nqp::list_s();
    my int $i := 0;
    while $i < nqp::elems($a) {
        if $k eq 'obj' { my $e := nqp::atpos($a, $i); nqp::push_s(@s, nqp::isnull($e) ?? 'null' !! ~$e) }
        elsif $k eq 'str' { my $e := nqp::atpos_s($a, $i); nqp::push_s(@s, nqp::isnull_s($e) ?? 'null' !! $e) }
        elsif $k eq 'num' { nqp::push_s(@s, ~nqp::atpos_n($a, $i)) }
        else { nqp::push_s(@s, ~nqp::atpos_i($a, $i)) }
        $i++
    }
    'elems ' ~ nqp::elems($a) ~ ': ' ~ nqp::join(' ', @s)
}
sub make($k) {
    if $k eq 'obj' { nqp::list('a', 'b', 'c', 'd') }
    elsif $k eq 'str' { nqp::list_s('a', 'b', 'c', 'd') }
    elsif $k eq 'int' { nqp::list_i(1, 2, 3, 4) }
    elsif $k eq 'num' { nqp::list_n(1.5, 2.5, 3.5, 4.5) }
    else { my $a := nqp::create($u8t); nqp::push_i($a, 1); nqp::push_i($a, 2); nqp::push_i($a, 3); nqp::push_i($a, 4); $a }
}

my @keep;
sub case($name, $k, int $shifted, $bad, $good) {
    my $a := make($k);
    if $shifted { nqp::push(@keep, $k eq 'obj' ?? nqp::shift($a) !! $k eq 'str' ?? nqp::shift_s($a)
        !! $k eq 'num' ?? nqp::shift_n($a) !! nqp::shift_i($a)) }
    say("== $name ($k array" ~ ($shifted ?? ', after a shift' !! '') ~ ')');
    say("before: " ~ show($a, $k));
    my $r;
    try { $bad($a); $r := 'returned'; CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
    say("rejected: $r");
    say("after:  " ~ show($a, $k));
    $good($a);
    say("valid op: " ~ show($a, $k));
}

case('pop_i', 'obj', 0, -> $a { nqp::pop_i($a) }, -> $a { nqp::push(@keep, nqp::pop($a)) });
case('pop_n', 'obj', 1, -> $a { nqp::pop_n($a) }, -> $a { nqp::push(@keep, nqp::pop($a)) });
case('pop_s', 'obj', 0, -> $a { nqp::pop_s($a) }, -> $a { nqp::push(@keep, nqp::pop($a)) });
case('pop', 'int', 0, -> $a { nqp::pop($a) }, -> $a { nqp::pop_i($a) });
case('pop_s', 'int', 1, -> $a { nqp::pop_s($a) }, -> $a { nqp::pop_i($a) });
case('pop_i', 'str', 0, -> $a { nqp::pop_i($a) }, -> $a { nqp::pop_s($a) });
case('pop_i', 'num', 0, -> $a { nqp::pop_i($a) }, -> $a { nqp::pop_n($a) });
case('pop_n', 'uint8', 0, -> $a { nqp::pop_n($a) }, -> $a { nqp::pop_i($a) });
case('shift_i (reference)', 'obj', 0, -> $a { nqp::shift_i($a) }, -> $a { nqp::push(@keep, nqp::shift($a)) });
case('unshift_i', 'obj', 0, -> $a { nqp::unshift_i($a, 7) }, -> $a { nqp::unshift($a, 'z') });
case('unshift_i', 'obj', 1, -> $a { nqp::unshift_i($a, 7) }, -> $a { nqp::unshift($a, 'z') });
case('unshift_s', 'obj', 1, -> $a { nqp::unshift_s($a, 'q') }, -> $a { nqp::unshift($a, 'z') });
case('unshift', 'int', 0, -> $a { nqp::unshift($a, nqp::list()) }, -> $a { nqp::unshift_i($a, 9) });
case('unshift_s', 'int', 1, -> $a { nqp::unshift_s($a, 'q') }, -> $a { nqp::unshift_i($a, 9) });
case('unshift_i', 'str', 1, -> $a { nqp::unshift_i($a, 7) }, -> $a { nqp::unshift_s($a, 'z') });
case('unshift_i', 'num', 1, -> $a { nqp::unshift_i($a, 7) }, -> $a { nqp::unshift_n($a, 9.5) });
case('unshift_n', 'uint8', 1, -> $a { nqp::unshift_n($a, 9.5) }, -> $a { nqp::unshift_i($a, 9) });
say("done");
