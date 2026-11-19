my $b = Buf.new(1..8);
$b.shift for ^2;
say "elems {$b.elems}: {$b.list}";
for 5, 6 -> $off {
    say "read-uint8($off): ", (try $b.read-uint8($off)) // "died: {$!.message}";
}
say "read-uint32(4): ", (try $b.read-uint32(4)) // "died: {$!.message}";
for (buf64, 2**61 + 1), (buf32, 2**62 + 1) -> ($type, $off) {
    my $c = $type.new(1, 2, 3, 4);
    my $r = (try $type ~~ buf64 ?? $c.read-int64($off) !! $c.read-int32($off)) // "died: {$!.message}";
    my $w = (try { $type ~~ buf64 ?? $c.write-int64($off, 99) !! $c.write-int32($off, 99); 'ok' }) // "died: {$!.message}";
    say "{$type.^name} at $off: read $r; write $w; now {$c.list}";
}
my $d = buf16.new(1..8);
my $r = (try $d.read-uint32(2**63 - 1)) // "died: {$!.message}";
my $w = (try { $d.write-uint32(2**63 - 1, 0x22221111); 'ok' }) // "died: {$!.message}";
say "buf16 at {2**63 - 1}: read $r; write $w; now {$d.list}";
