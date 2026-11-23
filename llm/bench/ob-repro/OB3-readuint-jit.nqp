# OB3 (a): the JIT's readuint does not apply the interpreter's checks
# ((flags & 3) == 3, size > 8). From cfix-B-raw/hand/jit-readuint-size16.nqp,
# one case per run (argument flags_3 or flags_16; one case per process, so
# that the specialization of one case does not decide the other's): a sub
# with the flags as a constant, called 200,000 times from the mainline (each
# call in a try), so that spesh and the JIT compile it with the flags as a
# known value. The interpreter (MVM_JIT_DISABLE=1, the .nojit output) throws
# "Invalid flags value for readuint" on every call. Before, with the JIT:
# calls return once the JIT has the sub (flags 3: a 1-byte read; flags 16:
# read_buf copies 16 bytes into an 8-byte local, "stack smashing detected"
# on cfix-base in the record). Fixed: every call dies with the interpreter's
# message, with and without the JIT.
# How many calls die depends on when the JIT takes over, so only
# none/some/all is printed.
sub inttype(int $bits, int $unsigned) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    my $h := nqp::hash('bits', $bits);
    if $unsigned { $h<unsigned> := 1 }
    nqp::composetype($t, nqp::hash('integer', $h));
    $t
}
sub how_many(int $n, int $total) { $n == 0 ?? 'none' !! $n == $total ?? 'all' !! 'some' }
sub MAIN($program, $case = '') {
    if $case ne 'flags_3' && $case ne 'flags_16' { say("usage: OB3-readuint-jit.nqp flags_3|flags_16"); nqp::exit(64) }
    say("readuint $case: start");
    my $at := nqp::newtype(nqp::null(), 'VMArray');
    nqp::composetype($at, nqp::hash('array', nqp::hash('type', inttype(8, 1))));
    my $a := nqp::create($at);
    my int $i := 0; while $i < 64 { nqp::push_i($a, $i); $i++ }
    my int $calls := 200000;
    my int $died := 0; my int $returned := 0; my $first_message := 'none'; my $last := 'none';
    $i := 0;
    if $case eq 'flags_3' {
        sub read_flags_3($a) { nqp::readuint($a, 0, 3) }
        while $i < $calls {
            try { $last := read_flags_3($a); $returned++; CATCH { if $died == 0 { $first_message := nqp::getmessage($!) }; $died++ } }
            $i++;
        }
    }
    else {
        sub read_flags_16($a) { nqp::readuint($a, 0, 16) }
        while $i < $calls {
            try { $last := read_flags_16($a); $returned++; CATCH { if $died == 0 { $first_message := nqp::getmessage($!) }; $died++ } }
            $i++;
        }
    }
    say("readuint $case: calls $calls, died " ~ how_many($died, $calls) ~ ", returned " ~ how_many($returned, $calls)
        ~ ", first message [$first_message], last value returned [$last]");
}
