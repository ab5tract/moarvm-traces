# O1, further cases: how nqp::spawnprocasync uses the config hash's
# "buf_type" key (src/io/procops.c), beyond O1-procasync-buf-type.nqp.
#
# Each mode spawns /bin/sh -c 'printf "%099d\n" 7' (100 bytes on stdout)
# and prints what the spawn and the reads gave:
#   valid    buf_type is a VMArray of uint8 (control): 100 elements.
#   missing  "stdout_bytes" is configured but "buf_type" is not.
#   rebind   buf_type is a uint8 array type at the spawn; before reading
#            is permitted, the key is rebound to an int64 array type.
#   noread   buf_type is the int64 array type, but no output is read
#            (no *_bytes key): the type is never used.
#   pty-missing  "pty" is set (the terminal is read through stdout), no
#            "stdout_bytes" and no "buf_type".
#   late     neither "stdout_bytes" nor "buf_type" at the spawn;
#            "stdout_bytes" is bound right after spawnprocasync returns.
#            The event loop thread reads the keys when it sets the process
#            up, so whether it sees the new key is a race: the outcome may
#            differ from run to run. Waits only for the done or error
#            callback.
# A correct VM: valid and rebind read 100 one-byte elements (rebinding
# after the spawn cannot change what the reads produce, or is refused);
# missing refuses the spawn (or reports an error) instead of reading into
# a null type; noread runs the process as it always did.
# Upstream (as recorded in this campaign): async_read looks buf_type up in
# the live hash at every read, so rebind reads into the int64 type (element
# 99 lies 664 bytes past the 128-byte buffer, as in O1's int64 case), and
# missing reads into VMNull.

my class Queue is repr('ConcBlockingQueue') { }

sub arr_type($bits) {
    my $t := nqp::newtype(nqp::null(), 'VMArray');
    my $e := nqp::newtype(nqp::null(), 'P6int');
    nqp::composetype($e, nqp::hash('integer', nqp::hash('bits', $bits, 'unsigned', 1)));
    nqp::composetype($t, nqp::hash('array', nqp::hash('type', $e)));
    $t
}

sub MAIN($prog, $mode = 'valid') {
    my $queue := nqp::create(Queue);
    my $u8  := arr_type(8);
    my $i64 := arr_type(64);
    my $done := 0; my $eof := 0;
    my @got;
    my $config := nqp::hash(
        'done', -> $status { $done := 1 },
        'ready', -> $stdin?, $stdout?, $stderr? { },
        'error', -> $err, $code? { say("error callback: $err"); $done := 1; $eof := 1 },
    );
    my $reader := -> $seq, $data, $err {
        if nqp::isconcrete($data) { nqp::push(@got, $data) }
        elsif nqp::isconcrete($err) && $err ne '' { say("stdout_bytes error: $err"); $eof := 1 }
        else { $eof := 1 }
    };
    if $mode ne 'noread' && $mode ne 'pty-missing' && $mode ne 'late' {
        $config<stdout_bytes> := $reader;
    }
    else { $eof := 1 }
    $config<pty> := 1 if $mode eq 'pty-missing';
    if $mode eq 'valid' || $mode eq 'rebind' { $config<buf_type> := $u8 }
    elsif $mode eq 'noread' { $config<buf_type> := $i64 }
    elsif $mode ne 'missing' && $mode ne 'pty-missing' && $mode ne 'late' {
        nqp::die("mode: valid, missing, rebind, noread, pty-missing or late")
    }
    my $r;
    try {
        my $task := nqp::spawnprocasync($queue, '/bin/sh',
            nqp::list('/bin/sh', '-c', 'printf "%099d\n" 7'), nqp::cwd(), nqp::getenvhash(), $config);
        $config<buf_type> := $i64 if $mode eq 'rebind';
        $config<stdout_bytes> := $reader if $mode eq 'late';
        nqp::permit($task, 1, -1) if $mode ne 'noread';
        while !$done || !$eof {
            if nqp::shift($queue) -> $t {
                if nqp::islist($t) { my $code := nqp::shift($t); $code(|$t) } else { $t() }
            }
        }
        $r := 'returned';
        CATCH { $r := 'DIED ' ~ nqp::getmessage($!) }
    }
    say("spawn: $r");
    say("reads: " ~ nqp::elems(@got));
    my int $total := 0;
    for @got { $total := $total + nqp::elems($_) }
    say("elements read: $total");
    if nqp::elems(@got) {
        my $first := @got[0];
        say("first read: " ~ nqp::reprname($first) ~ ", " ~ nqp::elems($first) ~ " elements");
        if nqp::elems($first) > 99 {
            say("element 0: " ~ nqp::atpos_i($first, 0) ~ ", element 99: " ~ nqp::atpos_i($first, 99));
        }
    }
}
