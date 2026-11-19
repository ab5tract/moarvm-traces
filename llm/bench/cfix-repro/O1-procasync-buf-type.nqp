# O1: async process output is adopted into the caller's buf_type without
# checking that it is a VMArray of 1-byte elements.
#
# async_read (src/io/procops.c:657-700) allocates an object of the type in
# the spawn config's "buf_type" key (681-683) and writes the libuv read
# buffer into it as an MVMArray (684-687): slots = the malloc'ed bytes,
# ssize = buf->len (bytes), elems = nread (bytes). Nothing in procops.c
# checks the type's REPR or element size (the socket and decoder sites check
# for an 8-bit integer array: asyncsocket.c:192-196, Decoder.c:320-324).
#
# The program spawns /bin/sh -c 'printf ...' writing 100 bytes to stdout,
# with "buf_type" set by the argument:
#   int64  a VMArray of int64 elements: the buffer (on_alloc: 128 bytes for
#          the first read) is read as 100 elements of 8 bytes; element 99
#          lies at bytes 792..799.
#   hash   the hash type (MVMHash): the four MVMArray body fields are
#          written over a hash body that does not have them.
# A correct VM prints, for either, an exception at spawnprocasync (or when
# the output arrives) naming buf_type, and no read. The bug:
#   int64: "got 100 elements", then element 99 is read 664 bytes past the
#          128-byte buffer: garbage on the plain build; AddressSanitizer
#          reports heap-buffer-overflow READ in MVM_VMArray_at_pos_i/atpos.
#   hash:  the hash object's body is overwritten; using it crashes or
#          misbehaves (MoarVM-managed nursery memory: ASAN cannot see the
#          overrun itself).
# Not reachable from Rakudo's Proc::Async, which always passes buf8
# (src/core.c/Proc/Async.rakumod).

my class Queue is repr('ConcBlockingQueue') { }

sub MAIN($prog, $mode = 'int64') {
    my $queue := nqp::create(Queue);
    my $type;
    if $mode eq 'int64' {
        $type := nqp::newtype(nqp::null(), 'VMArray');
        my $i64 := nqp::newtype(nqp::null(), 'P6int');
        nqp::composetype($i64, nqp::hash('integer', nqp::hash('bits', 64)));
        nqp::composetype($type, nqp::hash('array', nqp::hash('type', $i64)));
    }
    elsif $mode eq 'hash' { $type := nqp::what(nqp::hash()) }
    else { nqp::die("mode: int64 or hash") }
    my $done := 0; my $eof := 0; my $errs := 0;
    my @got;
    my $config := nqp::hash(
        'done', -> $status { $done := 1 },
        'ready', -> $stdin?, $stdout?, $stderr? { },
        'stdout_bytes', -> $seq, $data, $err {
            if nqp::isconcrete($data) { nqp::push(@got, $data) } else { $eof := 1 }
        },
        'error', -> $err { say("error: $err"); $done := 1; $eof := 1 },
        'buf_type', $type
    );
    my $r;
    try {
        my $task := nqp::spawnprocasync($queue, '/bin/sh',
            nqp::list('/bin/sh', '-c', 'printf "%099d\n" 7'), nqp::cwd(), nqp::getenvhash(), $config);
        nqp::permit($task, 1, -1);
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
    my $first := @got[0];
    if $mode eq 'int64' {
        say("got " ~ nqp::elems($first) ~ " elements");
        say("element 0: " ~ nqp::atpos_i($first, 0));
        say("element 99: " ~ nqp::atpos_i($first, 99));
    }
    else {
        say("repr: " ~ nqp::reprname($first));
        say("elems: " ~ nqp::elems($first));
        $first<k> := 1;
        say("bound a key: " ~ nqp::elems($first));
    }
}
