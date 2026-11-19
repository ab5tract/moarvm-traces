my $n = Uni.new(101, 769, 97).NFC;
say $n.^name, " ", $n.list;
my $r = (try { $n.push(5); "pushed" }) // "push died: {$!.message}";
say $r;
$r = (try { $n[5] = 1; "assigned" }) // "assign died: {$!.message}";
say $r;
