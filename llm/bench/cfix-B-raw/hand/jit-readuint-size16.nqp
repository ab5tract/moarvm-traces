# Seen on the way (not fixed here): the interpreter refuses readint/readuint
# flags whose size is over 8 bytes ("Invalid flags value"), but the JIT's
# readuint path calls read_buf with the size from the flags directly, and
# read_buf copies count bytes into an 8-byte local. flags 16: size 1 << 4 = 16.
# The loop gives spesh and the JIT the chance to compile the frame; each
# call is in a try.
sub inttype(int $bits, int $unsigned) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    my $h := nqp::hash('bits', $bits);
    if $unsigned { $h<unsigned> := 1 }
    nqp::composetype($t, nqp::hash('integer', $h));
    $t
}
my $at := nqp::newtype(nqp::null(), 'VMArray');
nqp::composetype($at, nqp::hash('array', nqp::hash('type', inttype(8, 1))));
my $a := nqp::create($at);
my int $i := 0; while $i < 64 { nqp::push_i($a, $i); $i++ }
sub rd($a) { nqp::readuint($a, 0, 16) }
my int $died := 0; my int $ret := 0; my $last := '';
$i := 0;
while $i < 200000 {
    try { $last := rd($a); $ret++; CATCH { $died++ } }
    $i++;
}
say("died $died, returned $ret, last $last");
