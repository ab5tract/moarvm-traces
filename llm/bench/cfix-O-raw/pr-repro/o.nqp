# nqp o.nqp int64|missing|rebind
my class Queue is repr('ConcBlockingQueue') { }
sub int_array(int $bits) {
    my $int := nqp::newtype(nqp::null(), 'P6int');
    nqp::composetype($int, nqp::hash('integer', nqp::hash('bits', $bits, 'unsigned', 1)));
    my $t := nqp::newtype(nqp::null(), 'VMArray');
    nqp::composetype($t, nqp::hash('array', nqp::hash('type', $int)));
    $t
}
sub MAIN($prog, $case) {
    my $queue := nqp::create(Queue);
    my $done := 0; my $eof := 0; my @got;
    my $config := nqp::hash(
        'done',  -> $status { $done := 1 },
        'error', -> $err, $code? { say("error: $err"); $done := 1; $eof := 1 },
        'stdout_bytes', -> $seq, $data, $err {
            nqp::isconcrete($data) ?? nqp::push(@got, $data) !! ($eof := 1)
        });
    $config<buf_type> := int_array(64) if $case eq 'int64';
    $config<buf_type> := int_array(8)  if $case eq 'rebind';
    my $task;
    try {
        # 100 bytes on stdout
        $task := nqp::spawnprocasync($queue, '/bin/sh', nqp::list('/bin/sh', '-c', 'printf "%099d\n" 7'),
            nqp::cwd(), nqp::getenvhash(), $config);
        CATCH { say("spawnprocasync died: " ~ nqp::getmessage($!)) }
    }
    return 0 unless nqp::isconcrete($task);
    $config<buf_type> := int_array(64) if $case eq 'rebind';
    nqp::permit($task, 1, -1);
    while !$done || !$eof {
        my $t := nqp::shift($queue);
        if nqp::islist($t) { my $code := nqp::shift($t); $code(|$t) } else { $t() }
    }
    my $buf := @got[0];
    say("read " ~ nqp::elems($buf) ~ " elements; element 0: " ~ nqp::atpos_i($buf, 0)
        ~ ", element 99: " ~ nqp::atpos_i($buf, 99));
}
