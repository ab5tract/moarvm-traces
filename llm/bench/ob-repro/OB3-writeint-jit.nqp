# OB3 (b): the JIT's writeint/writeuint do not apply the interpreter's checks
# ((flags & 3) == 3, size > 8). Not run by anyone before (cfix-open-bugs.md
# OB3 (b)); written like OB3-readuint-jit.nqp, one case per run (argument
# writeint_flags_3, writeint_flags_16, writeuint_flags_3 or
# writeuint_flags_16): a sub with the flags as a constant, called 200,000
# times from the mainline, each call in a try. The interpreter (.nojit
# output) throws "Invalid flags (F) or size (S) value for writeint" on every
# call. Before, with the JIT: calls return once the JIT has the sub (flags 3:
# a 1-byte write in native order; flags 16: write_buf copies 16 bytes from
# the address of an 8-byte register). Fixed: every call dies with the
# interpreter's message, with and without the JIT. The target is a
# 64-element uint8 array; its elems after the loop is printed (64 if nothing
# grew it). Only none/some/all is printed for the counts.
sub inttype(int $bits, int $unsigned) {
    my $t := nqp::newtype(nqp::null(), 'P6int');
    my $h := nqp::hash('bits', $bits);
    if $unsigned { $h<unsigned> := 1 }
    nqp::composetype($t, nqp::hash('integer', $h));
    $t
}
sub how_many(int $n, int $total) { $n == 0 ?? 'none' !! $n == $total ?? 'all' !! 'some' }
sub writeint_flags_3($a)   { nqp::writeint($a, 0, 1, 3) }
sub writeint_flags_16($a)  { nqp::writeint($a, 0, 1, 16) }
sub writeuint_flags_3($a)  { nqp::writeuint($a, 0, 1, 3) }
sub writeuint_flags_16($a) { nqp::writeuint($a, 0, 1, 16) }
sub MAIN($program, $case = '') {
    my %subs := nqp::hash('writeint_flags_3', &writeint_flags_3, 'writeint_flags_16', &writeint_flags_16,
        'writeuint_flags_3', &writeuint_flags_3, 'writeuint_flags_16', &writeuint_flags_16);
    unless nqp::existskey(%subs, $case) {
        say("usage: OB3-writeint-jit.nqp writeint_flags_3|writeint_flags_16|writeuint_flags_3|writeuint_flags_16");
        nqp::exit(64);
    }
    say("$case: start");
    my $at := nqp::newtype(nqp::null(), 'VMArray');
    nqp::composetype($at, nqp::hash('array', nqp::hash('type', inttype(8, 1))));
    my $a := nqp::create($at);
    my int $i := 0; while $i < 64 { nqp::push_i($a, 0); $i++ }
    my $code := %subs{$case};
    my int $calls := 200000;
    my int $died := 0; my int $returned := 0; my $first_message := 'none';
    $i := 0;
    while $i < $calls {
        try { $code($a); $returned++; CATCH { if $died == 0 { $first_message := nqp::getmessage($!) }; $died++ } }
        $i++;
    }
    say("$case: calls $calls, died " ~ how_many($died, $calls) ~ ", returned " ~ how_many($returned, $calls)
        ~ ", first message [$first_message], elems after " ~ nqp::elems($a) ~ ", element 0 " ~ nqp::atpos_i($a, 0));
}
