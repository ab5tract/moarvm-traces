sub int_array(int $bits) {
    my $int := nqp::newtype(nqp::null(), 'P6int');
    nqp::composetype($int, nqp::hash('integer', nqp::hash('bits', $bits, 'unsigned', 1)));
    my $t := nqp::newtype(nqp::null(), 'VMArray');
    nqp::composetype($t, nqp::hash('array', nqp::hash('type', $int)));
    $t
}
sub hex(int $n) {
    my $s := ''; my $d := '0123456789abcdef';
    while $n > 0 { $s := nqp::substr($d, $n % 16, 1) ~ $s; $n := nqp::div_i($n, 16) }
    $s eq '' ?? '0' !! $s
}
sub show($what, $a) {
    my @e; my int $i := 0;
    while $i < nqp::elems($a) { nqp::push(@e, hex(nqp::atpos_i($a, $i))); $i++ }
    say("$what: " ~ nqp::elems($a) ~ " elements: " ~ nqp::join(' ', @e));
}
my $u16 := int_array(16);
my $u8  := int_array(8);

my $a := nqp::create($u16);
nqp::push_i($a, 1); nqp::push_i($a, 2);
show('uint16 1 2, append "ab" as utf16', nqp::encode('ab', 'utf16', $a));

my $b := nqp::create($u8);
nqp::push_i($b, 1); nqp::push_i($b, 2); nqp::push_i($b, 3); nqp::shift_i($b);
show('uint8 2 3 (after a shift), append "ab" as utf8', nqp::encode('ab', 'utf8', $b));

show('fresh uint16, "abc" as utf8', nqp::encode('abc', 'utf8', nqp::create($u16)));

my $c := nqp::create($u16);
nqp::setelems($c, 8); nqp::setelems($c, 0);
show('uint16 with room for 8, none used, append 17 bytes of utf8', nqp::encode('abcdefghijklmnopq', 'utf8', $c));
